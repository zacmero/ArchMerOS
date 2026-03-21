#!/usr/bin/env bash

set -euo pipefail

if ! command -v thunar >/dev/null 2>&1; then
  exec xdg-open "${1:-$HOME/Desktop}"
fi

thunar "$@" >/tmp/archmeros-thunar.log 2>&1 &

sleep 0.35

active="$(hyprctl activewindow -j 2>/dev/null || printf '{}')"
active_class="$(printf '%s' "$active" | jq -r '.class // empty' | tr '[:upper:]' '[:lower:]')"

if [[ "$active_class" != "thunar" ]]; then
  exit 0
fi

monitor_width="$(hyprctl -j monitors | jq -r '.[] | select(.focused == true) | .width' | head -n 1)"
monitor_height="$(hyprctl -j monitors | jq -r '.[] | select(.focused == true) | .height' | head -n 1)"

if [[ -n "${monitor_width:-}" && -n "${monitor_height:-}" ]]; then
  width="$(( monitor_width * 72 / 100 ))"
  height="$(( monitor_height * 76 / 100 ))"

  if [[ "$(printf '%s' "$active" | jq -r '.floating // false')" != "true" ]]; then
    hyprctl dispatch togglefloating >/dev/null 2>&1 || true
  fi

  hyprctl -q --batch \
    "dispatch resizeactive exact $width $height;" \
    "dispatch centerwindow 1;" \
    "dispatch alterzorder top;" >/dev/null 2>&1 || true
fi
