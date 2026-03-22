#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageOps


SCRIPT_PATH = Path(__file__).resolve()
REPO_ROOT = SCRIPT_PATH.parents[3]
WALLPAPER_DIR = REPO_ROOT / "config" / "wallpapers"
GENERATED_DIR = WALLPAPER_DIR / "generated"


def run(command: list[str]) -> str:
    return subprocess.check_output(command, text=True)


def active_monitors() -> dict[str, tuple[int, int]]:
    try:
        data = json.loads(run(["hyprctl", "-j", "monitors"]))
    except Exception:
        data = []

    monitors: dict[str, tuple[int, int]] = {}
    for monitor in data:
        name = monitor.get("name")
        width = int(monitor.get("width", 0) or 0)
        height = int(monitor.get("height", 0) or 0)
        if name and width > 0 and height > 0:
            monitors[name] = (width, height)
    return monitors


def sanitize(value: str) -> str:
    return re.sub(r"[^a-zA-Z0-9._-]+", "-", value).strip("-") or "wallpaper"


def resolve_source(value: str) -> Path:
    candidate = Path(value).expanduser()
    if candidate.is_file():
        return candidate.resolve()

    repo_candidate = WALLPAPER_DIR / value
    if repo_candidate.is_file():
        return repo_candidate.resolve()

    raise FileNotFoundError(value)


def crop_for_monitor(source: Path, monitor: str, size: tuple[int, int]) -> Path:
    GENERATED_DIR.mkdir(parents=True, exist_ok=True)

    width, height = size
    stem = sanitize(source.stem)
    monitor_name = sanitize(monitor)
    output = GENERATED_DIR / f"{monitor_name}--{stem}-{width}x{height}.png"

    with Image.open(source) as image:
        prepared = ImageOps.fit(
            image.convert("RGBA"),
            (width, height),
            method=Image.Resampling.LANCZOS,
            centering=(0.5, 0.5),
        )
        prepared.save(output, format="PNG")

    return output


def main() -> int:
    parser = argparse.ArgumentParser(description="Crop wallpapers to monitor aspect ratios for ArchMerOS")
    parser.add_argument("source", help="Wallpaper file path or name")
    parser.add_argument("--monitor", help="Single monitor name")
    parser.add_argument("--all", action="store_true", help="Crop for all active monitors")
    args = parser.parse_args()

    source = resolve_source(args.source)
    monitors = active_monitors()
    if not monitors:
        return 1

    if args.all:
        payload = {
            monitor: str(crop_for_monitor(source, monitor, size))
            for monitor, size in monitors.items()
        }
        print(json.dumps(payload))
        return 0

    if args.monitor:
        if args.monitor not in monitors:
            return 1
        print(str(crop_for_monitor(source, args.monitor, monitors[args.monitor])))
        return 0

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
