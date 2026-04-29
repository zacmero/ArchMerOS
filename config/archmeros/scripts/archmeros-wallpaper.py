#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve()
REPO_ROOT = SCRIPT_PATH.parents[3]
WALLPAPER_DIR = REPO_ROOT / "config" / "wallpapers"
DEFAULTS_FILE = REPO_ROOT / "config" / "archmeros" / "defaults" / "wallpapers.json"
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state")) / "archmeros"
STATE_FILE = STATE_DIR / "wallpapers.json"
LEGACY_STATE_FILE = STATE_DIR / "current-wallpaper"
PID_FILE = STATE_DIR / "wallpaper.pid"
LOG_FILE = Path("/tmp/archmeros-wallpaper.log")
APPEARANCE_STATE_FILE = STATE_DIR / "appearance.json"
THEME_SCRIPT = REPO_ROOT / "config" / "archmeros" / "scripts" / "archmeros-theme.py"
DEFAULT_ROTATION_INTERVAL = 300


def run(command: list[str], check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, check=check, text=True, capture_output=True)


def start_detached(command: list[str], log_path: Path) -> None:
    with log_path.open("w", encoding="utf-8") as handle:
        process = subprocess.Popen(
            command,
            stdout=handle,
            stderr=subprocess.STDOUT,
            stdin=subprocess.DEVNULL,
            start_new_session=True,
        )
    PID_FILE.write_text(f"{process.pid}\n", encoding="utf-8")


def stop_backend() -> None:
    if PID_FILE.exists():
        try:
          pid = int(PID_FILE.read_text(encoding="utf-8").strip())
        except Exception:
            pid = 0
        if pid > 0:
            subprocess.run(["kill", str(pid)], check=False)
            subprocess.run(["sleep", "1"], check=False)
            subprocess.run(["kill", "-9", str(pid)], check=False)
        PID_FILE.unlink(missing_ok=True)
    subprocess.run(["pkill", "-x", "swaybg"], check=False)
    subprocess.run(["pkill", "-x", "hyprpaper"], check=False)


def active_monitors() -> list[str]:
    try:
        result = run(["hyprctl", "-j", "monitors"])
        monitors = json.loads(result.stdout)
        names = [entry["name"] for entry in monitors if entry.get("name")]
        if names:
            return names
    except Exception:
        pass

    defaults = load_defaults()
    names = list(defaults.get("monitors", {}).keys())
    if names:
        return names

    return ["DP-3", "HDMI-A-1", "DP-2"]


def load_defaults() -> dict:
    if DEFAULTS_FILE.exists():
        return json.loads(DEFAULTS_FILE.read_text(encoding="utf-8"))
    return {"mode": "fill", "monitors": {}}


def resolve_wallpaper(requested: str) -> Path:
    candidate = Path(requested).expanduser()
    if candidate.is_file():
        return candidate.resolve()

    repo_candidate = WALLPAPER_DIR / requested
    if repo_candidate.is_file():
        return repo_candidate.resolve()

    raise FileNotFoundError(f"Wallpaper not found: {requested}")


def available_wallpapers() -> list[Path]:
    return sorted(
        path
        for path in WALLPAPER_DIR.iterdir()
        if path.is_file() and path.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"}
    )


def first_wallpaper() -> Path:
    wallpapers = available_wallpapers()
    if not wallpapers:
        raise FileNotFoundError(f"No wallpapers found in {WALLPAPER_DIR}")
    return wallpapers[0]


def normalize_monitor_map(raw_map: dict[str, str]) -> dict[str, str]:
    normalized: dict[str, str] = {}
    for monitor, value in raw_map.items():
        try:
            normalized[monitor] = str(resolve_wallpaper(value))
        except FileNotFoundError:
            continue
    return normalized


def ensure_monitors(state: dict) -> dict:
    monitors = active_monitors()
    current = dict(state.get("monitors", {}))
    defaults = normalize_monitor_map(load_defaults().get("monitors", {}))
    fallback = next(iter(current.values()), None) or next(iter(defaults.values()), None)
    if fallback is None:
        fallback = str(first_wallpaper())

    for monitor in monitors:
        if monitor not in current:
            current[monitor] = defaults.get(monitor, fallback)

    state["mode"] = state.get("mode", "fill")
    state["monitors"] = {monitor: current[monitor] for monitor in monitors}
    return state


def load_state() -> dict:
    STATE_DIR.mkdir(parents=True, exist_ok=True)

    if STATE_FILE.exists():
        data = json.loads(STATE_FILE.read_text(encoding="utf-8"))
        data["monitors"] = normalize_monitor_map(data.get("monitors", {}))
        data["mode"] = data.get("mode", "fill")
        return ensure_monitors(data)

    defaults = load_defaults()
    default_map = normalize_monitor_map(defaults.get("monitors", {}))
    monitors = active_monitors()

    if LEGACY_STATE_FILE.exists():
        legacy_path = LEGACY_STATE_FILE.read_text(encoding="utf-8").strip()
        if legacy_path:
            try:
                resolved = str(resolve_wallpaper(legacy_path))
                default_map = {monitor: resolved for monitor in monitors}
            except FileNotFoundError:
                pass

    if not default_map:
        fallback = str(first_wallpaper())
        default_map = {monitor: fallback for monitor in monitors}

    state = {"mode": defaults.get("mode", "fill"), "monitors": default_map}
    return ensure_monitors(state)


def save_state(state: dict) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    first_path = next(iter(state["monitors"].values()), "")
    if first_path:
        LEGACY_STATE_FILE.write_text(first_path + "\n", encoding="utf-8")


def escape_hyprpaper_path(path: str) -> str:
    return path.replace("\\", "\\\\").replace(" ", "\\ ")


def apply_state(state: dict) -> None:
    mode = state.get("mode", "fill")
    mappings = state["monitors"]
    rotation_enabled = bool(state.get("rotation_enabled", False))
    rotation_interval = max(60, int(state.get("rotation_interval", DEFAULT_ROTATION_INTERVAL) or DEFAULT_ROTATION_INTERVAL))

    stop_backend()

    if rotation_enabled:
        config_file = Path("/tmp/archmeros-hyprpaper.conf")
        lines = ["ipc = on", "splash = false", ""]
        wallpaper_dir = str(WALLPAPER_DIR.resolve())
        for monitor in mappings:
            lines.extend(
                [
                    "wallpaper {",
                    f"    monitor = {monitor}",
                    f"    path = {wallpaper_dir}",
                    "    fit_mode = cover",
                    f"    timeout = {rotation_interval}",
                    "    order = random",
                    "}",
                    "",
                ]
            )
        config_file.write_text("\n".join(lines) + "\n", encoding="utf-8")
        start_detached(["hyprpaper", "-c", str(config_file)], Path("/tmp/archmeros-hyprpaper.log"))
        return

    if shutil.which("swaybg"):
        command = ["swaybg"]
        for monitor, path in mappings.items():
            command.extend(["-o", monitor, "-i", path, "-m", mode])
        start_detached(command, LOG_FILE)
        return

    config_file = Path("/tmp/archmeros-hyprpaper.conf")
    lines: list[str] = []
    for path in sorted(set(mappings.values())):
        lines.append(f"preload = {escape_hyprpaper_path(path)}")
    lines.append("")
    for monitor, path in mappings.items():
        lines.append(f"wallpaper = {monitor},{escape_hyprpaper_path(path)}")
    lines.append("")
    lines.append("splash = false")
    lines.append("ipc = on")
    config_file.write_text("\n".join(lines) + "\n", encoding="utf-8")
    start_detached(["hyprpaper", "-c", str(config_file)], Path("/tmp/archmeros-hyprpaper.log"))


def appearance_mode() -> str:
    if not APPEARANCE_STATE_FILE.exists():
        return "default"
    try:
        data = json.loads(APPEARANCE_STATE_FILE.read_text(encoding="utf-8"))
        return data.get("mode", "default")
    except Exception:
        return "default"


def refresh_shell() -> None:
    subprocess.run(["hyprctl", "reload"], check=False)
    subprocess.run(["pkill", "-x", "waybar"], check=False)
    subprocess.run(["pkill", "-x", "mako"], check=False)
    start_detached(
        [
            "waybar",
            "-c",
            str(Path.home() / ".config" / "waybar" / "config.jsonc"),
            "-s",
            str(Path.home() / ".config" / "waybar" / "style.css"),
        ],
        Path("/tmp/archmeros-waybar.log"),
    )
    start_detached(
        ["mako", "-c", str(Path.home() / ".config" / "mako" / "config")],
        Path("/tmp/archmeros-mako.log"),
    )


def refresh_theme_for_auto_mode() -> None:
    if appearance_mode() != "auto" or not THEME_SCRIPT.exists():
        return
    subprocess.run([str(THEME_SCRIPT), "--apply-auto", "--no-refresh"], check=False)
    refresh_shell()


def main() -> int:
    parser = argparse.ArgumentParser(description="ArchMerOS wallpaper controller")
    parser.add_argument("wallpaper", nargs="?", help="Wallpaper file name or path")
    parser.add_argument("--monitor", help="Target monitor name")
    parser.add_argument("--all", action="store_true", help="Apply the wallpaper to all monitors")
    parser.add_argument("--list-monitors", action="store_true", help="List detected monitor names")
    parser.add_argument("--show-state", action="store_true", help="Print the current wallpaper state")
    parser.add_argument("--no-theme-sync", action="store_true", help="Do not refresh auto appearance mode")
    parser.add_argument("--enable-rotation", action="store_true", help="Enable random wallpaper rotation")
    parser.add_argument("--disable-rotation", action="store_true", help="Disable random wallpaper rotation")
    parser.add_argument("--rotation-interval", type=int, help="Wallpaper rotation interval in seconds")
    parser.add_argument("--stop", action="store_true", help="Stop the current wallpaper backend")
    parser.add_argument("--status", action="store_true", help="Show the wallpaper backend PID if present")
    args = parser.parse_args()

    if args.stop:
        stop_backend()
        return 0

    if args.status:
        if PID_FILE.exists():
            print(PID_FILE.read_text(encoding="utf-8").strip())
        return 0

    if args.list_monitors:
        print("\n".join(active_monitors()))
        return 0

    state = load_state()

    if args.enable_rotation or args.disable_rotation or args.rotation_interval is not None:
        if args.enable_rotation:
            state["rotation_enabled"] = True
        if args.disable_rotation:
            state["rotation_enabled"] = False
        if args.rotation_interval is not None:
            state["rotation_interval"] = max(60, args.rotation_interval)
        save_state(state)
        apply_state(state)
        if args.show_state:
            print(json.dumps(state, indent=2))
        return 0

    if args.wallpaper:
        resolved = str(resolve_wallpaper(args.wallpaper))
        if args.monitor and not args.all:
            state["monitors"][args.monitor] = resolved
        else:
            for monitor in state["monitors"]:
                state["monitors"][monitor] = resolved
        save_state(state)
        apply_state(state)
        if not args.no_theme_sync:
            refresh_theme_for_auto_mode()
        if args.show_state:
            print(json.dumps(state, indent=2))
        return 0

    save_state(state)
    apply_state(state)
    if args.show_state:
        print(json.dumps(state, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
