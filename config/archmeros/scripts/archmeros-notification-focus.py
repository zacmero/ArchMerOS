#!/usr/bin/env python3

import fcntl
import json
import os
import re
import socket
import subprocess
import time
from pathlib import Path


LOCK_PATH = Path.home() / ".cache" / "archmeros" / "notification-focus.lock"
LOG_PATH = Path("/tmp/archmeros-notification-focus.log")
SOCKET_RETRY_DELAY = 1.0


def log(message: str) -> None:
    try:
        LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        with LOG_PATH.open("a", encoding="utf-8") as handle:
            handle.write(f"{time.time():.3f} {message}\n")
    except Exception:
        pass


def compact(value: str | None) -> str:
    return re.sub(r"[^a-z0-9]+", "", (value or "").lower())


def hyprctl_json(command: str) -> object:
    try:
        proc = subprocess.run(
            ["hyprctl", "-j", command],
            check=True,
            capture_output=True,
            text=True,
        )
        return json.loads(proc.stdout or "null")
    except Exception:
        return {} if command == "activewindow" else []


def active_window() -> dict:
    data = hyprctl_json("activewindow")
    return data if isinstance(data, dict) else {}


def hypr_socket2_path() -> Path | None:
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    if not signature or not runtime:
        try:
            proc = subprocess.run(
                ["hyprctl", "-j", "instances"],
                check=True,
                capture_output=True,
                text=True,
            )
            data = json.loads(proc.stdout or "[]")
            if isinstance(data, list) and data:
                first = data[0]
                signature = signature or str(first.get("instance") or "")
                runtime = runtime or f"/run/user/{os.getuid()}"
        except Exception:
            pass
    if not signature or not runtime:
        return None
    return Path(runtime) / "hypr" / signature / ".socket2.sock"


def parse_mako_list(output: str) -> list[dict]:
    notifications: list[dict] = []
    current: dict | None = None

    for raw_line in output.splitlines():
        line = raw_line.rstrip()
        match = re.match(r"^Notification (\d+):(.*)$", line)
        if match:
            if current:
                notifications.append(current)
            current = {
                "id": int(match.group(1)),
                "summary": match.group(2).strip(),
                "app_name": "",
            }
            continue
        if current is None:
            continue
        match = re.match(r"^\s+App name:\s*(.*)$", line)
        if match:
            current["app_name"] = match.group(1).strip()

    if current:
        notifications.append(current)
    return notifications


def list_notifications() -> list[dict]:
    try:
        proc = subprocess.run(
            ["makoctl", "list"],
            check=True,
            capture_output=True,
            text=True,
        )
    except Exception:
        return []
    return parse_mako_list(proc.stdout)


def dismiss_notification(notification_id: int) -> None:
    subprocess.run(
        ["makoctl", "dismiss", "-n", str(notification_id), "-h"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def notification_matches_window(notification: dict, window: dict) -> bool:
    app_name = compact(notification.get("app_name"))
    summary = compact(notification.get("summary"))
    if not app_name and not summary:
        return False

    class_name = compact(window.get("class"))
    initial_class = compact(window.get("initialClass"))
    title = compact(window.get("title"))

    candidates = [value for value in [class_name, initial_class, title] if value]
    for needle in [app_name, summary]:
        if not needle:
            continue
        for haystack in candidates:
            if needle in haystack or haystack in needle:
                return True
    return False


def dismiss_matching_notifications() -> None:
    window = active_window()
    if not window:
        return

    notifications = list_notifications()
    if not notifications:
        return

    dismissed = 0
    for notification in notifications:
        if notification_matches_window(notification, window):
            dismiss_notification(notification["id"])
            dismissed += 1

    if dismissed:
        log(f"dismissed={dismissed} class={window.get('class','')} title={window.get('title','')}")


def listen() -> int:
    socket_path = hypr_socket2_path()
    if socket_path is None:
        log("no socket path")
        return 1

    LOCK_PATH.parent.mkdir(parents=True, exist_ok=True)
    lock_handle = LOCK_PATH.open("w")
    try:
        fcntl.flock(lock_handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return 0

    last_window_key = ""
    while True:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
                sock.connect(str(socket_path))
                with sock.makefile("r", encoding="utf-8", errors="ignore") as events:
                    dismiss_matching_notifications()
                    for raw_line in events:
                        line = raw_line.strip()
                        if not line or ">>" not in line:
                            continue
                        event_name, _payload = line.split(">>", 1)
                        if event_name not in {"activewindow", "activewindowv2", "openwindow"}:
                            continue
                        window = active_window()
                        window_key = f"{window.get('class','')}|{window.get('title','')}"
                        if window_key == last_window_key:
                            continue
                        last_window_key = window_key
                        dismiss_matching_notifications()
        except KeyboardInterrupt:
            return 0
        except Exception as exc:
            log(f"retry {exc}")
            time.sleep(SOCKET_RETRY_DELAY)


if __name__ == "__main__":
    raise SystemExit(listen())
