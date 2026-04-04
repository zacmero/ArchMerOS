#!/usr/bin/env python3

from __future__ import annotations

import argparse
import datetime as dt
import getpass
import json
import math
import os
import random
import re
import select
import shutil
import socket
import subprocess
import sys
import termios
import textwrap
import time
import tty
from dataclasses import dataclass
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve()
REPO_ROOT = SCRIPT_PATH.parents[3]
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state")) / "archmeros"
THEME_FILE = REPO_ROOT / "themes" / "generated" / "current.json"
APPEARANCE_STATE_FILE = STATE_DIR / "appearance.json"
WALLPAPER_STATE_FILE = STATE_DIR / "wallpapers.json"
DEFAULT_WALLPAPER_FILE = REPO_ROOT / "config" / "archmeros" / "defaults" / "wallpapers.json"

DEFAULT_PALETTE = {
    "text": "#d8ddff",
    "subtext1": "#aab4ea",
    "subtext0": "#8891c9",
    "overlay0": "#626da7",
    "surface0": "rgba(29, 35, 60, 0.62)",
    "surface1": "rgba(43, 49, 83, 0.72)",
    "base": "rgba(13, 17, 30, 0.52)",
    "mantle": "rgba(9, 12, 22, 0.72)",
    "crust": "rgba(5, 7, 14, 0.86)",
    "accent": "#58d6ff",
    "accent2": "#ff7edb",
    "accent3": "#be92ff",
    "warning": "#ffd86f",
    "green": "#8fe388",
}

MONITOR_ROLES = {
    "DP-3": "anchor terminal",
    "HDMI-A-1": "main code deck",
    "DP-2": "media and utility rail",
}

ETHOS_LINES = [
    "Terminal-centered workflow first.",
    "Strong aesthetics without bloat.",
    "Modularity over monoliths.",
    "Security and stability over novelty.",
]


RGB = tuple[int, int, int]


@dataclass(slots=True)
class Cell:
    char: str = " "
    fg: RGB | None = None
    bg: RGB | None = None


@dataclass(frozen=True)
class Ritual:
    title: str
    command: str
    purpose: str


@dataclass(frozen=True)
class MonitorCard:
    monitor: str
    role: str
    wallpaper: str


@dataclass(frozen=True)
class AppState:
    theme_name: str
    appearance_mode: str
    appearance_preset: str
    palette: dict[str, str]
    host: str
    user: str
    shell: str
    desktop: str
    branch: str
    git_clean: bool
    uptime: str
    load: str
    memory: str
    battery: str | None
    monitors: list[MonitorCard]
    transmission_pool: list[str]
    rituals: list[Ritual]
    sequence: list[Ritual]
    accent_hex: str
    wallpaper_signature: str
    term_name: str


@dataclass(slots=True)
class DriveSequence:
    seed: int
    started_at: float
    last_tick: float
    lane_bias: int
    vehicle_kind: str
    style: str
    model: str
    route: str
    billboard_left: str
    billboard_right: str
    speed_floor: int
    speed_peak: int
    curve_amplitude: float
    curve_speed: float
    wobble: float
    drift_phase: float
    lane: int
    desired_lane: int
    lane_position: float
    speed: float
    score: int
    passed: int
    distance: float
    spawn_timer: float
    traffic: list["TrafficObstacle"]
    crashed: bool
    crash_flash: float


@dataclass(slots=True)
class TrafficObstacle:
    lane: int
    depth: float
    vehicle_kind: str
    style: str
    speed_factor: float
    phase: float
    passed: bool = False


def load_json(path: Path, fallback: dict | None = None) -> dict:
    if path.exists():
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return fallback or {}
    return fallback or {}


def clamp(value: float, minimum: float = 0.0, maximum: float = 255.0) -> int:
    return int(max(minimum, min(maximum, round(value))))


def parse_rgb(value: str, fallback: RGB) -> RGB:
    if value.startswith("#"):
        value = value.lstrip("#")
        if len(value) >= 6:
            return tuple(int(value[index:index + 2], 16) for index in (0, 2, 4))
    match = re.fullmatch(r"rgba\((\d+),\s*(\d+),\s*(\d+),\s*([0-9.]+)\)", value)
    if match:
        red, green, blue, _alpha = match.groups()
        return (int(red), int(green), int(blue))
    return fallback


def mix(rgb_a: RGB, rgb_b: RGB, amount: float) -> RGB:
    return tuple(clamp(rgb_a[index] * (1 - amount) + rgb_b[index] * amount) for index in range(3))


def darken(rgb: RGB, amount: float) -> RGB:
    return mix(rgb, (0, 0, 0), amount)


def lighten(rgb: RGB, amount: float) -> RGB:
    return mix(rgb, (255, 255, 255), amount)


def hex_value(rgb: RGB) -> str:
    return "#{:02x}{:02x}{:02x}".format(*rgb)


def ease_out_expo(value: float) -> float:
    value = max(0.0, min(1.0, value))
    if value >= 1.0:
        return 1.0
    return 1 - math.pow(2, -10 * value)


def ease_in_out_sine(value: float) -> float:
    value = max(0.0, min(1.0, value))
    return -(math.cos(math.pi * value) - 1) / 2


def billboard_label(value: str, fallback: str) -> str:
    tokens = [token.upper() for token in re.findall(r"[A-Za-z0-9]+", value) if token]
    if not tokens:
        return fallback
    return " ".join(tokens[:2])[:18]


def ansi_fg(rgb: RGB | None) -> str:
    if rgb is None:
        return "\x1b[39m"
    return f"\x1b[38;2;{rgb[0]};{rgb[1]};{rgb[2]}m"


def ansi_bg(rgb: RGB | None) -> str:
    if rgb is None:
        return "\x1b[49m"
    return f"\x1b[48;2;{rgb[0]};{rgb[1]};{rgb[2]}m"


def human_uptime() -> str:
    try:
        seconds = int(float(Path("/proc/uptime").read_text(encoding="utf-8").split()[0]))
    except (OSError, ValueError, IndexError):
        return "unknown"
    days, seconds = divmod(seconds, 86400)
    hours, seconds = divmod(seconds, 3600)
    minutes, _ = divmod(seconds, 60)
    parts: list[str] = []
    if days:
        parts.append(f"{days}d")
    if hours or days:
        parts.append(f"{hours}h")
    parts.append(f"{minutes}m")
    return " ".join(parts)


def memory_status() -> str:
    try:
        lines = Path("/proc/meminfo").read_text(encoding="utf-8").splitlines()
    except OSError:
        return "unknown"
    values: dict[str, int] = {}
    for line in lines:
        key, _, raw = line.partition(":")
        number = raw.strip().split()[0] if raw.strip() else ""
        if number.isdigit():
            values[key] = int(number)
    total = values.get("MemTotal", 0)
    available = values.get("MemAvailable", 0)
    if total <= 0:
        return "unknown"
    used = total - available
    used_gib = used / 1024 / 1024
    total_gib = total / 1024 / 1024
    percent = used * 100 / total
    return f"{used_gib:.1f}/{total_gib:.1f} GiB ({percent:.0f}%)"


def battery_status() -> str | None:
    power_root = Path("/sys/class/power_supply")
    if not power_root.exists():
        return None
    for candidate in sorted(power_root.glob("BAT*")):
        try:
            capacity = (candidate / "capacity").read_text(encoding="utf-8").strip()
            status = (candidate / "status").read_text(encoding="utf-8").strip().lower()
        except OSError:
            continue
        if capacity.isdigit():
            return f"{capacity}% {status}"
    return None


def git_info(repo_root: Path) -> tuple[str, bool]:
    try:
        branch_result = subprocess.run(
            ["git", "-C", str(repo_root), "rev-parse", "--abbrev-ref", "HEAD"],
            check=False,
            capture_output=True,
            text=True,
            timeout=0.8,
        )
        branch = branch_result.stdout.strip() or "detached"
    except (OSError, subprocess.SubprocessError):
        return ("unknown", True)
    try:
        status_result = subprocess.run(
            ["git", "-C", str(repo_root), "status", "--short", "--untracked-files=no"],
            check=False,
            capture_output=True,
            text=True,
            timeout=0.8,
        )
        clean = not status_result.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        clean = True
    return (branch, clean)


def short_wallpaper_name(value: str) -> str:
    name = Path(value).stem.replace("_", " ").replace("-", " ").strip()
    return re.sub(r"\s+", " ", name) or "unknown"


def load_palette() -> tuple[str, dict[str, str], str, str]:
    theme_data = load_json(THEME_FILE, {"name": "default", "palette": DEFAULT_PALETTE})
    appearance = load_json(APPEARANCE_STATE_FILE, {"mode": "preset", "preset": "default"})
    palette = DEFAULT_PALETTE | theme_data.get("palette", {})
    return (
        str(theme_data.get("name", "default")),
        palette,
        str(appearance.get("mode", "preset")),
        str(appearance.get("preset", theme_data.get("name", "default"))),
    )


def load_monitors() -> list[MonitorCard]:
    wallpaper_state = load_json(WALLPAPER_STATE_FILE, load_json(DEFAULT_WALLPAPER_FILE, {"monitors": {}}))
    monitors = wallpaper_state.get("monitors", {})
    if not isinstance(monitors, dict):
        monitors = {}

    cards: list[MonitorCard] = []
    preferred_order = ["DP-3", "HDMI-A-1", "DP-2"]
    seen: set[str] = set()
    for monitor in preferred_order + sorted(monitors):
        if monitor in seen:
            continue
        seen.add(monitor)
        wallpaper = short_wallpaper_name(str(monitors.get(monitor, "unknown")))
        cards.append(MonitorCard(monitor=monitor, role=MONITOR_ROLES.get(monitor, "auxiliary rail"), wallpaper=wallpaper))
    return cards


def build_rituals() -> list[Ritual]:
    return [
        Ritual(
            title="Capture a fresh note",
            command="~/.config/archmeros/scripts/archmeros-note.sh",
            purpose="Open a timestamped scratchpad in Neovim through the ArchMerOS terminal path.",
        ),
        Ritual(
            title="Switch the city palette",
            command="~/.config/archmeros/scripts/archmeros-theme-select.sh",
            purpose="Rotate between shell theme bundles without touching upstream terminal internals.",
        ),
        Ritual(
            title="Re-stage the shell",
            command="~/.config/archmeros/scripts/archmeros-refresh-shell.sh",
            purpose="Reload Hyprland, Waybar, Mako, wallpaper state, and Walker support services.",
        ),
        Ritual(
            title="Cut a new skyline",
            command="~/.config/archmeros/scripts/archmeros-wallpaper-pick.sh",
            purpose="Rebuild the atmosphere from the wallpaper browser and crop pipeline.",
        ),
        Ritual(
            title="Open the appearance deck",
            command="~/.config/archmeros/scripts/archmeros-appearance.sh",
            purpose="Step into the full shell appearance menu when you want more than a quick toggle.",
        ),
        Ritual(
            title="Flash the system signature",
            command="~/.config/archmeros/scripts/archmeros-fastfetch.sh",
            purpose="Print the ArchMerOS identity without leaving the terminal lane.",
        ),
    ]


def time_greeting() -> str:
    hour = dt.datetime.now().hour
    if 5 <= hour < 12:
        return "Morning voltage rising"
    if 12 <= hour < 18:
        return "Day shift still humming"
    if 18 <= hour < 23:
        return "Night has the better palette"
    return "The city is running after midnight"


def build_transmissions(
    host: str,
    theme_name: str,
    appearance_mode: str,
    branch: str,
    git_clean: bool,
    monitors: list[MonitorCard],
    accent_hex: str,
) -> list[str]:
    wallpapers = ", ".join(card.wallpaper for card in monitors[:3]) or "unknown streets"
    repo_status = "clean enough for a precise cut" if git_clean else "already carrying live edits"
    return [
        f"{time_greeting()}. {host} is dressed in {theme_name} with {appearance_mode} pressure.",
        f"Accent vector locked to {accent_hex}. ArchMerOS stays neon, but disciplined.",
        f"Wallpaper feed is steering the room through {wallpapers}.",
        f"Branch {branch} is {repo_status}. Nothing here asks for random damage.",
        "Left monitor keeps the terminal honest. Center takes the hard work. Right catches drift and noise.",
        "This machine is at its best when it feels sharp, not busy.",
        "If you need momentum: capture a note, tint the skyline, then reopen the shell.",
    ]


def build_state(sequence_offset: int) -> AppState:
    theme_name, palette, appearance_mode, appearance_preset = load_palette()
    host = socket.gethostname().split(".", 1)[0]
    user = getpass.getuser()
    shell = Path(os.environ.get("SHELL", "shell")).name
    desktop = os.environ.get("XDG_CURRENT_DESKTOP") or ("Hyprland" if os.environ.get("HYPRLAND_INSTANCE_SIGNATURE") else "terminal")
    branch, git_clean = git_info(REPO_ROOT)
    monitors = load_monitors()
    rituals = build_rituals()
    accent_hex = str(palette.get("accent", DEFAULT_PALETTE["accent"]))
    seed = sum(ord(char) for char in (theme_name + branch + "".join(card.wallpaper for card in monitors)))
    shuffled = rituals[:]
    random.Random(seed + (sequence_offset * 97)).shuffle(shuffled)
    sequence = shuffled[:3]
    term_name = os.environ.get("TERM", "unknown")
    transmission_pool = build_transmissions(host, theme_name, appearance_mode, branch, git_clean, monitors, accent_hex)
    wallpaper_signature = " / ".join(card.wallpaper for card in monitors[:3]) or "no wallpaper telemetry"
    return AppState(
        theme_name=theme_name,
        appearance_mode=appearance_mode,
        appearance_preset=appearance_preset,
        palette=palette,
        host=host,
        user=user,
        shell=shell,
        desktop=desktop,
        branch=branch,
        git_clean=git_clean,
        uptime=human_uptime(),
        load="{:.2f} {:.2f} {:.2f}".format(*os.getloadavg()),
        memory=memory_status(),
        battery=battery_status(),
        monitors=monitors,
        transmission_pool=transmission_pool,
        rituals=rituals,
        sequence=sequence,
        accent_hex=accent_hex,
        wallpaper_signature=wallpaper_signature,
        term_name=term_name,
    )


def build_drive_sequence(state: AppState, frame: int, sequence_offset: int) -> DriveSequence:
    seed_source = (
        state.theme_name
        + state.appearance_mode
        + state.appearance_preset
        + state.branch
        + state.desktop
        + state.wallpaper_signature
        + state.accent_hex
    )
    config_seed = sum(ord(char) for char in seed_source)
    seed = config_seed ^ (frame << 11) ^ (sequence_offset << 7) ^ time.time_ns()
    rng = random.Random(seed)

    vehicle_kind = rng.choice(["car", "motorcycle"])
    if vehicle_kind == "motorcycle":
        style = rng.choice(["kaneda", "street", "phantom"])
        model_roots = {
            "kaneda": ["KANEDA", "AKIRA", "REDLINE", "NIGHTBIKE", "RIFT"],
            "street": ["SHURIKEN", "STREET HAZE", "LOWSIDE", "REVENANT", "STRIKE"],
            "phantom": ["SPECTER", "MIRAGE", "GHOSTLINE", "PHASE", "NEON RIDER"],
        }
        suffixes = ["900", "GT", "RS", "MK-II", "X", "TURBO"]
    else:
        style = rng.choice(["wedge", "interceptor", "phantom"])
        model_roots = {
            "wedge": ["VECTOR", "NOVA", "RAZOR", "WARP", "RIFT"],
            "interceptor": ["COBRA", "SABLE", "MONARCH", "INTERCEPTOR", "VANTAGE"],
            "phantom": ["PHANTOM", "ECHO", "GHOST", "SPECTER", "MIRAGE"],
        }
        suffixes = ["GT", "XR", "MK-II", "RS", "V", "X"]
    wallpapers = [card.wallpaper for card in state.monitors] or [state.theme_name]
    lane_index = rng.choice([0, 1, 2])
    speed_floor = 162 + rng.randint(0, 26) + (16 if not state.git_clean else 0)
    if vehicle_kind == "motorcycle":
        speed_floor += 12
    speed_peak = 272 + rng.randint(0, 116) + (18 if state.appearance_mode == "auto" else 0)
    if vehicle_kind == "motorcycle":
        speed_peak += 26

    return DriveSequence(
        seed=seed,
        started_at=time.monotonic(),
        last_tick=time.monotonic(),
        lane_bias=lane_index - 1,
        vehicle_kind=vehicle_kind,
        style=style,
        model=f"{rng.choice(model_roots[style])} {rng.choice(suffixes)}",
        route=billboard_label(rng.choice(wallpapers), "NIGHT GRID"),
        billboard_left=billboard_label(state.theme_name or state.appearance_mode, "ARCHMEROS"),
        billboard_right=billboard_label(state.branch, "MIDNIGHT"),
        speed_floor=speed_floor,
        speed_peak=speed_peak,
        curve_amplitude=rng.uniform(0.10, 0.27),
        curve_speed=rng.uniform(0.55, 1.15),
        wobble=rng.uniform(1.7, 2.9),
        drift_phase=rng.uniform(0.0, math.tau),
        lane=lane_index,
        desired_lane=lane_index,
        lane_position=float(lane_index - 1),
        speed=float(speed_floor + ((speed_peak - speed_floor) * 0.18)),
        score=0,
        passed=0,
        distance=0.0,
        spawn_timer=rng.uniform(0.55, 1.10),
        traffic=[],
        crashed=False,
        crash_flash=0.0,
    )


class Canvas:
    def __init__(self, width: int, height: int, bg: RGB | None = None) -> None:
        self.width = width
        self.height = height
        self.cells = [Cell(bg=bg) for _ in range(width * height)]

    def _index(self, x: int, y: int) -> int:
        return y * self.width + x

    def set(self, x: int, y: int, char: str = " ", fg: RGB | None = None, bg: RGB | None = None) -> None:
        if not (0 <= x < self.width and 0 <= y < self.height):
            return
        cell = self.cells[self._index(x, y)]
        cell.char = char[:1]
        if fg is not None:
            cell.fg = fg
        if bg is not None:
            cell.bg = bg

    def fill_rect(self, x: int, y: int, width: int, height: int, bg: RGB | None = None, fg: RGB | None = None, char: str = " ") -> None:
        x0 = max(0, x)
        y0 = max(0, y)
        x1 = min(self.width, x + width)
        y1 = min(self.height, y + height)
        for row in range(y0, y1):
            for column in range(x0, x1):
                self.set(column, row, char=char, fg=fg, bg=bg)

    def text(self, x: int, y: int, text: str, fg: RGB | None = None, bg: RGB | None = None, max_width: int | None = None) -> None:
        if y < 0 or y >= self.height or x >= self.width:
            return
        if max_width is None:
            max_width = self.width - x
        trimmed = text[: max(0, max_width)]
        for offset, char in enumerate(trimmed):
            self.set(x + offset, y, char=char, fg=fg, bg=bg)

    def box(self, x: int, y: int, width: int, height: int, title: str, border_fg: RGB, bg: RGB, title_fg: RGB | None = None) -> None:
        if width < 4 or height < 3:
            return
        self.fill_rect(x, y, width, height, bg=bg)
        right = x + width - 1
        bottom = y + height - 1
        for column in range(x + 1, right):
            self.set(column, y, "-", fg=border_fg, bg=bg)
            self.set(column, bottom, "-", fg=border_fg, bg=bg)
        for row in range(y + 1, bottom):
            self.set(x, row, "|", fg=border_fg, bg=bg)
            self.set(right, row, "|", fg=border_fg, bg=bg)
        self.set(x, y, "+", fg=border_fg, bg=bg)
        self.set(right, y, "+", fg=border_fg, bg=bg)
        self.set(x, bottom, "+", fg=border_fg, bg=bg)
        self.set(right, bottom, "+", fg=border_fg, bg=bg)
        title_text = f" {title} "
        self.text(x + 2, y, title_text[: max(0, width - 4)], fg=title_fg or border_fg, bg=bg, max_width=max(0, width - 4))

    def wrapped_text(self, x: int, y: int, width: int, text: str, fg: RGB, bg: RGB | None = None, max_lines: int | None = None) -> int:
        lines = textwrap.wrap(text, width=max(1, width)) or [""]
        if max_lines is not None:
            lines = lines[:max_lines]
        for index, line in enumerate(lines):
            self.text(x, y + index, line, fg=fg, bg=bg, max_width=width)
        return len(lines)

    def render(self, color: bool = True, home: bool = True) -> str:
        output = ["\x1b[H"] if home else []
        for row in range(self.height):
            current_fg: RGB | None = None
            current_bg: RGB | None = None
            for column in range(self.width):
                cell = self.cells[self._index(column, row)]
                if color:
                    if cell.fg != current_fg:
                        output.append(ansi_fg(cell.fg))
                        current_fg = cell.fg
                    if cell.bg != current_bg:
                        output.append(ansi_bg(cell.bg))
                        current_bg = cell.bg
                output.append(cell.char)
            if color:
                output.append("\x1b[0m")
            if row != self.height - 1:
                output.append("\n")
        if color:
            output.append("\x1b[0m")
        return "".join(output)


class TerminalController:
    def __init__(self) -> None:
        self.fd = sys.stdin.fileno()
        self.original: list | None = None

    def __enter__(self) -> "TerminalController":
        self.original = termios.tcgetattr(self.fd)
        tty.setcbreak(self.fd)
        sys.stdout.write("\x1b[?1049h\x1b[?25l\x1b[2J\x1b[H")
        sys.stdout.flush()
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        if self.original is not None:
            termios.tcsetattr(self.fd, termios.TCSADRAIN, self.original)
        sys.stdout.write("\x1b[0m\x1b[?25h\x1b[?1049l")
        sys.stdout.flush()

    def read_keys(self, timeout: float) -> list[str]:
        ready, _, _ = select.select([self.fd], [], [], timeout)
        if not ready:
            return []
        data = os.read(self.fd, 64).decode("utf-8", "ignore")
        keys: list[str] = []
        index = 0
        while index < len(data):
            chunk = data[index:]
            if chunk.startswith("\x1b[A"):
                keys.append("UP")
                index += 3
            elif chunk.startswith("\x1b[B"):
                keys.append("DOWN")
                index += 3
            elif chunk.startswith("\x1b[C"):
                keys.append("RIGHT")
                index += 3
            elif chunk.startswith("\x1b[D"):
                keys.append("LEFT")
                index += 3
            elif chunk.startswith("\x1b[Z"):
                keys.append("SHIFT_TAB")
                index += 3
            else:
                keys.append(chunk[0])
                index += 1
        return keys


class NightDriveApp:
    def __init__(self, *, screensaver: bool = False) -> None:
        self.view_index = 0
        self.ritual_index = 0
        self.transmission_index = 0
        self.sequence_offset = 0
        self.show_help = False
        self.glitch = True
        self.frame = 0
        self.drive_sequence: DriveSequence | None = None
        self.state = build_state(self.sequence_offset)
        self.last_refresh = time.monotonic()
        self.screensaver = screensaver
        self.screensaver_started_at = time.monotonic()
        if self.screensaver:
            self.start_drive_sequence()

    def palette_rgb(self, name: str, fallback: str) -> RGB:
        return parse_rgb(self.state.palette.get(name, fallback), parse_rgb(fallback, (255, 255, 255)))

    def refresh_state_if_needed(self, force: bool = False) -> None:
        now = time.monotonic()
        if force or now - self.last_refresh >= 4.0:
            self.state = build_state(self.sequence_offset)
            if self.state.rituals:
                self.ritual_index %= len(self.state.rituals)
            if self.state.transmission_pool:
                self.transmission_index %= len(self.state.transmission_pool)
            self.last_refresh = now

    def cycle_view(self, direction: int) -> None:
        self.view_index = (self.view_index + direction) % 3

    def active_drive_sequence(self) -> DriveSequence | None:
        return self.drive_sequence

    def start_drive_sequence(self) -> None:
        self.refresh_state_if_needed(force=True)
        self.show_help = False
        self.drive_sequence = build_drive_sequence(self.state, self.frame, self.sequence_offset)
        if self.screensaver:
            self.drive_sequence.traffic.clear()
            self.drive_sequence.spawn_timer = 9999.0

    def reroll(self) -> None:
        self.sequence_offset += 1
        self.transmission_index = (self.transmission_index + 1) % max(1, len(self.state.transmission_pool))
        self.refresh_state_if_needed(force=True)

    def handle_key(self, key: str) -> bool:
        if self.screensaver and key:
            return False
        drive_sequence = self.active_drive_sequence()
        if key in {"q", "Q"}:
            return False
        if key == "\x1b":
            if drive_sequence is not None:
                self.drive_sequence = None
                return True
            return False
        if key in {"\r", "\n"}:
            self.start_drive_sequence()
            return True
        if drive_sequence is not None:
            if not drive_sequence.crashed:
                if key in {"LEFT", "a", "A"}:
                    drive_sequence.desired_lane = max(0, drive_sequence.desired_lane - 1)
                    return True
                if key in {"RIGHT", "d", "D"}:
                    drive_sequence.desired_lane = min(2, drive_sequence.desired_lane + 1)
                    return True
                if key in {"UP", "w", "W"}:
                    drive_sequence.speed = min(float(drive_sequence.speed_peak), drive_sequence.speed + (30 if drive_sequence.vehicle_kind == "motorcycle" else 24))
                    return True
                if key in {"DOWN", "s", "S"}:
                    drive_sequence.speed = max(92.0, drive_sequence.speed - 32)
                    return True
            if key in {"r", "R", " "}:
                self.start_drive_sequence()
            elif key in {"h", "H", "?"}:
                self.show_help = not self.show_help
            return True
        if key in {"1", "2", "3"}:
            self.view_index = int(key) - 1
        elif key in {"\t", "RIGHT"}:
            self.cycle_view(1)
        elif key in {"SHIFT_TAB", "LEFT"}:
            self.cycle_view(-1)
        elif key in {"j", "J", "DOWN"} and self.state.rituals:
            self.ritual_index = (self.ritual_index + 1) % len(self.state.rituals)
        elif key in {"k", "K", "UP"} and self.state.rituals:
            self.ritual_index = (self.ritual_index - 1) % len(self.state.rituals)
        elif key in {"r", "R"}:
            self.reroll()
        elif key in {"g", "G"}:
            self.glitch = not self.glitch
        elif key in {"h", "H", "?"}:
            self.show_help = not self.show_help
        return True

    def drive_road_geometry(
        self,
        canvas: Canvas,
        row: int,
        road_top: int,
        road_bottom: int,
        primary_curve: float,
        secondary_curve: float,
    ) -> tuple[float, int, int]:
        depth = (row - road_top) / max(1, road_bottom - road_top)
        center_offset = int((primary_curve * depth + secondary_curve * (depth * depth)) * canvas.width * 0.18)
        center = (canvas.width // 2) + center_offset
        half_width = int((canvas.width * 0.06) + (canvas.width * 0.48 * (depth ** 1.18)))
        return (depth, center, half_width)

    def draw_drive_billboard(
        self,
        canvas: Canvas,
        x: int,
        y: int,
        width: int,
        label: str,
        border: RGB,
        bg: RGB,
        post_x: int,
        post_bottom: int,
    ) -> None:
        box_width = max(12, min(width, len(label) + 4))
        if box_width < 12 or y < 4 or y + 3 >= post_bottom or x < 1 or x + box_width >= canvas.width - 1:
            return
        canvas.box(x, y, box_width, 3, label, border, bg, title_fg=lighten(border, 0.32))
        post_color = mix(border, bg, 0.35)
        for row in range(y + 3, min(canvas.height - 3, post_bottom)):
            if (row - y) % 2 == 0:
                canvas.set(post_x, row, "|", fg=post_color)

    def update_drive_sequence(self, sequence: DriveSequence) -> None:
        now = time.monotonic()
        delta = min(0.12, max(0.0, now - sequence.last_tick))
        sequence.last_tick = now
        if delta <= 0.0:
            return

        if self.screensaver:
            sequence.desired_lane = 1

        lane_target = float(sequence.desired_lane - 1)
        lane_snap = 12.0 if sequence.vehicle_kind == "motorcycle" else 8.0
        sequence.lane_position += (lane_target - sequence.lane_position) * min(1.0, delta * lane_snap)
        sequence.lane = int(round(sequence.lane_position + 1))

        if sequence.crashed:
            sequence.speed = max(0.0, sequence.speed - (180.0 * delta))
            sequence.crash_flash = max(0.0, sequence.crash_flash - (delta * 1.8))
            return

        ambient_speed = sequence.speed_floor + ((sequence.speed_peak - sequence.speed_floor) * 0.28)
        ambient_speed += math.sin((now - sequence.started_at) * sequence.curve_speed) * 8.0
        sequence.speed += (ambient_speed - sequence.speed) * min(1.0, delta * 0.75)
        sequence.speed = max(92.0, min(float(sequence.speed_peak), sequence.speed))
        sequence.distance += sequence.speed * delta * 0.12

        if self.screensaver:
            return

        sequence.spawn_timer -= delta * (0.95 + ((sequence.speed / max(1.0, sequence.speed_peak)) * 1.2))
        if sequence.spawn_timer <= 0.0 and len(sequence.traffic) < 7:
            rng = random.Random(sequence.seed + int(sequence.distance * 10) + len(sequence.traffic) * 37 + self.frame)
            occupied = {traffic.lane for traffic in sequence.traffic if traffic.depth < 0.30}
            candidate_lanes = [lane for lane in (0, 1, 2) if lane not in occupied] or [0, 1, 2]
            vehicle_kind = rng.choice(["car", "motorcycle", "car"])
            if vehicle_kind == "motorcycle":
                style = rng.choice(["kaneda", "street", "phantom"])
                speed_factor = rng.uniform(0.95, 1.30)
            else:
                style = rng.choice(["wedge", "interceptor", "phantom"])
                speed_factor = rng.uniform(0.78, 1.12)
            sequence.traffic.append(
                TrafficObstacle(
                    lane=rng.choice(candidate_lanes),
                    depth=0.02,
                    vehicle_kind=vehicle_kind,
                    style=style,
                    speed_factor=speed_factor,
                    phase=rng.uniform(0.0, math.tau),
                )
            )
            sequence.spawn_timer = rng.uniform(0.48, 1.08) * (300.0 / max(140.0, sequence.speed))

        next_traffic: list[TrafficObstacle] = []
        for traffic in sequence.traffic:
            traffic.depth += delta * (0.26 + ((sequence.speed / max(1.0, sequence.speed_peak)) * 0.65)) * traffic.speed_factor

            if not traffic.passed and 0.86 <= traffic.depth <= 1.04:
                lane_gap = abs((traffic.lane - 1) - sequence.lane_position)
                collision_threshold = 0.18 if sequence.vehicle_kind == "motorcycle" else 0.28
                if lane_gap <= collision_threshold:
                    sequence.crashed = True
                    sequence.crash_flash = 1.0
                    sequence.speed *= 0.45
                    traffic.passed = True
            if not traffic.passed and traffic.depth > 1.01:
                traffic.passed = True
                if not sequence.crashed:
                    sequence.passed += 1
                    sequence.score += 120 + int(sequence.speed * 0.7) + (60 if sequence.vehicle_kind == "motorcycle" else 0)

            if traffic.depth <= 1.20:
                next_traffic.append(traffic)
        sequence.traffic = next_traffic

    def draw_drive_obstacle(
        self,
        canvas: Canvas,
        sequence: DriveSequence,
        traffic: TrafficObstacle,
        road_top: int,
        road_bottom: int,
        primary_curve: float,
        secondary_curve: float,
    ) -> None:
        accent = self.palette_rgb("accent", DEFAULT_PALETTE["accent"])
        accent2 = self.palette_rgb("accent2", DEFAULT_PALETTE["accent2"])
        accent3 = self.palette_rgb("accent3", DEFAULT_PALETTE["accent3"])
        text = self.palette_rgb("text", DEFAULT_PALETTE["text"])
        warning = self.palette_rgb("warning", DEFAULT_PALETTE["warning"])
        green = self.palette_rgb("green", DEFAULT_PALETTE["green"])
        palette = {
            "wedge": accent,
            "interceptor": accent3,
            "phantom": mix(accent2, accent3, 0.40),
            "kaneda": accent2,
            "street": green,
        }

        row = road_top + int((road_bottom - road_top) * min(1.0, traffic.depth))
        depth, center, half_width = self.drive_road_geometry(canvas, row, road_top, road_bottom, primary_curve, secondary_curve)
        lane_center = center + int((traffic.lane - 1) * half_width * 0.34)
        road_bg = mix(darken(self.palette_rgb("base", DEFAULT_PALETTE["base"]), 0.34), darken(accent3, 0.78), depth * 0.18)
        body = palette.get(traffic.style, accent)
        edge = lighten(body, 0.18)
        headlight = warning if traffic.vehicle_kind == "car" else accent

        if traffic.vehicle_kind == "motorcycle":
            width = max(3, int(2 + (depth * 5.0)))
            height = max(3, int(2 + (depth * 4.0)))
            x = lane_center - (width // 2)
            y = row - height + 1
            if y < road_top or x < 1 or x + width >= canvas.width - 1:
                return
            canvas.fill_rect(x + 1, y, max(1, width - 2), 1, bg=lighten(body, 0.14))
            if height >= 4:
                canvas.set(x + (width // 2), y, "^", fg=text, bg=lighten(body, 0.14))
            canvas.fill_rect(x, y + 1, width, 1, bg=body)
            canvas.fill_rect(x + 1, y + 2, max(1, width - 2), 1, bg=darken(body, 0.10))
            wheel_row = y + height - 1
            canvas.set(x + 1, wheel_row, "o", fg=text, bg=road_bg)
            canvas.set(x + width - 2, wheel_row, "o", fg=text, bg=road_bg)
            if depth > 0.34:
                canvas.set(x + (width // 2), y + 1, "*", fg=headlight, bg=body)
            return

        width = max(4, int(3 + (depth * 9.0)))
        height = max(3, int(2 + (depth * 4.2)))
        x = lane_center - (width // 2)
        y = row - height + 1
        if y < road_top or x < 1 or x + width >= canvas.width - 1:
            return
        roof_width = max(2, width - 2)
        canvas.fill_rect(x + 1, y, roof_width, 1, bg=lighten(body, 0.12))
        canvas.fill_rect(x, y + 1, width, 1, bg=body)
        canvas.fill_rect(x, y + 2, width, 1, bg=darken(body, 0.10))
        if height >= 4:
            canvas.fill_rect(x + 1, y + 3, max(2, width - 2), 1, bg=darken(body, 0.16))
        canvas.set(x + 1, y + 1, "/", fg=edge, bg=body)
        canvas.set(x + width - 2, y + 1, "\\", fg=edge, bg=body)
        canvas.set(x + 1, y + height - 1, "*", fg=headlight, bg=road_bg)
        canvas.set(x + width - 2, y + height - 1, "*", fg=headlight, bg=road_bg)

    def draw_drive_car(
        self,
        canvas: Canvas,
        center_x: int,
        base_y: int,
        sequence: DriveSequence,
        road_bg: RGB,
    ) -> None:
        accent = self.palette_rgb("accent", DEFAULT_PALETTE["accent"])
        accent2 = self.palette_rgb("accent2", DEFAULT_PALETTE["accent2"])
        accent3 = self.palette_rgb("accent3", DEFAULT_PALETTE["accent3"])
        text = self.palette_rgb("text", DEFAULT_PALETTE["text"])
        warning = self.palette_rgb("warning", DEFAULT_PALETTE["warning"])
        green = self.palette_rgb("green", DEFAULT_PALETTE["green"])

        style_body = {
            "wedge": accent,
            "interceptor": accent3,
            "phantom": mix(accent2, accent3, 0.45),
            "kaneda": accent2,
            "street": green,
        }
        body = style_body.get(sequence.style, accent)
        roof = lighten(mix(body, accent2, 0.18), 0.08)
        body_dark = darken(body, 0.16)
        edge = lighten(body, 0.22)
        underglow = mix(body, accent3, 0.30)
        taillight = accent2 if sequence.style != "interceptor" else warning

        vehicle_width = 11 if sequence.vehicle_kind == "motorcycle" else (13 if canvas.width >= 110 else 11)
        x = center_x - (vehicle_width // 2)
        y = base_y - 4
        if x < 1 or x + vehicle_width >= canvas.width - 1 or y < 3 or y + 5 >= canvas.height - 2:
            return

        if sequence.vehicle_kind == "motorcycle":
            canvas.fill_rect(x + 3, y + 4, max(2, vehicle_width - 6), 1, bg=underglow)
            canvas.text(x + 3, y, "__", fg=edge, bg=road_bg, max_width=2)
            canvas.fill_rect(x + 2, y + 1, max(3, vehicle_width - 4), 1, bg=roof)
            canvas.fill_rect(x + 1, y + 2, max(5, vehicle_width - 2), 1, bg=body)
            canvas.fill_rect(x + 2, y + 3, max(3, vehicle_width - 4), 1, bg=body_dark)
            head_x = x + (vehicle_width // 2)
            canvas.set(head_x, y + 1, "^", fg=text, bg=roof)
            canvas.set(head_x, y + 2, "*", fg=warning, bg=body)
            canvas.set(x + 2, y + 4, "o", fg=text, bg=road_bg)
            canvas.set(x + vehicle_width - 3, y + 4, "o", fg=text, bg=road_bg)
            for streak in range(1, 3):
                if y + 4 + streak >= canvas.height - 2:
                    break
                canvas.set(head_x, y + 4 + streak, "|", fg=accent2, bg=road_bg)
            return

        # Glow under the car.
        canvas.fill_rect(x + 2, y + 4, vehicle_width - 4, 1, bg=underglow)

        if sequence.style == "wedge":
            layers = [
                (3, vehicle_width - 6, roof),
                (2, vehicle_width - 4, lighten(body, 0.04)),
                (1, vehicle_width - 2, body),
                (0, vehicle_width, body_dark),
            ]
        elif sequence.style == "interceptor":
            layers = [
                (2, vehicle_width - 4, roof),
                (1, vehicle_width - 2, body),
                (1, vehicle_width - 2, body),
                (0, vehicle_width, body_dark),
            ]
        else:
            layers = [
                (3, vehicle_width - 6, roof),
                (2, vehicle_width - 4, mix(body, accent, 0.18)),
                (1, vehicle_width - 2, body),
                (1, vehicle_width - 2, body_dark),
            ]

        for row_index, (offset, width, color) in enumerate(layers):
            row = y + row_index
            left = x + offset
            canvas.fill_rect(left, row, width, 1, bg=color)
            if offset > 0:
                canvas.set(left - 1, row, "/" if row_index < 2 else "|", fg=edge, bg=road_bg)
            if left + width < x + vehicle_width:
                canvas.set(left + width, row, "\\" if row_index < 2 else "|", fg=edge, bg=road_bg)

        cockpit_width = max(2, vehicle_width - 8)
        canvas.fill_rect(x + 4, y + 1, cockpit_width, 1, bg=lighten(roof, 0.16))
        canvas.text(x + 4, y + 1, "_" * cockpit_width, fg=text, bg=lighten(roof, 0.16), max_width=cockpit_width)

        # Rear deck, lights, wheels, and light trails.
        tail_y = y + 4
        canvas.fill_rect(x + 1, tail_y, vehicle_width - 2, 1, bg=darken(body_dark, 0.06))
        canvas.set(x + 2, tail_y, "*", fg=taillight, bg=darken(body_dark, 0.06))
        canvas.set(x + vehicle_width - 3, tail_y, "*", fg=taillight, bg=darken(body_dark, 0.06))
        canvas.set(x + 2, tail_y + 1, "o", fg=text, bg=road_bg)
        canvas.set(x + vehicle_width - 3, tail_y + 1, "o", fg=text, bg=road_bg)

        trail_length = 2 + int((time.monotonic() * 10) % 2)
        for streak in range(1, trail_length + 1):
            if tail_y + streak >= canvas.height - 2:
                break
            canvas.set(x + 2, tail_y + streak, "|", fg=taillight, bg=road_bg)
            canvas.set(x + vehicle_width - 3, tail_y + streak, "|", fg=taillight, bg=road_bg)

    def draw_drive_sequence(self, canvas: Canvas, sequence: DriveSequence) -> None:
        self.update_drive_sequence(sequence)
        accent = self.palette_rgb("accent", DEFAULT_PALETTE["accent"])
        accent2 = self.palette_rgb("accent2", DEFAULT_PALETTE["accent2"])
        accent3 = self.palette_rgb("accent3", DEFAULT_PALETTE["accent3"])
        text = self.palette_rgb("text", DEFAULT_PALETTE["text"])
        subtext = self.palette_rgb("subtext1", DEFAULT_PALETTE["subtext1"])
        warning = self.palette_rgb("warning", DEFAULT_PALETTE["warning"])
        crust = self.palette_rgb("crust", DEFAULT_PALETTE["crust"])
        mantle = self.palette_rgb("mantle", DEFAULT_PALETTE["mantle"])
        base = self.palette_rgb("base", DEFAULT_PALETTE["base"])

        elapsed = time.monotonic() - sequence.started_at
        progress = min(1.0, sequence.speed / max(1.0, sequence.speed_peak))
        acceleration = ease_out_expo(progress)
        sway = math.sin(elapsed * sequence.wobble + sequence.drift_phase)
        speed = int(sequence.speed + sway * 4)

        horizon = max(7, canvas.height // 4)
        road_top = horizon + 2
        road_bottom = canvas.height - 4
        primary_curve = math.sin(elapsed * sequence.curve_speed + sequence.drift_phase) * sequence.curve_amplitude
        secondary_curve = math.sin(elapsed * (sequence.curve_speed * 0.58) + (sequence.seed % 23)) * sequence.curve_amplitude * 0.42

        for row in range(canvas.height):
            shade = mix(crust, darken(accent, 0.86), min(1.0, row / max(1, canvas.height - 1)) * 0.18)
            canvas.fill_rect(0, row, canvas.width, 1, bg=shade)

        for row in range(3, horizon):
            if row % 4 == (self.frame % 4):
                scan_color = mix(accent3, crust, 0.88)
                canvas.fill_rect(0, row, canvas.width, 1, bg=mix(crust, accent3, 0.02))
                for column in range(row % 5, canvas.width, 11):
                    canvas.set(column, row, ".", fg=scan_color)

        star_rng = random.Random(sequence.seed)
        for index in range(max(22, canvas.width // 3)):
            x = (star_rng.randrange(0, canvas.width) + int(elapsed * (1 + (index % 3)))) % canvas.width
            y = star_rng.randrange(3, max(4, horizon - 1))
            twinkle = (self.frame + index) % 7
            star_color = accent2 if twinkle == 0 else (accent3 if twinkle in {1, 2} else lighten(base, 0.60))
            canvas.set(x, y, "*" if twinkle == 0 else ".", fg=star_color)

        sun_center_x = (canvas.width // 2) + int(primary_curve * canvas.width * 0.12)
        sun_center_y = max(5, horizon - 4)
        sun_radius = max(5, min(canvas.width // 10, canvas.height // 6))
        for row in range(sun_center_y - sun_radius, sun_center_y + sun_radius):
            for column in range(sun_center_x - (sun_radius * 2), sun_center_x + (sun_radius * 2)):
                dx = (column - sun_center_x) / max(1, sun_radius * 1.7)
                dy = (row - sun_center_y) / max(1, sun_radius)
                distance = math.sqrt((dx * dx) + (dy * dy))
                if distance <= 1.0 and row < road_top - 1:
                    glow = mix(accent2, warning, min(1.0, distance * 0.55))
                    if (row + self.frame) % 3 == 0 and distance > 0.45:
                        glow = mix(glow, accent3, 0.24)
                    canvas.set(column, row, " ", bg=glow)

        skyline_rng = random.Random(sequence.seed + 77)
        skyline_shift = int(elapsed * (3.0 + acceleration * 6.0)) % 18
        column = -18 + skyline_shift
        city_color = mix(base, accent3, 0.14)
        window_color = lighten(accent, 0.20)
        while column < canvas.width + 18:
            tower_width = skyline_rng.randint(5, 12)
            tower_height = skyline_rng.randint(4, max(6, road_top - 4))
            left = column
            top = road_top - tower_height
            canvas.fill_rect(left, top, min(tower_width, canvas.width - left), tower_height, bg=city_color)
            for win_y in range(top + 1, road_top - 1, 2):
                for win_x in range(left + 1, min(canvas.width - 1, left + tower_width - 1), 2):
                    if skyline_rng.random() > 0.52:
                        canvas.set(win_x, win_y, ".", fg=window_color, bg=city_color)
            column += tower_width

        for row in range(road_top, road_bottom + 1):
            depth, center, half_width = self.drive_road_geometry(canvas, row, road_top, road_bottom, primary_curve, secondary_curve)
            left = max(0, center - half_width)
            right = min(canvas.width - 1, center + half_width)
            road_bg = mix(darken(base, 0.34), darken(accent3, 0.78), depth * 0.18)
            canvas.fill_rect(left, row, max(1, right - left + 1), 1, bg=road_bg)

            edge_color = accent if ((row + self.frame) % 4 < 2) else accent3
            canvas.set(left, row, "/", fg=edge_color, bg=road_bg)
            canvas.set(right, row, "\\", fg=edge_color, bg=road_bg)

            shoulder_glow = accent2 if (row + self.frame) % 5 == 0 else accent
            if left - 1 >= 0:
                canvas.set(left - 1, row, ".", fg=shoulder_glow)
            if right + 1 < canvas.width:
                canvas.set(right + 1, row, ".", fg=shoulder_glow)

            for divider in (-1, 1):
                lane_x = center + int(divider * half_width * 0.34)
                band = (((1.0 - depth) * 20.0) + elapsed * (7.0 + acceleration * 10.0) + (divider * 2.5)) % 8.0
                if band < 1.8 + (depth * 2.3):
                    stripe_half = max(1, int(1 + depth * 3.4))
                    stripe_color = accent2 if divider > 0 else accent
                    for offset in range(-stripe_half, stripe_half + 1):
                        canvas.set(lane_x + offset, row, "|", fg=stripe_color, bg=road_bg)

        for traffic in sorted(sequence.traffic, key=lambda item: item.depth):
            self.draw_drive_obstacle(canvas, sequence, traffic, road_top, road_bottom, primary_curve, secondary_curve)

        billboard_specs = [
            (0.18, -1, sequence.billboard_left, accent),
            (0.32, 1, sequence.route, accent2),
            (0.50, -1, sequence.billboard_right, accent3),
        ]
        for depth, side, label, border in billboard_specs:
            row = road_top + int((road_bottom - road_top) * depth)
            _, center, half_width = self.drive_road_geometry(canvas, row, road_top, road_bottom, primary_curve, secondary_curve)
            sign_width = 18 if depth < 0.3 else 16
            sign_x = center - half_width - sign_width - 5 if side < 0 else center + half_width + 5
            post_x = sign_x + sign_width - 3 if side < 0 else sign_x + 2
            sign_bg = mix(mantle, border, 0.10)
            self.draw_drive_billboard(canvas, sign_x, row - 1, sign_width, label, border, sign_bg, post_x, row + 8)

        header_bg = mix(mantle, accent, 0.12)
        canvas.fill_rect(0, 0, canvas.width, 3, bg=header_bg)
        vehicle_label = "MOTORCYCLE" if sequence.vehicle_kind == "motorcycle" else "CAR"
        left_header = f" MIDNIGHT RUN // {sequence.model} // {vehicle_label} "
        right_header = f" {speed:03d} KM/H "
        canvas.text(2, 0, left_header, fg=accent2, bg=header_bg, max_width=max(0, canvas.width - 4))
        canvas.text(max(2, canvas.width - len(right_header) - 2), 0, right_header, fg=warning, bg=header_bg, max_width=len(right_header))
        control_hint = " ARROWS STEER // ENTER NEW RUN "
        route_text = f" route {sequence.route}  score {sequence.score:05d}  passed {sequence.passed:02d}  lane {sequence.desired_lane + 1}/3 "
        canvas.text(2, 1, route_text, fg=text, bg=header_bg, max_width=max(0, canvas.width - len(control_hint) - 6))
        canvas.text(max(2, canvas.width - len(control_hint) - 2), 1, control_hint, fg=subtext, bg=header_bg, max_width=len(control_hint))
        for column in range(canvas.width):
            line_color = accent if column % 2 == 0 else accent3
            canvas.set(column, 2, "-", fg=line_color, bg=header_bg)

        bottom_depth, road_center, road_half_width = self.drive_road_geometry(canvas, road_bottom, road_top, road_bottom, primary_curve, secondary_curve)
        lane_offset = int(sequence.lane_position * road_half_width * 0.24)
        wobble_offset = int(math.sin(elapsed * sequence.wobble + sequence.drift_phase) * max(1, road_half_width * (0.04 if sequence.vehicle_kind == "motorcycle" else 0.03)))
        car_center = road_center + lane_offset + wobble_offset
        road_bg = mix(darken(base, 0.34), darken(accent3, 0.78), bottom_depth * 0.18)
        self.draw_drive_car(canvas, car_center, road_bottom - 1, sequence, road_bg)

        footer_bg = mix(crust, accent3, 0.08)
        canvas.fill_rect(0, canvas.height - 2, canvas.width, 2, bg=footer_bg)
        if sequence.crashed:
            footer = " WRECKED // Enter restart  Esc cockpit  q exit  ? help "
            descriptor = f" {sequence.model} folded on the {sequence.route} line at {int(sequence.distance)} m "
        else:
            footer = " Left/Right steer  Up boost  Down brake  Enter reroll  Esc cockpit "
            descriptor = f" {sequence.model} is slicing through {self.state.wallpaper_signature} at {int(sequence.distance)} m "
        canvas.text(1, canvas.height - 2, footer, fg=text, bg=footer_bg, max_width=max(0, canvas.width - 2))
        canvas.text(1, canvas.height - 1, descriptor, fg=subtext, bg=footer_bg, max_width=max(0, canvas.width - 2))

        if sequence.crashed:
            overlay_w = min(54, canvas.width - 10)
            overlay_x = max(4, (canvas.width - overlay_w) // 2)
            overlay_y = max(5, road_top + ((road_bottom - road_top) // 3))
            overlay_bg = mix(mantle, accent2, 0.14)
            canvas.box(overlay_x, overlay_y, overlay_w, 5, "CRASH", accent2, overlay_bg, title_fg=text)
            canvas.text(overlay_x + 2, overlay_y + 2, "Neon everywhere. Your line broke.", fg=text, bg=overlay_bg, max_width=max(0, overlay_w - 4))
            canvas.text(overlay_x + 2, overlay_y + 3, "Enter restarts. Esc returns to the cockpit.", fg=subtext, bg=overlay_bg, max_width=max(0, overlay_w - 4))

    def draw_screensaver_sequence(self, canvas: Canvas, sequence: DriveSequence) -> None:
        self.draw_drive_sequence(canvas, sequence)
        crust = self.palette_rgb("crust", DEFAULT_PALETTE["crust"])
        accent = self.palette_rgb("accent", DEFAULT_PALETTE["accent"])
        accent2 = self.palette_rgb("accent2", DEFAULT_PALETTE["accent2"])
        text = self.palette_rgb("text", DEFAULT_PALETTE["text"])

        canvas.fill_rect(0, 0, canvas.width, 3, bg=crust)
        canvas.fill_rect(0, canvas.height - 2, canvas.width, 2, bg=crust)

        label = " ARCHMEROS NIGHT DRIVE "
        pulse = accent2 if (self.frame // 12) % 2 == 0 else accent
        x = max(2, (canvas.width - len(label)) // 2)
        canvas.text(x, canvas.height - 1, label, fg=pulse, bg=crust, max_width=len(label))

    def draw_background(self, canvas: Canvas) -> None:
        crust = self.palette_rgb("crust", DEFAULT_PALETTE["crust"])
        base = self.palette_rgb("base", DEFAULT_PALETTE["base"])
        accent = self.palette_rgb("accent", DEFAULT_PALETTE["accent"])
        accent2 = self.palette_rgb("accent2", DEFAULT_PALETTE["accent2"])
        accent3 = self.palette_rgb("accent3", DEFAULT_PALETTE["accent3"])
        horizon = max(12, canvas.height // 2)

        for row in range(canvas.height):
            shade = mix(crust, darken(accent, 0.84), min(1.0, row / max(1, canvas.height - 1)) * 0.22)
            canvas.fill_rect(0, row, canvas.width, 1, bg=shade)

        if self.glitch:
            grid_color = mix(accent3, crust, 0.84)
            for column in range(0, canvas.width, 7):
                limit = max(3, horizon - 6)
                for row in range(2, limit):
                    if (row + column + self.frame) % 5 == 0:
                        canvas.set(column, row, ".", fg=grid_color, bg=None)

        seed = sum(ord(char) for char in self.state.wallpaper_signature + self.state.theme_name)
        star_rng = random.Random(seed)
        star_count = max(18, canvas.width // 4)
        for index in range(star_count):
            x = star_rng.randrange(0, canvas.width)
            y = star_rng.randrange(1, max(2, horizon - 7))
            blink = (self.frame + index) % 6
            color = accent2 if blink == 0 else (accent3 if blink in {1, 2} else lighten(base, 0.58))
            canvas.set(x, y, "." if blink else "*", fg=color)

        sun_center_x = canvas.width // 2
        sun_center_y = max(6, horizon - 8)
        sun_radius = max(6, min(canvas.width // 7, canvas.height // 4))
        for row in range(sun_center_y - sun_radius, sun_center_y + sun_radius):
            for column in range(sun_center_x - (sun_radius * 2), sun_center_x + (sun_radius * 2)):
                dx = (column - sun_center_x) / max(1, sun_radius * 1.8)
                dy = (row - sun_center_y) / max(1, sun_radius)
                distance = math.sqrt((dx * dx) + (dy * dy))
                if distance <= 1.0 and row < horizon - 1:
                    bg = mix(accent2, accent, min(1.0, distance * 0.72))
                    if (row + self.frame) % 3 == 0 and distance > 0.45:
                        bg = mix(bg, accent3, 0.22)
                    canvas.set(column, row, " ", bg=bg)

        skyline_rng = random.Random(seed + 77)
        column = 0
        city_color = mix(base, accent3, 0.12)
        window_color = lighten(accent, 0.18)
        while column < canvas.width:
            width = skyline_rng.randint(4, 10)
            height = skyline_rng.randint(4, max(5, horizon - 4))
            left = column
            top = horizon - height
            canvas.fill_rect(left, top, min(width, canvas.width - left), height, bg=city_color)
            for win_y in range(top + 1, horizon - 1, 2):
                for win_x in range(left + 1, min(canvas.width - 1, left + width - 1), 2):
                    if skyline_rng.random() > 0.55:
                        canvas.set(win_x, win_y, ".", fg=window_color, bg=city_color)
            column += width

        road_top = horizon + 1
        road_bg = darken(base, 0.3)
        for row in range(road_top, canvas.height):
            perspective = (row - road_top) / max(1, canvas.height - road_top - 1)
            half_width = int((canvas.width * 0.10) + (canvas.width * 0.46 * perspective))
            center = canvas.width // 2
            left = max(0, center - half_width)
            right = min(canvas.width - 1, center + half_width)
            canvas.fill_rect(left, row, max(1, right - left + 1), 1, bg=road_bg)
            if left > 0:
                canvas.set(left, row, "/", fg=accent, bg=road_bg)
            if right < canvas.width:
                canvas.set(right, row, "\\", fg=accent, bg=road_bg)

            lane_width = max(1, int((1.0 - perspective) * 5))
            if row % 2 == (self.frame // 2) % 2:
                for delta in range(-lane_width, lane_width + 1):
                    canvas.set(center + delta, row, "|", fg=accent2, bg=road_bg)

        bike_x = max(4, (canvas.width // 2) - 4)
        bike_y = canvas.height - 5
        if bike_y >= road_top + 1:
            bike_fg = lighten(accent2, 0.12)
            wheel_fg = lighten(accent, 0.08)
            canvas.text(bike_x, bike_y, "  __  ", fg=bike_fg, bg=road_bg)
            canvas.text(bike_x - 1, bike_y + 1, "_/[]\\_", fg=bike_fg, bg=road_bg)
            canvas.text(bike_x - 1, bike_y + 2, "o----o", fg=wheel_fg, bg=road_bg)

    def draw_header(self, canvas: Canvas) -> None:
        accent = self.palette_rgb("accent", DEFAULT_PALETTE["accent"])
        accent2 = self.palette_rgb("accent2", DEFAULT_PALETTE["accent2"])
        text = self.palette_rgb("text", DEFAULT_PALETTE["text"])
        mantle = self.palette_rgb("mantle", DEFAULT_PALETTE["mantle"])
        header_bg = mix(mantle, accent, 0.08)
        canvas.fill_rect(0, 0, canvas.width, 3, bg=header_bg)
        now = dt.datetime.now().strftime("%Y-%m-%d %H:%M")
        view_name = ["DASHBOARD", "RITUALS", "SIGNALS"][self.view_index]
        left_text = f" ARCHMEROS NIGHT DRIVE "
        right_text = f" {view_name} :: {now} "
        canvas.text(2, 0, left_text, fg=accent2, bg=header_bg, max_width=max(0, canvas.width - 4))
        canvas.text(max(2, canvas.width - len(right_text) - 2), 0, right_text, fg=text, bg=header_bg, max_width=max(0, len(right_text)))
        subtitle = f" {self.state.host} :: {self.state.theme_name} :: {self.state.appearance_mode} :: {self.state.wallpaper_signature} "
        canvas.text(2, 1, subtitle, fg=text, bg=header_bg, max_width=max(0, canvas.width - 4))
        for column in range(canvas.width):
            line_color = accent if column % 3 else accent2
            canvas.set(column, 2, "-", fg=line_color, bg=header_bg)

    def draw_footer(self, canvas: Canvas) -> None:
        text = self.palette_rgb("text", DEFAULT_PALETTE["text"])
        subtext = self.palette_rgb("subtext1", DEFAULT_PALETTE["subtext1"])
        accent = self.palette_rgb("accent", DEFAULT_PALETTE["accent"])
        footer_bg = mix(self.palette_rgb("crust", DEFAULT_PALETTE["crust"]), accent, 0.05)
        canvas.fill_rect(0, canvas.height - 2, canvas.width, 2, bg=footer_bg)
        left = " enter midnight run  1/2/3 switch view  j/k move  r reroll  g glitch  ? help  q exit "
        selected = self.state.rituals[self.ritual_index]
        right = f" armed manually: {selected.command} "
        canvas.text(1, canvas.height - 2, left, fg=text, bg=footer_bg, max_width=max(0, canvas.width - 2))
        canvas.text(1, canvas.height - 1, right, fg=subtext, bg=footer_bg, max_width=max(0, canvas.width - 2))

    def draw_machine_panel(self, canvas: Canvas, x: int, y: int, width: int, height: int, bg: RGB) -> None:
        border = self.palette_rgb("accent", DEFAULT_PALETTE["accent"])
        text = self.palette_rgb("text", DEFAULT_PALETTE["text"])
        subtext = self.palette_rgb("subtext1", DEFAULT_PALETTE["subtext1"])
        ok = self.palette_rgb("green", DEFAULT_PALETTE["green"])
        warn = self.palette_rgb("warning", DEFAULT_PALETTE["warning"])
        canvas.box(x, y, width, height, "MACHINE", border, bg, title_fg=text)
        rows = [
            ("user", f"{self.state.user}@{self.state.host}"),
            ("shell", f"{self.state.shell} on {self.state.term_name}"),
            ("desk", self.state.desktop),
            ("git", f"{self.state.branch} :: {'clean' if self.state.git_clean else 'dirty'}"),
            ("up", self.state.uptime),
            ("load", self.state.load),
            ("mem", self.state.memory),
        ]
        if self.state.battery:
            rows.append(("bat", self.state.battery))
        for index, (label, value) in enumerate(rows[: max(0, height - 3)]):
            row = y + 1 + index
            canvas.text(x + 2, row, f"{label:>4}", fg=border, bg=bg, max_width=4)
            value_fg = ok if label == "git" and self.state.git_clean else (warn if label == "bat" else subtext)
            canvas.text(x + 8, row, value[: max(0, width - 10)], fg=value_fg, bg=bg, max_width=max(0, width - 10))

    def draw_transmission_panel(self, canvas: Canvas, x: int, y: int, width: int, height: int, bg: RGB) -> None:
        accent2 = self.palette_rgb("accent2", DEFAULT_PALETTE["accent2"])
        text = self.palette_rgb("text", DEFAULT_PALETTE["text"])
        subtext = self.palette_rgb("subtext1", DEFAULT_PALETTE["subtext1"])
        accent3 = self.palette_rgb("accent3", DEFAULT_PALETTE["accent3"])
        canvas.box(x, y, width, height, "TRANSMISSION", accent2, bg, title_fg=text)
        message = self.state.transmission_pool[self.transmission_index]
        used = canvas.wrapped_text(x + 2, y + 2, width - 4, message, fg=text, bg=bg, max_lines=max(3, height - 6))
        canvas.text(x + 2, y + 2 + used + 1, f"theme vector  {self.state.theme_name}", fg=accent3, bg=bg, max_width=max(0, width - 4))
        canvas.text(
            x + 2,
            y + 2 + used + 2,
            f"appearance    {self.state.appearance_mode} / {self.state.appearance_preset}",
            fg=subtext,
            bg=bg,
            max_width=max(0, width - 4),
        )
        canvas.text(x + 2, y + height - 2, f"accent {self.state.accent_hex}", fg=accent2, bg=bg, max_width=max(0, width - 4))

    def draw_monitor_panel(self, canvas: Canvas, x: int, y: int, width: int, height: int, bg: RGB) -> None:
        border = self.palette_rgb("accent3", DEFAULT_PALETTE["accent3"])
        text = self.palette_rgb("text", DEFAULT_PALETTE["text"])
        subtext = self.palette_rgb("subtext1", DEFAULT_PALETTE["subtext1"])
        canvas.box(x, y, width, height, "MONITORS", border, bg, title_fg=text)
        for index, card in enumerate(self.state.monitors[: max(0, height - 2)]):
            row = y + 1 + (index * 3)
            if row + 2 >= y + height - 1:
                break
            canvas.text(x + 2, row, card.monitor, fg=border, bg=bg, max_width=max(0, width - 4))
            canvas.text(x + 2, row + 1, card.role, fg=text, bg=bg, max_width=max(0, width - 4))
            canvas.text(x + 2, row + 2, card.wallpaper, fg=subtext, bg=bg, max_width=max(0, width - 4))

    def draw_dashboard_bottom(self, canvas: Canvas, x: int, y: int, width: int, height: int, bg: RGB) -> None:
        border = self.palette_rgb("accent", DEFAULT_PALETTE["accent"])
        text = self.palette_rgb("text", DEFAULT_PALETTE["text"])
        subtext = self.palette_rgb("subtext1", DEFAULT_PALETTE["subtext1"])
        accent2 = self.palette_rgb("accent2", DEFAULT_PALETTE["accent2"])
        canvas.box(x, y, width, height, "TONIGHT", border, bg, title_fg=text)
        sequence_lines = [
            f"{index + 1}. {ritual.title}"
            for index, ritual in enumerate(self.state.sequence)
        ]
        for index, line in enumerate(sequence_lines):
            canvas.text(x + 2, y + 2 + index, line, fg=accent2 if index == 0 else text, bg=bg, max_width=max(0, width - 4))
        if self.state.sequence:
            detail = self.state.sequence[0].purpose
            canvas.wrapped_text(x + 2, y + 6, width - 4, detail, fg=subtext, bg=bg, max_lines=max(2, height - 8))
        canvas.text(x + 2, y + height - 3, "Enter launches a random neon car or motorcycle run. Rituals stay manual.", fg=accent2, bg=bg, max_width=max(0, width - 4))
        canvas.text(x + 2, y + height - 2, "Night Drive never executes commands from the ritual deck. It only arms the mood.", fg=subtext, bg=bg, max_width=max(0, width - 4))

    def draw_rituals_view(self, canvas: Canvas, x: int, y: int, width: int, height: int, bg: RGB) -> None:
        split = min(34, max(28, width // 3))
        list_bg = mix(bg, self.palette_rgb("accent2", DEFAULT_PALETTE["accent2"]), 0.04)
        detail_bg = mix(bg, self.palette_rgb("accent", DEFAULT_PALETTE["accent"]), 0.03)
        text = self.palette_rgb("text", DEFAULT_PALETTE["text"])
        subtext = self.palette_rgb("subtext1", DEFAULT_PALETTE["subtext1"])
        accent = self.palette_rgb("accent", DEFAULT_PALETTE["accent"])
        accent2 = self.palette_rgb("accent2", DEFAULT_PALETTE["accent2"])
        canvas.box(x, y, split, height, "RITUAL DECK", accent2, list_bg, title_fg=text)
        for index, ritual in enumerate(self.state.rituals[: max(0, height - 3)]):
            row = y + 1 + index
            marker = ">" if index == self.ritual_index else " "
            fg = accent2 if index == self.ritual_index else subtext
            canvas.text(x + 2, row, f"{marker} {ritual.title}", fg=fg, bg=list_bg, max_width=max(0, split - 4))

        detail_x = x + split + 2
        detail_width = width - split - 2
        canvas.box(detail_x, y, detail_width, height, "DETAIL", accent, detail_bg, title_fg=text)
        ritual = self.state.rituals[self.ritual_index]
        canvas.text(detail_x + 2, y + 2, ritual.title, fg=accent2, bg=detail_bg, max_width=max(0, detail_width - 4))
        canvas.text(detail_x + 2, y + 4, ritual.command, fg=accent, bg=detail_bg, max_width=max(0, detail_width - 4))
        canvas.wrapped_text(detail_x + 2, y + 7, detail_width - 4, ritual.purpose, fg=text, bg=detail_bg, max_lines=max(3, height - 13))
        canvas.text(detail_x + 2, y + height - 4, "sequence now", fg=accent2, bg=detail_bg, max_width=max(0, detail_width - 4))
        canvas.text(
            detail_x + 2,
            y + height - 3,
            "  ->  ".join(item.title for item in self.state.sequence),
            fg=subtext,
            bg=detail_bg,
            max_width=max(0, detail_width - 4),
        )
        canvas.text(detail_x + 2, y + height - 2, "Use j/k to rotate. Enter is for the animated run, not rituals.", fg=subtext, bg=detail_bg, max_width=max(0, detail_width - 4))

    def draw_signals_view(self, canvas: Canvas, x: int, y: int, width: int, height: int, bg: RGB) -> None:
        accent = self.palette_rgb("accent", DEFAULT_PALETTE["accent"])
        accent2 = self.palette_rgb("accent2", DEFAULT_PALETTE["accent2"])
        accent3 = self.palette_rgb("accent3", DEFAULT_PALETTE["accent3"])
        text = self.palette_rgb("text", DEFAULT_PALETTE["text"])
        subtext = self.palette_rgb("subtext1", DEFAULT_PALETTE["subtext1"])
        canvas.box(x, y, width, height, "SIGNALS", accent3, bg, title_fg=text)

        palette_rows = [
            ("accent", accent),
            ("pink rail", accent2),
            ("violet haze", accent3),
            ("text glow", self.palette_rgb("text", DEFAULT_PALETTE["text"])),
            ("warning", self.palette_rgb("warning", DEFAULT_PALETTE["warning"])),
            ("green", self.palette_rgb("green", DEFAULT_PALETTE["green"])),
        ]
        for index, (label, rgb) in enumerate(palette_rows):
            row = y + 2 + index
            if row >= y + height - 2:
                break
            canvas.text(x + 2, row, f"{label:<11}", fg=subtext, bg=bg, max_width=11)
            canvas.fill_rect(x + 15, row, min(10, max(1, width - 45)), 1, bg=rgb)
            canvas.text(x + 27, row, hex_value(rgb), fg=text, bg=bg, max_width=10)

        info_x = x + max(40, width // 2)
        info_width = width - (info_x - x) - 2
        for index, line in enumerate(ETHOS_LINES):
            row = y + 2 + index
            canvas.text(info_x, row, line, fg=accent2 if index == 0 else text, bg=bg, max_width=max(0, info_width))

        monitor_y = y + 8
        for index, card in enumerate(self.state.monitors):
            row = monitor_y + index * 2
            if row >= y + height - 3:
                break
            canvas.text(info_x, row, f"{card.monitor:<8} {card.role}", fg=accent, bg=bg, max_width=max(0, info_width))
            canvas.text(info_x, row + 1, card.wallpaper, fg=subtext, bg=bg, max_width=max(0, info_width))

        canvas.text(info_x, y + height - 2, self.state.transmission_pool[self.transmission_index], fg=text, bg=bg, max_width=max(0, info_width))

    def draw_help(self, canvas: Canvas) -> None:
        if not self.show_help:
            return
        width = min(70, canvas.width - 8)
        height = 11
        x = max(4, (canvas.width - width) // 2)
        y = max(4, (canvas.height - height) // 2)
        bg = mix(self.palette_rgb("mantle", DEFAULT_PALETTE["mantle"]), self.palette_rgb("accent3", DEFAULT_PALETTE["accent3"]), 0.08)
        border = self.palette_rgb("accent2", DEFAULT_PALETTE["accent2"])
        text = self.palette_rgb("text", DEFAULT_PALETTE["text"])
        subtext = self.palette_rgb("subtext1", DEFAULT_PALETTE["subtext1"])
        canvas.box(x, y, width, height, "HELP", border, bg, title_fg=text)
        lines = [
            "enter: launch a random midnight run with a seeded neon car or bike",
            "1/2/3 or tab: switch between dashboard, rituals, and signals",
            "j/k or arrows: move through the ritual deck",
            "left/right + up/down: steer, boost, and brake during the run",
            "r: reroll the transmission in the cockpit",
            "g: toggle the faint skyline grid",
            "esc: cancel the run and return to the cockpit",
            "q: leave Night Drive",
        ]
        for index, line in enumerate(lines):
            canvas.text(x + 2, y + 2 + index, line, fg=subtext if index else text, bg=bg, max_width=max(0, width - 4))

    def draw_small_mode(self, canvas: Canvas) -> None:
        bg = mix(self.palette_rgb("mantle", DEFAULT_PALETTE["mantle"]), self.palette_rgb("accent", DEFAULT_PALETTE["accent"]), 0.04)
        text = self.palette_rgb("text", DEFAULT_PALETTE["text"])
        accent = self.palette_rgb("accent2", DEFAULT_PALETTE["accent2"])
        canvas.box(2, 4, canvas.width - 4, canvas.height - 8, "COMPACT MODE", accent, bg, title_fg=text)
        message = self.state.transmission_pool[self.transmission_index]
        row = 6
        row += canvas.wrapped_text(4, row, canvas.width - 8, message, fg=text, bg=bg, max_lines=4)
        row += 2
        canvas.text(4, row, f"theme     {self.state.theme_name} / {self.state.appearance_mode}", fg=accent, bg=bg, max_width=max(0, canvas.width - 8))
        canvas.text(4, row + 1, f"wallpaper {self.state.wallpaper_signature}", fg=text, bg=bg, max_width=max(0, canvas.width - 8))
        canvas.text(4, row + 2, f"ritual    {self.state.rituals[self.ritual_index].command}", fg=text, bg=bg, max_width=max(0, canvas.width - 8))
        canvas.text(4, row + 4, "enter     midnight run", fg=accent, bg=bg, max_width=max(0, canvas.width - 8))
        canvas.text(4, canvas.height - 6, "Widen the terminal for the full skyline.", fg=accent, bg=bg, max_width=max(0, canvas.width - 8))

    def draw(self, width: int, height: int) -> str:
        self.refresh_state_if_needed()
        crust = self.palette_rgb("crust", DEFAULT_PALETTE["crust"])
        canvas = Canvas(width, height, bg=crust)
        drive_sequence = self.active_drive_sequence()
        if self.screensaver:
            if drive_sequence is None:
                self.start_drive_sequence()
                drive_sequence = self.active_drive_sequence()
            if drive_sequence is not None:
                elapsed = time.monotonic() - self.screensaver_started_at
                if elapsed >= 45.0:
                    self.screensaver_started_at = time.monotonic()
                    self.reroll()
                    self.start_drive_sequence()
                    drive_sequence = self.active_drive_sequence()
            if drive_sequence is not None:
                self.draw_screensaver_sequence(canvas, drive_sequence)
                self.frame += 1
                return canvas.render(color=True, home=True)
        if drive_sequence is not None:
            self.draw_drive_sequence(canvas, drive_sequence)
            self.draw_help(canvas)
            self.frame += 1
            return canvas.render(color=True, home=True)

        self.draw_background(canvas)
        self.draw_header(canvas)
        self.draw_footer(canvas)

        if width < 96 or height < 28:
            self.draw_small_mode(canvas)
            self.draw_help(canvas)
            self.frame += 1
            return canvas.render(color=True, home=True)

        panel_bg = mix(self.palette_rgb("mantle", DEFAULT_PALETTE["mantle"]), self.palette_rgb("crust", DEFAULT_PALETTE["crust"]), 0.16)
        top_y = 4
        top_h = 12
        left_w = 30
        right_w = 30
        center_x = 2 + left_w + 2
        center_w = width - left_w - right_w - 8
        right_x = width - right_w - 2
        bottom_y = top_y + top_h + 2
        bottom_h = height - bottom_y - 4

        self.draw_machine_panel(canvas, 2, top_y, left_w, top_h, panel_bg)
        self.draw_transmission_panel(canvas, center_x, top_y, center_w, top_h, mix(panel_bg, self.palette_rgb("accent", DEFAULT_PALETTE["accent"]), 0.03))
        self.draw_monitor_panel(canvas, right_x, top_y, right_w, top_h, panel_bg)

        bottom_bg = mix(self.palette_rgb("surface0", DEFAULT_PALETTE["surface0"]), self.palette_rgb("crust", DEFAULT_PALETTE["crust"]), 0.24)
        if self.view_index == 0:
            self.draw_dashboard_bottom(canvas, 2, bottom_y, width - 4, bottom_h, bottom_bg)
        elif self.view_index == 1:
            self.draw_rituals_view(canvas, 2, bottom_y, width - 4, bottom_h, bottom_bg)
        else:
            self.draw_signals_view(canvas, 2, bottom_y, width - 4, bottom_h, bottom_bg)

        self.draw_help(canvas)
        self.frame += 1
        return canvas.render(color=True, home=True)

    def snapshot(self, width: int, height: int, color: bool) -> str:
        self.refresh_state_if_needed(force=True)
        crust = self.palette_rgb("crust", DEFAULT_PALETTE["crust"])
        canvas = Canvas(width, height, bg=crust)
        self.draw_background(canvas)
        self.draw_header(canvas)
        self.draw_footer(canvas)
        if width < 96 or height < 28:
            self.draw_small_mode(canvas)
        else:
            panel_bg = mix(self.palette_rgb("mantle", DEFAULT_PALETTE["mantle"]), self.palette_rgb("crust", DEFAULT_PALETTE["crust"]), 0.16)
            top_y = 4
            top_h = 12
            left_w = 30
            right_w = 30
            center_x = 2 + left_w + 2
            center_w = width - left_w - right_w - 8
            right_x = width - right_w - 2
            bottom_y = top_y + top_h + 2
            bottom_h = height - bottom_y - 4
            self.draw_machine_panel(canvas, 2, top_y, left_w, top_h, panel_bg)
            self.draw_transmission_panel(canvas, center_x, top_y, center_w, top_h, mix(panel_bg, self.palette_rgb("accent", DEFAULT_PALETTE["accent"]), 0.03))
            self.draw_monitor_panel(canvas, right_x, top_y, right_w, top_h, panel_bg)
            self.draw_dashboard_bottom(canvas, 2, bottom_y, width - 4, bottom_h, mix(self.palette_rgb("surface0", DEFAULT_PALETTE["surface0"]), self.palette_rgb("crust", DEFAULT_PALETTE["crust"]), 0.24))
        return canvas.render(color=color, home=False)

    def run(self, fps: float) -> int:
        if not sys.stdin.isatty() or not sys.stdout.isatty():
            raise RuntimeError("Night Drive needs a TTY. Use --snapshot for non-interactive output.")
        frame_delay = 1.0 / max(2.0, fps)
        with TerminalController() as terminal:
            running = True
            while running:
                columns, lines = shutil.get_terminal_size((120, 36))
                sys.stdout.write(self.draw(columns, lines))
                sys.stdout.flush()
                for key in terminal.read_keys(frame_delay):
                    running = self.handle_key(key)
                    if not running:
                        break
        return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="ArchMerOS Night Drive terminal cockpit")
    parser.add_argument("--snapshot", action="store_true", help="Render one frame and print it")
    parser.add_argument("--plain", action="store_true", help="Disable ANSI colors in snapshot mode")
    parser.add_argument("--width", type=int, default=120, help="Snapshot width")
    parser.add_argument("--height", type=int, default=36, help="Snapshot height")
    parser.add_argument("--fps", type=float, default=12.0, help="Interactive frame rate")
    parser.add_argument("--screensaver", action="store_true", help="Exit on the first keypress for screensaver use")
    args = parser.parse_args()

    app = NightDriveApp(screensaver=args.screensaver)
    if args.snapshot:
        sys.stdout.write(app.snapshot(max(70, args.width), max(20, args.height), color=not args.plain))
        if not args.plain:
            sys.stdout.write("\x1b[0m")
        sys.stdout.write("\n")
        return 0
    return app.run(args.fps)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130)
