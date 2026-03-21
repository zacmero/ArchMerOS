#!/usr/bin/env bash

set -euo pipefail

mode="${1:-medium}"

active="$(hyprctl activewindow -j)"
pinned="$(printf '%s' "$active" | jq -r '.pinned')"
floating="$(printf '%s' "$active" | jq -r '.floating')"

if [[ "$active" == "{}" ]]; then
  exit 0
fi

if [[ "$pinned" == "true" ]]; then
  hyprctl -q --batch \
    "dispatch pin;" \
    "dispatch settiled;"
  exit 0
fi

if [[ "$floating" == "true" ]]; then
  hyprctl -q --batch \
    "dispatch settiled;"
  exit 0
fi

monitor="$(hyprctl -j monitors | jq -r '.[] | select(.focused == true) | .name' | head -n 1)"
monitor_width="$(hyprctl -j monitors | jq -r '.[] | select(.focused == true) | .width' | head -n 1)"
monitor_height="$(hyprctl -j monitors | jq -r '.[] | select(.focused == true) | .height' | head -n 1)"

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
  *)
    printf 'ArchMerOS window pop: unknown mode %s\n' "$mode" >&2
    exit 1
    ;;
esac

hyprctl -q --batch \
  "dispatch togglefloating;" \
  "dispatch movewindow mon:${monitor};" \
  "dispatch resizeactive exact $width $height;" \
  "dispatch centerwindow 1;" \
  "dispatch alterzorder top;"
