#!/usr/bin/env python3

import json
import re
import subprocess
import sys
import time


def clients():
    try:
        data = subprocess.check_output(["hyprctl", "-j", "clients"], text=True)
        return json.loads(data)
    except Exception:
        return []


def monitors():
    try:
        data = subprocess.check_output(["hyprctl", "-j", "monitors"], text=True)
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


def main():
    if len(sys.argv) < 2:
      return 1

    class_pattern = re.compile(sys.argv[1])
    mode = sys.argv[2] if len(sys.argv) > 2 else "none"
    monitor_name = sys.argv[3] if len(sys.argv) > 3 else ""
    workspace_id = sys.argv[4] if len(sys.argv) > 4 else ""

    target = None
    for _ in range(60):
        matches = []
        for client in clients():
            klass = client.get("class") or client.get("initialClass") or ""
            if class_pattern.search(klass):
                matches.append(client)
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
        dispatch("movetoworkspacesilent", f"{workspace_id},address:{address}")

    if mode not in {"full", "medium"}:
        stabilize_focus(address)
        return 0

    active_monitor = None
    for monitor in monitors():
        if monitor_name and monitor.get("name") == monitor_name:
            active_monitor = monitor
            break
        if not monitor_name and monitor.get("focused"):
            active_monitor = monitor
            break

    if not active_monitor:
        return 0

    monitor_name = active_monitor.get("name")
    width = int(active_monitor.get("width", 0))
    height = int(active_monitor.get("height", 0))
    if not monitor_name or width <= 0 or height <= 0:
        return 0

    if mode == "full":
        target_w = width * 96 // 100
        target_h = height * 92 // 100
    else:
        target_w = width * 72 // 100
        target_h = height * 76 // 100

    if not target.get("floating"):
        dispatch("togglefloating")

    dispatch("movewindow", f"mon:{monitor_name}")
    if workspace_id:
        dispatch("movetoworkspacesilent", f"{workspace_id},address:{address}")
    dispatch("resizeactive", "exact", str(target_w), str(target_h))
    dispatch("centerwindow", "1")
    stabilize_focus(address)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
