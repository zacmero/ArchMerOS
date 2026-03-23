#!/usr/bin/env python3

import json
import subprocess
import sys
import time


def clients():
    try:
        data = subprocess.check_output(["hyprctl", "-j", "clients"], text=True)
        return json.loads(data)
    except Exception:
        return []


def dispatch(*args: str):
    subprocess.run(["hyprctl", "dispatch", *args], check=False)


def stabilize_focus(address: str):
    for _ in range(10):
        dispatch("focuswindow", f"address:{address}")
        dispatch("bringactivetotop")
        time.sleep(0.05)


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

    dispatch("focuswindow", f"address:{address}")

    if monitor_name:
        dispatch("movewindow", f"mon:{monitor_name}")
    if workspace_id:
        dispatch("movetoworkspace", str(workspace_id))

    if mode not in {"full", "medium"}:
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

    if mode == "full":
        target_w = width * 96 // 100
        target_h = height * 92 // 100
    else:
        target_w = width * 72 // 100
        target_h = height * 76 // 100

    if not target.get("floating"):
        dispatch("togglefloating")

    dispatch("resizeactive", "exact", str(target_w), str(target_h))
    dispatch("centerwindow", "1")
    stabilize_focus(address)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
