#!/usr/bin/env python3

import json
import subprocess
import sys
import time
from pathlib import Path

FULL_THRESHOLD = 85
MEDIUM_THRESHOLD = 64
DISPATCH_SHIM = Path.home() / ".config" / "archmeros" / "scripts" / "archmeros-hyprctl-dispatch.sh"


def clients():
    try:
        data = subprocess.check_output(["hyprctl", "-j", "clients"], text=True)
        return json.loads(data)
    except Exception:
        return []


def client_by_address(address: str) -> dict:
    return next((client for client in clients() if client.get("address") == address), {})


def active_address() -> str:
    try:
        data = subprocess.check_output(["hyprctl", "-j", "activewindow"], text=True)
        return str(json.loads(data).get("address") or "")
    except Exception:
        return ""


def dispatch(*args: str):
    command = [str(DISPATCH_SHIM), *args] if DISPATCH_SHIM.exists() else ["hyprctl", "dispatch", *args]
    subprocess.run(command, check=False)


def size_mode(width: int, height: int, monitor_width: int, monitor_height: int) -> str:
    if width <= 0 or height <= 0 or monitor_width <= 0 or monitor_height <= 0:
        return "none"
    if width * 100 >= monitor_width * FULL_THRESHOLD or height * 100 >= monitor_height * FULL_THRESHOLD:
        return "full"
    if width * 100 >= monitor_width * MEDIUM_THRESHOLD or height * 100 >= monitor_height * MEDIUM_THRESHOLD:
        return "medium"
    return "none"


def target_size(mode: str, monitor_width: int, monitor_height: int) -> tuple[int, int] | None:
    if monitor_width <= 0 or monitor_height <= 0:
        return None
    if mode == "full":
        return (monitor_width * 96 // 100, monitor_height * 92 // 100)
    if mode == "medium":
        return (monitor_width * 72 // 100, monitor_height * 76 // 100)
    return None


def stabilize_focus(address: str):
    dispatch("focuswindow", f"address:{address}")
    dispatch("bringactivetotop")


def focus_window(address: str):
    for _ in range(10):
        dispatch("focuswindow", f"address:{address}")
        if active_address() == address:
            return
        time.sleep(0.02)


def main() -> int:
    if len(sys.argv) < 2:
        return 1

    try:
        pid = int(sys.argv[1])
    except ValueError:
        return 1

    mode = sys.argv[2] if len(sys.argv) > 2 else "none"
    monitor_name = sys.argv[3] if len(sys.argv) > 3 else ""
    workspace_id = sys.argv[4] if len(sys.argv) > 4 else ""
    requested_width = int(sys.argv[5]) if len(sys.argv) > 5 else 0
    requested_height = int(sys.argv[6]) if len(sys.argv) > 6 else 0

    target = None
    for _ in range(80):
        matches = [client for client in clients() if int(client.get("pid") or -1) == pid]
        if matches:
            matches.sort(key=lambda c: c.get("focusHistoryID", -1))
            target = matches[-1]
            break
        time.sleep(0.12)

    if not target:
        return 0

    address = target.get("address")
    if not address:
        return 0

    target = client_by_address(address) or target
    focus_window(address)

    if monitor_name:
        dispatch("movewindow", f"mon:{monitor_name}")
    if workspace_id:
        dispatch("movetoworkspace", str(workspace_id))

    if mode == "inherit":
        mode = size_mode(
            int(target.get("size", [0, 0])[0] or 0),
            int(target.get("size", [0, 0])[1] or 0),
            int(target.get("monitorWidth", 0) or 0),
            int(target.get("monitorHeight", 0) or 0),
        )

    if mode not in {"max", "full", "medium"}:
        stabilize_focus(address)
        return 0

    width = int(target.get("monitorWidth", 0) or 0)
    height = int(target.get("monitorHeight", 0) or 0)

    if width <= 0 or height <= 0:
        try:
            monitors = json.loads(subprocess.check_output(["hyprctl", "-j", "monitors"], text=True))
        except Exception:
            monitors = []
        for monitor in monitors:
            if monitor.get("name") == monitor_name or monitor.get("focused"):
                width = int(monitor.get("width", 0) or 0)
                height = int(monitor.get("height", 0) or 0)
                break

    if width <= 0 or height <= 0:
        stabilize_focus(address)
        return 0

    if requested_width > 0 and requested_height > 0:
        target_w, target_h = requested_width, requested_height
    else:
        size = target_size(mode, width, height)
        if size is None:
            stabilize_focus(address)
            return 0
        target_w, target_h = size

    dispatch("setfloating")
    for _ in range(10):
        time.sleep(0.02)
        if client_by_address(address).get("floating"):
            break

    focus_window(address)
    dispatch("resizeactive", "exact", str(target_w), str(target_h))
    dispatch("centerwindow", "1")
    stabilize_focus(address)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
