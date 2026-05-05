#!/usr/bin/env python3

import fcntl
import json
import os
import socket
import subprocess
import sys
import time
from pathlib import Path


CACHE_DIR = Path.home() / ".cache" / "archmeros" / "reopen-history"
LAUNCHES_PATH = CACHE_DIR / "launches.json"
GENERAL_PATH = CACHE_DIR / "closed-general.json"
FOLDERS_PATH = CACHE_DIR / "closed-folders.json"
LOCK_PATH = CACHE_DIR / "listener.lock"
MAX_LAUNCHES = 120
MAX_HISTORY = 20
SNAPSHOT_REFRESH_DELAY = 0.14
SOCKET_RETRY_DELAY = 1.0


def ensure_cache_dir() -> None:
    try:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
    except OSError:
        pass


def load_json(path: Path) -> list[dict]:
    if not path.exists():
        return []
    try:
        data = json.loads(path.read_text())
    except Exception:
        return []
    return data if isinstance(data, list) else []


def save_json(path: Path, data: list[dict]) -> None:
    try:
        ensure_cache_dir()
        path.write_text(json.dumps(data, indent=2))
    except OSError:
        pass


def append_capped(path: Path, item: dict, limit: int) -> None:
    try:
        data = load_json(path)
        data.append(item)
        save_json(path, data[-limit:])
    except OSError:
        pass


def normalize(value: str | None) -> str:
    return (value or "").strip().lower()


def normalize_address(value: str | None) -> str:
    return normalize(value)


def read_cmdline(pid: int) -> list[str]:
    try:
        raw = Path(f"/proc/{pid}/cmdline").read_bytes()
    except OSError:
        return []
    return [part.decode("utf-8", errors="ignore") for part in raw.split(b"\0") if part]


def process_name(argv: list[str]) -> str:
    if not argv:
        return ""
    return Path(argv[0]).name.lower()


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


def clients() -> list[dict]:
    data = hyprctl_json("clients")
    return data if isinstance(data, list) else []


def track_launch(
    kind: str,
    class_name: str,
    class_prefix: str,
    process: str,
    command: list[str],
    title_contains: str = "",
) -> int:
    item = {
        "ts": time.time(),
        "kind": kind,
        "class": normalize(class_name),
        "class_prefix": normalize(class_prefix),
        "process": normalize(process),
        "title_contains": normalize(title_contains),
        "command": command,
    }
    append_capped(LAUNCHES_PATH, item, MAX_LAUNCHES)
    return 0


def known_command_for_window(klass: str, title: str) -> tuple[list[str], str] | None:
    scripts = Path.home() / ".config/archmeros/scripts"
    normalized_title = normalize(title)
    known_apps = [
        ("obsidian", "", [str(scripts / "archmeros-obsidian.sh")]),
        ("termius", "", [str(scripts / "archmeros-termius.sh")]),
        ("telegram", "", [str(scripts / "archmeros-telegram.sh")]),
        ("org.telegram.desktop", "", [str(scripts / "archmeros-telegram.sh")]),
        ("telegramdesktop", "", [str(scripts / "archmeros-telegram.sh")]),
        ("archmeros-chatgpt", "", [str(scripts / "archmeros-webapp.sh"), "chatgpt"]),
        ("archmeros-gemini", "", [str(scripts / "archmeros-webapp.sh"), "gemini"]),
        ("archmeros-todoist", "", [str(scripts / "archmeros-todoist.sh")]),
        ("com.todoist.todoist", "", [str(scripts / "archmeros-todoist.sh")]),
        ("todoist", "", [str(scripts / "archmeros-todoist.sh")]),
        ("archmeros-plex", "", [str(scripts / "archmeros-plex-launch.sh")]),
        ("firefox", "youtube music", [str(scripts / "archmeros-youtube-music.sh")]),
    ]
    for class_match, title_match, command in known_apps:
        if class_match and class_match not in klass:
            continue
        if title_match and title_match not in normalized_title:
            continue
        return command, "general"
    return None


def resolve_command_from_values(klass: str, pid: int, title: str) -> tuple[list[str], str]:
    argv = read_cmdline(pid) if pid > 0 else []
    proc = process_name(argv)
    scripts = Path.home() / ".config/archmeros/scripts"

    known_command = known_command_for_window(klass, title)
    if known_command is not None:
        return known_command

    launches = load_json(LAUNCHES_PATH)
    best_item = None
    best_score = -1
    for item in reversed(launches):
        item_class = normalize(item.get("class"))
        item_prefix = normalize(item.get("class_prefix"))
        if item_class and item_class != klass:
            continue
        if item_prefix and not klass.startswith(item_prefix):
            continue

        score = 0
        if item.get("title_contains") and item["title_contains"] in normalize(title):
            score += 150
        if item_class and item_class == klass:
            score += 120
        if item_prefix and klass.startswith(item_prefix):
            score += 110
        if item.get("process") and item["process"] == proc:
            score += 90
        if klass == "thunar" and item.get("kind") == "folder":
            score += 20
        if score > best_score:
            best_item = item
            best_score = score

    if best_item and best_score > 0 and best_item.get("command"):
        return list(best_item["command"]), best_item.get("kind", "general")

    if klass == "thunar":
        return [str(scripts / "archmeros-thunar.sh"), str(Path.home())], "folder"

    if argv:
        return argv, "general"

    return [], "general"


def build_history_item(window: dict) -> dict:
    klass = normalize(window.get("class"))
    pid = int(window.get("pid") or 0)
    title = window.get("title", "")
    command, kind = resolve_command_from_values(klass, pid, title)
    return {
        "ts": time.time(),
        "kind": kind,
        "class": klass,
        "title": title,
        "command": command,
        "address": normalize_address(window.get("address")),
    }


def append_history_item(item: dict) -> None:
    command = item.get("command") or []
    if not command:
        return

    history_item = {
        "ts": time.time(),
        "kind": item.get("kind", "general"),
        "class": item.get("class", ""),
        "title": item.get("title", ""),
        "command": command,
    }
    append_capped(GENERAL_PATH, history_item, MAX_HISTORY)
    if history_item["kind"] == "folder" or history_item["class"] == "thunar":
        append_capped(FOLDERS_PATH, history_item, MAX_HISTORY)


def record_close() -> int:
    window = active_window()
    if not window:
        return 0

    klass = normalize(window.get("class"))
    title = normalize(window.get("title"))
    if klass == "firefox" and "youtube music" not in title and "music.youtube.com" not in title:
        return 0

    append_history_item(build_history_item(window))
    return 0


def reopen(scope: str) -> int:
    path = FOLDERS_PATH if scope == "folders" else GENERAL_PATH
    data = load_json(path)
    if not data:
        return 0

    item = None
    command = []
    while data:
        candidate = data.pop()
        candidate_command = candidate.get("command") or []
        if candidate_command:
            item = candidate
            command = candidate_command
            break
    save_json(path, data[-MAX_HISTORY:])

    if item is None or not command:
        return 0

    with open(os.devnull, "rb") as devnull_in, open(os.devnull, "wb") as devnull_out:
        subprocess.Popen(
            command,
            stdin=devnull_in,
            stdout=devnull_out,
            stderr=devnull_out,
            start_new_session=True,
        )
    return 0


def snapshot_windows() -> dict[str, dict]:
    result: dict[str, dict] = {}
    for client in clients():
        address = normalize_address(client.get("address"))
        if not address:
            continue
        result[address] = build_history_item(client)
    return result


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


def listen() -> int:
    socket_path = hypr_socket2_path()
    if socket_path is None:
        return 1

    ensure_cache_dir()
    lock_handle = LOCK_PATH.open("w")
    try:
        fcntl.flock(lock_handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return 0

    windows = snapshot_windows()
    while True:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
                sock.connect(str(socket_path))
                with sock.makefile("r", encoding="utf-8", errors="ignore") as events:
                    for raw_line in events:
                        line = raw_line.strip()
                        if not line or ">>" not in line:
                            continue

                        event_name, payload = line.split(">>", 1)
                        payload = payload.strip()

                        if event_name == "closewindow":
                            address = normalize_address(payload.split(",", 1)[0])
                            item = windows.pop(address, None)
                            if item:
                                append_history_item(item)
                            continue

                        if event_name == "openwindow":
                            time.sleep(SNAPSHOT_REFRESH_DELAY)
                            windows = snapshot_windows()
        except KeyboardInterrupt:
            return 0
        except Exception:
            time.sleep(SOCKET_RETRY_DELAY)


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        return 1

    action = argv[1]
    if action == "track-launch":
        if len(argv) < 7 or "--" not in argv:
            return 1
        sep = argv.index("--")
        if sep < 6:
            return 1
        kind = argv[2]
        class_name = argv[3]
        class_prefix = argv[4]
        process = argv[5]
        title_contains = ""
        idx = 6
        while idx < sep:
            if argv[idx] == "--title-contains" and idx + 1 < sep:
                title_contains = argv[idx + 1]
                idx += 2
                continue
            return 1
        command = argv[sep + 1 :]
        return track_launch(kind, class_name, class_prefix, process, command, title_contains)

    if action == "record-close":
        return record_close()

    if action == "reopen-folders":
        return reopen("folders")

    if action == "reopen-general":
        return reopen("general")

    if action == "listen":
        return listen()

    return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
