#!/usr/bin/env python3

import json
import subprocess
import sys
import time

FULL_THRESHOLD = 85
MEDIUM_THRESHOLD = 64


def active_window():
    try:
        return json.loads(subprocess.check_output(["hyprctl", "-j", "activewindow"], text=True))
    except Exception:
        return {}


def clients():
    try:
        return json.loads(subprocess.check_output(["hyprctl", "-j", "clients"], text=True))
    except Exception:
        return []


from pathlib import Path

DISPATCH_SHIM = Path.home() / ".config" / "archmeros" / "scripts" / "archmeros-hyprctl-dispatch.sh"


def dispatch(*args: str):
    if DISPATCH_SHIM.exists():
        subprocess.run([str(DISPATCH_SHIM), *args], check=False)
    else:
        subprocess.run(["hyprctl", "dispatch", *args], check=False)


def size_mode(width: int, height: int, monitor_width: int, monitor_height: int) -> str:
    if width <= 0 or height <= 0 or monitor_width <= 0 or monitor_height <= 0:
        return "none"
    if width * 100 >= monitor_width * FULL_THRESHOLD or height * 100 >= monitor_height * FULL_THRESHOLD:
        return "full"
    if width * 100 >= monitor_width * MEDIUM_THRESHOLD or height * 100 >= monitor_height * MEDIUM_THRESHOLD:
        return "medium"
    return "none"


def target_size(mode: str, monitor_width: int, monitor_height: int) -> tuple[int, int] | None:
    if mode == "full":
        return (monitor_width * 96 // 100, monitor_height * 92 // 100)
    if mode == "medium":
        return (monitor_width * 72 // 100, monitor_height * 76 // 100)
    return None


def find_client(address: str, source_monitor: int):
    found = None
    for _ in range(3):
        for client in clients():
            if client.get("address") == address:
                found = client
                if client.get("monitor") != source_monitor:
                    return client
        time.sleep(0.03)
    return found


def main() -> int:
    if len(sys.argv) != 2:
        return 1

    direction = sys.argv[1]
    if direction not in {"l", "r", "u", "d"}:
        return 1

    window = active_window()
    if not window:
        return 0

    address = window.get("address")
    if not address:
        return 0

    source_monitor = int(window.get("monitor", -1))
    size = window.get("size") or [0, 0]
    floating = bool(window.get("floating"))
    mode = size_mode(
        int(size[0] or 0),
        int(size[1] or 0),
        int(window.get("monitorWidth", 0) or 0),
        int(window.get("monitorHeight", 0) or 0),
    )

    dispatch("movewindow", direction)

    client = find_client(address, source_monitor)
    if not client:
        return 0

    target_monitor = int(client.get("monitor", -1))
    if target_monitor == source_monitor:
        return 0

    if not floating:
        target_workspace = (client.get("workspace") or {}).get("id")
        for other in clients():
            if (
                target_workspace is not None
                and other.get("address") != address
                and other.get("mapped") is True
                and other.get("hidden") is False
                and other.get("floating") is True
                and other.get("pinned") is not True
                and (other.get("workspace") or {}).get("id") == target_workspace
            ):
                dispatch("settiled", f"address:{other['address']}")
        dispatch("focuswindow", f"address:{address}")
        dispatch("bringactivetotop")
        return 0

    if mode == "none":
        return 0

    target_monitor_width = int(client.get("monitorWidth", 0) or 0)
    target_monitor_height = int(client.get("monitorHeight", 0) or 0)
    size = target_size(mode, target_monitor_width, target_monitor_height)
    if size is None:
        return 0

    dispatch("focuswindow", f"address:{address}")
    dispatch("resizeactive", "exact", str(size[0]), str(size[1]))
    dispatch("centerwindow", "1")
    dispatch("bringactivetotop")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
