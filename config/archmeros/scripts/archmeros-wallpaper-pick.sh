#!/usr/bin/env bash

set -euo pipefail

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
repo_root="$(cd "$(dirname "$script_path")/../../.." && pwd)"
wallpaper_dir="${repo_root}/config/wallpapers"
wallpaper_controller="${repo_root}/config/archmeros/scripts/archmeros-wallpaper.py"
rofi_theme="$HOME/.config/rofi/launchers/drun.rasi"
preview_log="/tmp/archmeros-wallpaper-preview.log"
preview_pid_file="/tmp/archmeros-wallpaper-preview.pid"

cleanup_preview() {
  if [[ -f "$preview_pid_file" ]]; then
    preview_pid="$(cat "$preview_pid_file" 2>/dev/null || true)"
    if [[ -n "${preview_pid:-}" ]]; then
      kill "$preview_pid" >/dev/null 2>&1 || true
    fi
    rm -f "$preview_pid_file"
  fi
}

show_preview() {
  local wallpaper_path="$1"
  cleanup_preview
  nohup imv "$wallpaper_path" >"$preview_log" 2>&1 &
  preview_pid=$!
  printf '%s\n' "$preview_pid" >"$preview_pid_file"
  disown "$preview_pid" || true
  sleep 0.2
}

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

while true; do
  selection="$(
    printf '%s\n' "${wallpapers[@]##*/}" \
      | rofi -dmenu -i -p "Wallpaper" -theme "$rofi_theme"
  )"

  if [[ -z "${selection:-}" ]]; then
    cleanup_preview
    exit 0
  fi

  preview_path="${wallpaper_dir}/${selection}"
  show_preview "$preview_path"

  decision="$(
    printf 'Apply\nPreview another\nCancel\n' \
      | rofi -dmenu -i -p "Wallpaper preview" -theme "$rofi_theme"
  )"

  case "${decision:-}" in
    Apply)
      cleanup_preview
      if [[ "$target" == "All monitors" ]]; then
        exec python3 "$wallpaper_controller" --all "$selection"
      fi
      exec python3 "$wallpaper_controller" --monitor "$target" "$selection"
      ;;
    "Preview another")
      continue
      ;;
    *)
      cleanup_preview
      exit 0
      ;;
  esac
done
