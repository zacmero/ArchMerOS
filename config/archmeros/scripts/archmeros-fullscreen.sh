#!/usr/bin/env bash

set -euo pipefail

active="$(hyprctl activewindow -j 2>/dev/null || printf '{}')"
active_class="$(printf '%s' "$active" | jq -r '(.class // .initialClass // "") | ascii_downcase')"

case "$active_class" in
  firefox|chromium|google-chrome|google-chrome-stable|brave-browser|archmeros-*)
    exec hyprctl dispatch fullscreenstate 2 0
    ;;
  *)
    exec hyprctl dispatch fullscreen 0
    ;;
esac
