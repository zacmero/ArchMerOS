#!/usr/bin/env python3

import fcntl
import json
import os
import re
import socket
import subprocess
import sys
import time
from pathlib import Path


LOCK_PATH = Path.home() / ".cache" / "archmeros" / "notification-focus.lock"
LOG_PATH = Path("/tmp/archmeros-notification-focus.log")
SOCKET_RETRY_DELAY = 1.0
POLL_INTERVAL = 0.15
FOCUS_DISMISS_DELAY = 2.5


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
    if not isinstance(data, dict):
        return {}
    try:
        data["process_cwd"] = os.readlink(f"/proc/{int(data.get('pid', 0))}/cwd")
    except (OSError, TypeError, ValueError):
        data["process_cwd"] = ""
    return data


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
        match = re.match(r"^\s+Urgency:\s*(.*)$", line)
        if match:
            current["urgency"] = match.group(1).strip().lower()

    if current:
        notifications.append(current)
    return notifications


def list_notifications() -> list[dict]:
    try:
        proc = subprocess.run(
            ["makoctl", "list", "-j"],
            check=True,
            capture_output=True,
            text=True,
        )
        notifications = json.loads(proc.stdout or "[]")
    except (Exception, json.JSONDecodeError):
        return []
    return notifications if isinstance(notifications, list) else []


def dismiss_notification(notification_id: int) -> None:
    subprocess.run(
        ["makoctl", "dismiss", "-n", str(notification_id), "-h"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def notification_is_protected(notification: dict) -> bool:
    return notification.get("category") == "archmeros-achievement"


def notification_matches_window(notification: dict, window: dict) -> bool:
    # Sentinel achievement toasts must survive app focus.
    if notification_is_protected(notification):
        return False
    app_name = compact(notification.get("app_name"))
    summary = compact(notification.get("summary"))
    body = str(notification.get("body") or "")
    if not app_name and not summary and not body:
        return False

    class_name = compact(window.get("class"))
    initial_class = compact(window.get("initialClass"))
    title = compact(window.get("title"))
    workspace = window.get("workspace") or {}
    workspace_name = str(workspace.get("name") or workspace.get("id") or "")

    process_cwd = str(window.get("process_cwd") or "")
    cwd = compact(process_cwd)
    cwd_name = compact(Path(process_cwd).name) if process_cwd else ""
    candidates = [
        value for value in [class_name, initial_class, title, cwd, cwd_name] if value
    ]
    ignored_body_words = {
        "agent", "complete", "completed", "done", "finished", "needs",
        "attention", "project", "session", "workspace", "working",
    }
    body_needles = [
        compact(word)
        for word in re.findall(r"[A-Za-z0-9_.-]+", body)
        if len(compact(word)) >= 4 and compact(word) not in ignored_body_words
    ]
    body_parts = [part.strip() for part in body.split("·")]
    if (
        summary == "codexfinished"
        and len(body_parts) >= 2
    ):
        return body_parts[1] == workspace_name
    for needle in [app_name, summary, compact(body), *body_needles]:
        if not needle:
            continue
        for haystack in candidates:
            if needle in haystack or haystack in needle:
                return True
    return False


def self_test() -> None:
    window = {
        "class": "archmeros-wezterm-123",
        "initialClass": "archmeros-wezterm-123",
        "title": "Codex",
        "process_cwd": "/home/zacmero/projects/ArchMerOS",
        "workspace": {"id": 3, "name": "3"},
    }
    assert notification_matches_window(
        {
            "app_name": "Herdr",
            "summary": "Agent finished",
            "body": "ArchMerOS",
            "urgency": "normal",
        },
        window,
    )
    assert notification_matches_window(
        {
            "app_name": "notify-send",
            "summary": "codex finished",
            "body": "prod-attack · 3 · codex-apple",
            "urgency": "normal",
        },
        window,
    )
    assert not notification_matches_window(
        {
            "app_name": "notify-send",
            "summary": "codex finished",
            "body": "prod-attack · 4 · codex-apple",
            "urgency": "normal",
        },
        window,
    )
    assert not notification_matches_window(
        {
            "app_name": "Sentinel",
            "summary": "Achievement unlocked",
            "body": "ArchMerOS",
            "urgency": "normal",
            "category": "archmeros-achievement",
        },
        window,
    )
    assert notification_matches_window(
        {
            "app_name": "wezterm",
            "summary": "Antigravity CLI is ready for input",
            "body": "",
            "urgency": "critical",
        },
        window,
    )


def update_notifications(seen: dict[int, dict], now: float | None = None) -> None:
    now = time.monotonic() if now is None else now
    window = active_window()
    if not window:
        return

    notifications = list_notifications()
    current_ids = {int(notification["id"]) for notification in notifications}
    for notification_id in set(seen) - current_ids:
        seen.pop(notification_id, None)

    dismissed = 0
    for notification in notifications:
        notification_id = int(notification["id"])
        if notification_is_protected(notification):
            continue
        matches = notification_matches_window(notification, window)
        state = seen.get(notification_id)
        if state is None:
            seen[notification_id] = {
                "focus_since": now if matches else None,
                "matched_at_arrival": matches,
            }
            if matches:
                dismiss_notification(notification_id)
                seen.pop(notification_id, None)
                dismissed += 1
            continue
        if not matches:
            state["focus_since"] = None
            continue
        if state["focus_since"] is None:
            state["focus_since"] = now
            continue
        if now - state["focus_since"] >= FOCUS_DISMISS_DELAY:
            dismiss_notification(notification_id)
            seen.pop(notification_id, None)
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

    seen: dict[int, dict] = {}
    while True:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
                sock.connect(str(socket_path))
                sock.settimeout(POLL_INTERVAL)
                while True:
                    update_notifications(seen)
                    try:
                        data = sock.recv(65536)
                    except TimeoutError:
                        continue
                    if not data:
                        raise RuntimeError("Hyprland event socket closed")
        except KeyboardInterrupt:
            return 0
        except Exception as exc:
            log(f"retry {exc}")
            time.sleep(SOCKET_RETRY_DELAY)


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        self_test()
    else:
        raise SystemExit(listen())
