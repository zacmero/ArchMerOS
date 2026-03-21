#!/usr/bin/env bash

set -euo pipefail

theme_script="$HOME/.config/archmeros/scripts/archmeros-theme.py"
wallpaper_script="$HOME/.config/archmeros/scripts/archmeros-wallpaper-pick.sh"
rofi_theme="$HOME/.config/rofi/launchers/drun.rasi"

selection="$(
  printf '%s\n' \
    "Default colors" \
    "Auto colors from current wallpapers" \
    "Apply saved preset" \
    "Save current auto colors as preset" \
    "Pick wallpapers per monitor" \
    "Reapply current appearance" \
    | rofi -dmenu -i -p "Appearance" -theme "$rofi_theme"
)"

if [[ -z "${selection:-}" ]]; then
  exit 0
fi

case "$selection" in
  "Default colors")
    exec "$theme_script" --apply-default
    ;;
  "Auto colors from current wallpapers")
    exec "$theme_script" --apply-auto
    ;;
  "Apply saved preset")
    mapfile -t presets < <("$theme_script" --list-presets | sort)
    preset="$(
      printf '%s\n' "${presets[@]}" \
        | rofi -dmenu -i -p "Preset" -theme "$rofi_theme"
    )"
    if [[ -n "${preset:-}" ]]; then
      exec "$theme_script" --apply-preset "$preset"
    fi
    ;;
  "Save current auto colors as preset")
    preset_name="$(
      printf '' \
        | rofi -dmenu -i -p "Preset name" -theme "$rofi_theme"
    )"
    if [[ -n "${preset_name:-}" ]]; then
      exec "$theme_script" --save-auto "$preset_name"
    fi
    ;;
  "Pick wallpapers per monitor")
    exec "$wallpaper_script"
    ;;
  "Reapply current appearance")
    exec "$theme_script" --reapply-current
    ;;
esac
