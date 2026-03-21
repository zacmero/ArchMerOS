#!/usr/bin/env bash

set -euo pipefail

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
repo_root="$(cd "$(dirname "$script_path")/../../.." && pwd)"
wallpaper_dir="${repo_root}/config/wallpapers"
wallpaper_controller="${repo_root}/config/archmeros/scripts/archmeros-wallpaper.py"
rofi_theme="$HOME/.config/rofi/launchers/drun.rasi"

if [[ ! -d "$wallpaper_dir" ]]; then
  printf 'ArchMerOS wallpaper picker: missing wallpaper dir %s\n' "$wallpaper_dir" >&2
  exit 1
fi

mapfile -t wallpapers < <(
  find "$wallpaper_dir" -maxdepth 1 -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
    | sort
)

if [[ ${#wallpapers[@]} -eq 0 ]]; then
  printf 'ArchMerOS wallpaper picker: no wallpapers found.\n' >&2
  exit 1
fi

mapfile -t monitors < <(python3 "$wallpaper_controller" --list-monitors)

target="$(
  {
    printf 'All monitors\n'
    printf '%s\n' "${monitors[@]}"
  } | rofi -dmenu -i -p "Wallpaper target" -theme "$rofi_theme"
)"

if [[ -z "${target:-}" ]]; then
  exit 0
fi

selection="$(
  printf '%s\n' "${wallpapers[@]##*/}" \
    | rofi -dmenu -i -p "Wallpaper" -theme "$rofi_theme"
)"

if [[ -z "${selection:-}" ]]; then
  exit 0
fi

if [[ "$target" == "All monitors" ]]; then
  exec python3 "$wallpaper_controller" --all "$selection"
fi

exec python3 "$wallpaper_controller" --monitor "$target" "$selection"
