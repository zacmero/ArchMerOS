#!/usr/bin/env python3

import json
import re
import subprocess
import sys
import time

FULL_THRESHOLD = 85
MEDIUM_THRESHOLD = 64


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
            title = client.get("title") or client.get("initialTitle") or ""
            if class_pattern.search(klass) or class_pattern.search(title):
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

    if mode == "inherit":
        size = target.get("size") or [0, 0]
        mode = size_mode(
            int(size[0] or 0),
            int(size[1] or 0),
            int(target.get("monitorWidth", 0) or 0),
            int(target.get("monitorHeight", 0) or 0),
        )

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

    size = target_size(mode, width, height)
    if size is None:
        stabilize_focus(address)
        return 0
    target_w, target_h = size

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
