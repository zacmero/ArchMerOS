#!/usr/bin/env python3

import json
import os
import selectors
import socket
import struct
import subprocess
import sys
import time
from pathlib import Path


EV_KEY = 1
BTN_LEFT = 272
INPUT_EVENT = struct.Struct("llHHi")
MOUSE_DEVICE = Path(
    os.environ.get(
        "ARCHMEROS_DROP_TILE_MOUSE",
        "/dev/input/by-id/usb-18f8_USB_OPTICAL_MOUSE-event-mouse",
    )
)
DISPATCH_SHIM = Path.home() / ".config/archmeros/scripts/archmeros-hyprctl-dispatch.sh"


def normalize_address(address: str) -> str:
    address = address.strip().lower()
    return address if address.startswith("0x") else f"0x{address}"


class DropState:
    def __init__(self) -> None:
        self.left_down = False
        self.monitors: dict[str, int] = {}
        self.pending: tuple[str, int] | None = None

    def seed(self, clients: list[dict]) -> None:
        for client in clients:
            address = normalize_address(str(client.get("address", "")))
            monitor = client.get("monitor")
            if address != "0x" and isinstance(monitor, int):
                self.monitors[address] = monitor

    def move(self, address: str, monitor: int, floating: bool, active: bool) -> None:
        address = normalize_address(address)
        previous = self.monitors.get(address)
        self.monitors[address] = monitor
        if not self.left_down or not floating or not active or previous is None:
            return

        origin = previous
        if self.pending and self.pending[0] == address:
            origin = self.pending[1]
        self.pending = None if monitor == origin else (address, origin)

    def button(self, value: int) -> tuple[str, int] | None:
        if value == 1:
            self.left_down = True
            self.pending = None
            return None
        if value != 0:
            return None

        self.left_down = False
        pending = self.pending
        self.pending = None
        return pending


def hypr_socket() -> tuple[Path, str]:
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    if signature:
        path = runtime / "hypr" / signature / ".socket2.sock"
        if path.exists():
            return path, signature

    sockets = sorted(
        (runtime / "hypr").glob("*/.socket2.sock"),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )
    if not sockets:
        raise RuntimeError("no live Hyprland event socket")
    return sockets[0], sockets[0].parent.name


def hyprctl_json(env: dict[str, str], command: str) -> object:
    output = subprocess.check_output(
        ["hyprctl", "-j", command],
        text=True,
        stderr=subprocess.DEVNULL,
        env=env,
    )
    return json.loads(output)


def active_client(env: dict[str, str]) -> dict:
    result = hyprctl_json(env, "activewindow")
    return result if isinstance(result, dict) else {}


def client_by_address(env: dict[str, str], address: str) -> dict:
    clients = hyprctl_json(env, "clients")
    if not isinstance(clients, list):
        return {}
    address = normalize_address(address)
    return next(
        (
            client
            for client in clients
            if normalize_address(str(client.get("address", ""))) == address
        ),
        {},
    )


def tile_pending(env: dict[str, str], pending: tuple[str, int]) -> None:
    time.sleep(0.06)
    address, _ = pending
    client = active_client(env)
    if (
        normalize_address(str(client.get("address", ""))) != address
        or client.get("floating") is not True
    ):
        return
    subprocess.run(
        [str(DISPATCH_SHIM), "settiled"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        env=env,
    )


def handle_hypr_event(state: DropState, env: dict[str, str], line: str) -> None:
    if not line.startswith("movewindowv2>>"):
        return
    fields = line.removeprefix("movewindowv2>>").split(",")
    if not fields:
        return

    address = normalize_address(fields[0])
    client = client_by_address(env, address)
    active = active_client(env)
    monitor = client.get("monitor")
    if not isinstance(monitor, int):
        return
    state.move(
        address,
        monitor,
        client.get("floating") is True,
        normalize_address(str(active.get("address", ""))) == address,
    )


def run() -> None:
    socket_path, signature = hypr_socket()
    env = os.environ.copy()
    env["HYPRLAND_INSTANCE_SIGNATURE"] = signature

    state = DropState()
    clients = hyprctl_json(env, "clients")
    state.seed(clients if isinstance(clients, list) else [])

    mouse_fd = os.open(MOUSE_DEVICE, os.O_RDONLY | os.O_NONBLOCK)
    hypr = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    hypr.connect(str(socket_path))

    selector = selectors.DefaultSelector()
    selector.register(mouse_fd, selectors.EVENT_READ, "mouse")
    selector.register(hypr, selectors.EVENT_READ, "hypr")
    hypr_buffer = ""

    while True:
        for key, _ in selector.select():
            if key.data == "mouse":
                data = os.read(mouse_fd, INPUT_EVENT.size * 64)
                for offset in range(0, len(data) - INPUT_EVENT.size + 1, INPUT_EVENT.size):
                    _, _, event_type, code, value = INPUT_EVENT.unpack_from(data, offset)
                    if event_type == EV_KEY and code == BTN_LEFT:
                        pending = state.button(value)
                        if pending:
                            tile_pending(env, pending)
                continue

            data = hypr.recv(65536)
            if not data:
                raise RuntimeError("Hyprland event socket closed")
            hypr_buffer += data.decode(errors="replace")
            lines = hypr_buffer.split("\n")
            hypr_buffer = lines.pop()
            for line in lines:
                handle_hypr_event(state, env, line)


def self_test() -> None:
    state = DropState()
    state.seed([{"address": "0xabc", "monitor": 0}])
    state.move("abc", 1, True, True)
    assert state.pending is None
    state.move("abc", 0, True, True)
    state.button(1)
    state.move("abc", 1, True, True)
    assert state.pending == ("0xabc", 0)
    state.move("abc", 0, True, True)
    assert state.pending is None
    state.move("abc", 2, True, True)
    assert state.button(0) == ("0xabc", 0)
    assert state.pending is None and not state.left_down


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        self_test()
    else:
        run()
