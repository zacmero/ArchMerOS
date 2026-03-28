#!/usr/bin/env python3

from __future__ import annotations

import argparse
import colorsys
import json
import os
import re
import subprocess
import sys
from pathlib import Path

from PIL import Image


SCRIPT_PATH = Path(__file__).resolve()
REPO_ROOT = SCRIPT_PATH.parents[3]
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state")) / "archmeros"
APPEARANCE_STATE_FILE = STATE_DIR / "appearance.json"
WALLPAPER_STATE_FILE = STATE_DIR / "wallpapers.json"
DEFAULT_PRESET_FILE = REPO_ROOT / "themes" / "presets" / "default.json"
PRESET_DIR = REPO_ROOT / "themes" / "presets"
GENERATED_THEME_FILE = REPO_ROOT / "themes" / "generated" / "current.json"
HYPR_THEME_FILE = REPO_ROOT / "config" / "hypr" / "theme.conf"
WAYBAR_COLORS_FILE = REPO_ROOT / "config" / "waybar" / "colors.css"
ROFI_COLORS_FILE = REPO_ROOT / "config" / "rofi" / "colors.rasi"
WALKER_THEME_FILE = REPO_ROOT / "config" / "walker" / "themes" / "archmeros" / "style.css"
MAKO_CONFIG_FILE = REPO_ROOT / "config" / "mako" / "config"


def load_json(path: Path, fallback: dict | None = None) -> dict:
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    return fallback or {}


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[index:index + 2], 16) for index in (0, 2, 4))


def css_color_to_rgb(value: str) -> tuple[int, int, int]:
    if value.startswith("#"):
        return hex_to_rgb(value)
    match = re.fullmatch(r"rgba\((\d+), (\d+), (\d+), ([0-9.]+)\)", value)
    if match:
        red, green, blue, _alpha = match.groups()
        return (int(red), int(green), int(blue))
    raise ValueError(f"Unsupported color format: {value}")


def rgb_to_hex(rgb: tuple[int, int, int]) -> str:
    return "#{:02x}{:02x}{:02x}".format(*rgb)


def clamp(value: float, minimum: float = 0.0, maximum: float = 255.0) -> int:
    return int(max(minimum, min(maximum, round(value))))


def mix(rgb_a: tuple[int, int, int], rgb_b: tuple[int, int, int], amount: float) -> tuple[int, int, int]:
    return tuple(clamp(rgb_a[index] * (1 - amount) + rgb_b[index] * amount) for index in range(3))


def lighten(rgb: tuple[int, int, int], amount: float) -> tuple[int, int, int]:
    return mix(rgb, (255, 255, 255), amount)


def darken(rgb: tuple[int, int, int], amount: float) -> tuple[int, int, int]:
    return mix(rgb, (0, 0, 0), amount)


def rgba(rgb: tuple[int, int, int], alpha: float) -> str:
    return f"rgba({rgb[0]}, {rgb[1]}, {rgb[2]}, {alpha:.2f})"


def rgba_hex(rgb: tuple[int, int, int], alpha: float) -> str:
    return "rgba({:02x}{:02x}{:02x}{:02x})".format(rgb[0], rgb[1], rgb[2], clamp(alpha * 255))


def rgba_to_hex8(value: str) -> str:
    match = re.fullmatch(r"rgba\((\d+), (\d+), (\d+), ([0-9.]+)\)", value)
    if not match:
        return value
    red, green, blue, alpha = match.groups()
    return "#{:02x}{:02x}{:02x}{:02x}".format(int(red), int(green), int(blue), clamp(float(alpha) * 255))


def slugify(value: str) -> str:
    return re.sub(r"[^a-z0-9._-]+", "-", value.strip().lower()).strip("-") or "custom"


def boost_color(rgb: tuple[int, int, int], minimum_saturation: float, minimum_value: float) -> tuple[int, int, int]:
    hue, saturation, value = colorsys.rgb_to_hsv(*(channel / 255 for channel in rgb))
    saturation = max(saturation, minimum_saturation)
    value = max(value, minimum_value)
    boosted = colorsys.hsv_to_rgb(hue, saturation, value)
    return tuple(clamp(channel * 255) for channel in boosted)


def hue_distance(hue_a: float, hue_b: float) -> float:
    direct = abs(hue_a - hue_b)
    return min(direct, 1.0 - direct)


def available_wallpaper_paths() -> list[Path]:
    data = load_json(WALLPAPER_STATE_FILE, {"monitors": {}})
    return [Path(value) for value in data.get("monitors", {}).values() if Path(value).is_file()]


def wallpaper_monitor_map() -> dict[str, Path]:
    data = load_json(WALLPAPER_STATE_FILE, {"monitors": {}})
    result: dict[str, Path] = {}
    for monitor, value in data.get("monitors", {}).items():
        path = Path(value)
        if path.is_file():
            result[monitor] = path
    return result


def collect_colors(path: Path) -> list[dict]:
    image = Image.open(path).convert("RGB")
    image.thumbnail((240, 240))
    quantized = image.quantize(colors=10, method=Image.Quantize.MEDIANCUT)
    palette = quantized.getpalette()
    colors = quantized.getcolors() or []
    entries: list[dict] = []
    for count, index in colors:
        offset = index * 3
        rgb = tuple(palette[offset:offset + 3])
        hue, saturation, value = colorsys.rgb_to_hsv(*(channel / 255 for channel in rgb))
        entries.append(
            {
                "count": count,
                "rgb": rgb,
                "hue": hue,
                "saturation": saturation,
                "value": value,
            }
        )
    return entries


def choose_base(candidates: list[dict]) -> tuple[int, int, int]:
    dark = [entry for entry in candidates if entry["value"] <= 0.40]
    pool = dark or candidates
    total = max(sum(entry["count"] for entry in pool), 1)
    rgb = [0.0, 0.0, 0.0]
    for entry in pool:
        weight = entry["count"] / total
        for index in range(3):
            rgb[index] += entry["rgb"][index] * weight
    mixed = tuple(clamp(channel) for channel in rgb)
    return darken(mix(mixed, (8, 10, 18), 0.45), 0.25)


def choose_accent(candidates: list[dict], exclude_hues: list[float]) -> tuple[int, int, int]:
    filtered = [
        entry
        for entry in candidates
        if entry["saturation"] >= 0.22
        and entry["value"] >= 0.18
        and all(hue_distance(entry["hue"], hue) >= 0.09 for hue in exclude_hues)
    ]
    pool = filtered or candidates
    scored = sorted(
        pool,
        key=lambda entry: ((entry["saturation"] * 1.35) + (entry["value"] * 0.25)) * entry["count"],
        reverse=True,
    )
    return tuple(scored[0]["rgb"])


def choose_semantic(candidates: list[dict], hue_min: float, hue_max: float, fallback: tuple[int, int, int]) -> tuple[int, int, int]:
    hits = [
        entry
        for entry in candidates
        if hue_min <= entry["hue"] <= hue_max and entry["saturation"] >= 0.20 and entry["value"] >= 0.20
    ]
    if not hits:
        return fallback
    hits.sort(key=lambda entry: (entry["saturation"] + entry["value"]) * entry["count"], reverse=True)
    return tuple(hits[0]["rgb"])


def build_auto_palette() -> dict:
    defaults = load_json(DEFAULT_PRESET_FILE)["palette"]
    monitor_map = wallpaper_monitor_map()
    wallpaper_paths = list(monitor_map.values())
    if not wallpaper_paths:
        return defaults

    per_wallpaper: dict[str, list[dict]] = {}
    candidates: list[dict] = []
    for monitor, path in monitor_map.items():
        colors = collect_colors(path)
        per_wallpaper[monitor] = colors
        candidates.extend(colors)

    if not candidates:
        return defaults

    center_candidates = per_wallpaper.get("HDMI-A-4") or candidates
    left_candidates = per_wallpaper.get("DP-2") or candidates
    right_candidates = per_wallpaper.get("DP-3") or candidates

    accent_rgb = boost_color(choose_accent(center_candidates, []), 0.72, 0.88)
    accent_hue = colorsys.rgb_to_hsv(*(channel / 255 for channel in accent_rgb))[0]
    accent2_rgb = boost_color(choose_accent(left_candidates, [accent_hue]), 0.72, 0.90)
    accent2_hue = colorsys.rgb_to_hsv(*(channel / 255 for channel in accent2_rgb))[0]
    accent3_rgb = boost_color(choose_accent(right_candidates, [accent_hue, accent2_hue]), 0.66, 0.86)

    # Keep the ArchMerOS identity, but let auto mode visibly move with the wallpapers.
    accent_rgb = mix(accent_rgb, hex_to_rgb(defaults["accent"]), 0.18)
    accent2_rgb = mix(accent2_rgb, hex_to_rgb(defaults["accent2"]), 0.22)
    accent3_rgb = mix(accent3_rgb, hex_to_rgb(defaults["accent3"]), 0.20)

    base_rgb = choose_base(candidates)
    base_rgb = darken(mix(base_rgb, accent_rgb, 0.10), 0.08)

    text_rgb = lighten(mix(accent_rgb, (230, 235, 255), 0.75), 0.10)
    subtext1_rgb = mix(text_rgb, accent3_rgb, 0.22)
    subtext0_rgb = darken(subtext1_rgb, 0.14)
    overlay1_rgb = darken(mix(accent3_rgb, accent_rgb, 0.35), 0.18)
    overlay0_rgb = darken(overlay1_rgb, 0.16)
    surface1_rgb = lighten(mix(base_rgb, accent3_rgb, 0.10), 0.18)
    surface0_rgb = lighten(mix(base_rgb, accent_rgb, 0.08), 0.10)
    mantle_rgb = darken(base_rgb, 0.18)
    crust_rgb = darken(base_rgb, 0.30)

    green_rgb = choose_semantic(candidates, 0.22, 0.45, mix(hex_to_rgb(defaults["green"]), accent_rgb, 0.24))
    yellow_rgb = choose_semantic(candidates, 0.11, 0.18, mix(hex_to_rgb(defaults["yellow"]), accent2_rgb, 0.18))
    peach_rgb = choose_semantic(candidates, 0.05, 0.10, mix(hex_to_rgb(defaults["peach"]), accent2_rgb, 0.22))
    red_rgb = choose_semantic(candidates, 0.94, 1.0, mix(hex_to_rgb(defaults["red"]), accent2_rgb, 0.25))
    if red_rgb == peach_rgb:
        red_rgb = mix(hex_to_rgb(defaults["red"]), accent2_rgb, 0.25)
    rosewater_rgb = lighten(accent2_rgb, 0.42)
    teal_rgb = choose_semantic(candidates, 0.45, 0.58, mix(hex_to_rgb(defaults["teal"]), accent_rgb, 0.24))
    lavender_rgb = lighten(accent3_rgb, 0.28)

    return {
        "rosewater": rgb_to_hex(rosewater_rgb),
        "pink": rgb_to_hex(accent2_rgb),
        "mauve": rgb_to_hex(accent3_rgb),
        "red": rgb_to_hex(red_rgb),
        "peach": rgb_to_hex(peach_rgb),
        "yellow": rgb_to_hex(yellow_rgb),
        "green": rgb_to_hex(green_rgb),
        "teal": rgb_to_hex(teal_rgb),
        "blue": rgb_to_hex(accent_rgb),
        "lavender": rgb_to_hex(lavender_rgb),
        "text": rgb_to_hex(text_rgb),
        "subtext1": rgb_to_hex(subtext1_rgb),
        "subtext0": rgb_to_hex(subtext0_rgb),
        "overlay1": rgb_to_hex(overlay1_rgb),
        "overlay0": rgb_to_hex(overlay0_rgb),
        "surface1": rgba(surface1_rgb, 0.74),
        "surface0": rgba(surface0_rgb, 0.64),
        "base": rgba(base_rgb, 0.52),
        "mantle": rgba(mantle_rgb, 0.74),
        "crust": rgba(crust_rgb, 0.88),
        "accent": rgb_to_hex(accent_rgb),
        "accent2": rgb_to_hex(accent2_rgb),
        "accent3": rgb_to_hex(accent3_rgb),
        "warning": rgb_to_hex(yellow_rgb),
    }


def write_files(name: str, palette: dict) -> None:
    HYPR_THEME_FILE.write_text(
        "\n".join(
            [
                f"$archmeros_active_border = {rgba_hex(hex_to_rgb(palette['accent']), 1.0)} {rgba_hex(hex_to_rgb(palette['accent2']), 1.0)} 45deg",
                f"$archmeros_inactive_border = {rgba_hex(hex_to_rgb(palette['overlay0']), 0.68)}",
                f"$archmeros_shadow = {rgba_hex(css_color_to_rgb(palette['crust']), 0.62)}",
                "",
            ]
        ),
        encoding="utf-8",
    )

    WAYBAR_COLORS_FILE.write_text(
        "\n".join(
            [
                f"@define-color rosewater {palette['rosewater']};",
                f"@define-color pink {palette['pink']};",
                f"@define-color mauve {palette['mauve']};",
                f"@define-color red {palette['red']};",
                f"@define-color peach {palette['peach']};",
                f"@define-color yellow {palette['yellow']};",
                f"@define-color green {palette['green']};",
                f"@define-color teal {palette['teal']};",
                f"@define-color blue {palette['blue']};",
                f"@define-color lavender {palette['lavender']};",
                f"@define-color text {palette['text']};",
                f"@define-color subtext1 {palette['subtext1']};",
                f"@define-color subtext0 {palette['subtext0']};",
                f"@define-color overlay1 {palette['overlay1']};",
                f"@define-color overlay0 {palette['overlay0']};",
                f"@define-color surface1 {palette['surface1']};",
                f"@define-color surface0 {palette['surface0']};",
                f"@define-color base {palette['base']};",
                f"@define-color mantle {palette['mantle']};",
                f"@define-color crust {palette['crust']};",
                f"@define-color accent {palette['accent']};",
                f"@define-color accent2 {palette['accent2']};",
                f"@define-color accent3 {palette['accent3']};",
                f"@define-color warning {palette['warning']};",
                "",
            ]
        ),
        encoding="utf-8",
    )

    ROFI_COLORS_FILE.write_text(
        "\n".join(
            [
                "* {",
                f"  rosewater:      {palette['rosewater'].upper()}FF;",
                f"  pink:           {palette['pink'].upper()}FF;",
                f"  mauve:          {palette['mauve'].upper()}FF;",
                f"  red:            {palette['red'].upper()}FF;",
                f"  peach:          {palette['peach'].upper()}FF;",
                f"  yellow:         {palette['yellow'].upper()}FF;",
                f"  green:          {palette['green'].upper()}FF;",
                f"  teal:           {palette['teal'].upper()}FF;",
                f"  blue:           {palette['blue'].upper()}FF;",
                f"  lavender:       {palette['lavender'].upper()}FF;",
                f"  text:           {palette['text'].upper()}FF;",
                f"  subtext1:       {palette['subtext1'].upper()}FF;",
                f"  overlay0:       {palette['overlay0'].upper()}FF;",
                f"  surface0:       {palette['surface0']};",
                f"  surface1:       {palette['surface1']};",
                f"  base:           {palette['base']};",
                f"  mantle:         {palette['mantle']};",
                "",
                f"  accent:         {palette['accent']};",
                "",
                "  background:     @base;",
                "  background-alt: @mantle;",
                "  foreground:     @text;",
                "  alternate-normal-foreground: @subtext1;",
                "  border-color:   @accent;",
                "  selected:       @accent;",
                f"  active:         {palette['accent2']};",
                f"  urgent:         {palette['red']};",
                "}",
                "",
            ]
        ),
        encoding="utf-8",
    )

    WALKER_THEME_FILE.write_text(
        "\n".join(
            [
                "* {",
                '  font-family: "CaskaydiaCove Nerd Font", "CommitMono Nerd Font", monospace;',
                "  font-size: 15px;",
                "  letter-spacing: 0.08em;",
                "}",
                "",
                "window {",
                f"  background: {palette['mantle']};",
                f"  color: {palette['text']};",
                f"  border: 2px solid {palette['accent']};",
                "  box-shadow: none;",
                "}",
                "",
                "box#input,",
                "entry {",
                f"  background: {palette['surface0']};",
                f"  color: {palette['text']};",
                "  border: 0;",
                "}",
                "",
                "entry {",
                f"  border-bottom: 2px solid {palette['accent2']};",
                "  padding: 14px 16px;",
                f"  caret-color: {palette['accent']};",
                "}",
                "",
                "listview {",
                "  background: transparent;",
                "  padding: 10px 12px 12px;",
                "}",
                "",
                "listview row {",
                "  background: transparent;",
                f"  color: {palette['text']};",
                "  padding: 10px 12px;",
                f"  border-top: 1px solid {palette['overlay0']};",
                "}",
                "",
                "listview row:selected {",
                f"  background: linear-gradient(90deg, {palette['accent']}, {palette['accent2']});",
                f"  color: {palette['mantle']};",
                "}",
                "",
                "label#placeholder {",
                f"  color: {palette['subtext1']};",
                "}",
                "",
            ]
        ),
        encoding="utf-8",
    )

    MAKO_CONFIG_FILE.write_text(
        "\n".join(
            [
                "font=CaskaydiaCove Nerd Font 12",
                f"background-color={rgba_to_hex8(palette['mantle'])}",
                f"text-color={palette['text']}",
                f"border-color={palette['accent']}",
                f"progress-color=over {palette['accent3']}",
                "border-size=2",
                "border-radius=10",
                "padding=12",
                "default-timeout=5000",
                "ignore-timeout=0",
                "width=360",
                "height=140",
                "margin=12",
                "anchor=top-right",
                "icons=1",
                "max-visible=5",
                "",
            ]
        ),
        encoding="utf-8",
    )

    GENERATED_THEME_FILE.write_text(
        json.dumps({"name": name, "palette": palette}, indent=2) + "\n",
        encoding="utf-8",
    )


def refresh_shell() -> None:
    subprocess.run(["hyprctl", "reload"], check=False)
    subprocess.run(["pkill", "-x", "waybar"], check=False)
    subprocess.run(["pkill", "-x", "mako"], check=False)
    subprocess.Popen(
        [
            "waybar",
            "-c",
            str(Path.home() / ".config" / "waybar" / "config.jsonc"),
            "-s",
            str(Path.home() / ".config" / "waybar" / "style.css"),
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        stdin=subprocess.DEVNULL,
        start_new_session=True,
    )
    subprocess.Popen(
        ["mako", "-c", str(Path.home() / ".config" / "mako" / "config")],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        stdin=subprocess.DEVNULL,
        start_new_session=True,
    )


def write_state(mode: str, preset: str | None = None) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    payload = {"mode": mode}
    if preset:
        payload["preset"] = preset
    APPEARANCE_STATE_FILE.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def load_preset(name: str) -> dict:
    preset_path = PRESET_DIR / f"{name}.json"
    if not preset_path.exists():
        raise FileNotFoundError(f"Preset not found: {name}")
    return load_json(preset_path)


def save_preset(name: str, palette: dict) -> str:
    slug = slugify(name)
    preset_path = PRESET_DIR / f"{slug}.json"
    preset_path.write_text(json.dumps({"name": slug, "palette": palette}, indent=2) + "\n", encoding="utf-8")
    return slug


def current_state() -> dict:
    return load_json(APPEARANCE_STATE_FILE, {"mode": "default", "preset": "default"})


def apply_palette(name: str, mode: str, palette: dict, refresh: bool, preset_name: str | None = None) -> None:
    write_files(name, palette)
    write_state(mode, preset_name)
    if refresh:
        refresh_shell()


def main() -> int:
    parser = argparse.ArgumentParser(description="ArchMerOS appearance controller")
    parser.add_argument("--apply-default", action="store_true")
    parser.add_argument("--apply-auto", action="store_true")
    parser.add_argument("--apply-preset")
    parser.add_argument("--save-auto")
    parser.add_argument("--list-presets", action="store_true")
    parser.add_argument("--reapply-current", action="store_true")
    parser.add_argument("--show-state", action="store_true")
    parser.add_argument("--no-refresh", action="store_true")
    args = parser.parse_args()

    if args.list_presets:
        for path in sorted(PRESET_DIR.glob("*.json")):
            print(path.stem)
        return 0

    if args.show_state:
        print(json.dumps(current_state(), indent=2))
        return 0

    refresh = not args.no_refresh

    if args.apply_default:
        preset = load_preset("default")
        apply_palette("default", "default", preset["palette"], refresh, "default")
        return 0

    if args.apply_auto:
        palette = build_auto_palette()
        apply_palette("auto", "auto", palette, refresh)
        return 0

    if args.apply_preset:
        preset = load_preset(args.apply_preset)
        apply_palette(args.apply_preset, "preset", preset["palette"], refresh, args.apply_preset)
        return 0

    if args.save_auto:
        palette = build_auto_palette()
        preset_name = save_preset(args.save_auto, palette)
        apply_palette(preset_name, "preset", palette, refresh, preset_name)
        return 0

    if args.reapply_current:
        state = current_state()
        mode = state.get("mode", "default")
        preset_name = state.get("preset", "default")
        if mode == "auto":
            palette = build_auto_palette()
            apply_palette("auto", "auto", palette, refresh)
            return 0
        if mode == "preset":
            preset = load_preset(preset_name)
            apply_palette(preset_name, "preset", preset["palette"], refresh, preset_name)
            return 0
        preset = load_preset("default")
        apply_palette("default", "default", preset["palette"], refresh, "default")
        return 0

    parser.print_help()
    return 1


if __name__ == "__main__":
    sys.exit(main())
