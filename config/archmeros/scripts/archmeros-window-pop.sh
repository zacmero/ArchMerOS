#!/usr/bin/env bash

set -euo pipefail

requested_mode="${1:-medium}"
mode="$requested_mode"

active="$(hyprctl activewindow -j)"
pinned="$(printf '%s' "$active" | jq -r '.pinned')"
floating="$(printf '%s' "$active" | jq -r '.floating')"

if [[ "$active" == "{}" ]]; then
  exit 0
fi

monitor="$(hyprctl -j monitors | jq -r '.[] | select(.focused == true) | .name' | head -n 1)"
monitor_width="$(hyprctl -j monitors | jq -r '.[] | select(.focused == true) | .width' | head -n 1)"
monitor_height="$(hyprctl -j monitors | jq -r '.[] | select(.focused == true) | .height' | head -n 1)"
active_width="$(printf '%s' "$active" | jq -r '.size[0] // 0')"
active_height="$(printf '%s' "$active" | jq -r '.size[1] // 0')"
current_mode="none"

if [[ -n "${monitor_width:-}" && -n "${monitor_height:-}" && "${monitor_width:-0}" != "0" && "${monitor_height:-0}" != "0" ]]; then
  if (( active_width * 100 / monitor_width >= 85 || active_height * 100 / monitor_height >= 85 )); then
    current_mode="full"
  elif (( active_width * 100 / monitor_width >= 64 || active_height * 100 / monitor_height >= 64 )); then
    current_mode="medium"
  fi
fi

if [[ "$pinned" == "true" ]]; then
  hyprctl -q --batch \
    "dispatch pin;" \
    "dispatch settiled;"
  exit 0
fi

if [[ "$requested_mode" == "shrink" ]]; then
  if [[ "$current_mode" == "full" ]]; then
    mode="medium"
  else
    mode="small"
  fi
elif [[ "$requested_mode" == "full" && "$current_mode" == "none" ]]; then
  mode="medium"
fi

if [[ "$requested_mode" != "shrink" && "$floating" == "true" && "$current_mode" == "$mode" ]]; then
  hyprctl -q --batch \
    "dispatch settiled;"
  exit 0
fi

if [[ -z "${monitor:-}" || -z "${monitor_width:-}" || -z "${monitor_height:-}" ]]; then
  exit 1
fi

case "$mode" in
  full)
    width="$(( monitor_width * 96 / 100 ))"
    height="$(( monitor_height * 92 / 100 ))"
    ;;
  medium)
    width="$(( monitor_width * 72 / 100 ))"
    height="$(( monitor_height * 76 / 100 ))"
    ;;
  small)
    width="$(( monitor_width * 42 / 100 ))"
    height="$(( monitor_height * 52 / 100 ))"
    ;;
  *)
    printf 'ArchMerOS window pop: unknown mode %s\n' "$mode" >&2
    exit 1
    ;;
esac

if [[ "$floating" != "true" ]]; then
  hyprctl dispatch togglefloating >/dev/null 2>&1 || true
fi

hyprctl -q --batch \
  "dispatch movewindow mon:${monitor};" \
  "dispatch resizeactive exact $width $height;" \
  "dispatch centerwindow 1;"
