#!/usr/bin/env bash

set -euo pipefail

active="$(hyprctl activewindow -j 2>/dev/null || printf '{}')"
active_class="$(printf '%s' "$active" | jq -r '(.class // .initialClass // "") | ascii_downcase')"

dispatch_cmd="$HOME/.config/archmeros/scripts/archmeros-hyprctl-dispatch.sh"

case "$active_class" in
  firefox|chromium|google-chrome|google-chrome-stable|brave-browser|archmeros-*)
    exec "$dispatch_cmd" fullscreenstate 2 0
    ;;
  *)
    exec "$dispatch_cmd" fullscreen 0
    ;;
esac
