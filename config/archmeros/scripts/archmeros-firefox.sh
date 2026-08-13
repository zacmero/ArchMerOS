#!/usr/bin/env bash

set -euo pipefail

# Native Wayland popup resizing flickers with delayed extension menu items.
export MOZ_ENABLE_WAYLAND=0

if (( $# )); then
  exec /usr/bin/firefox "$@"
fi

/usr/bin/firefox &

# Firefox assigns the selector title after Hyprland evaluates static rules.
for _ in {1..150}; do
  selector="$(hyprctl clients -j | jq -r '.[] | select(.class == "firefox" and .title == "Firefox - Choose a profile") | "\(.address) \(.monitor)"' | head -n1)"
  if [[ -n "$selector" ]]; then
    read -r address monitor <<<"$selector"
    dimensions="$(hyprctl monitors -j | jq -r --argjson monitor "$monitor" '.[] | select(.id == $monitor) | "\(.width) \(.height)"')"
    read -r width height <<<"$dimensions"
    hyprctl dispatch resizewindowpixel exact "$((width * 84 / 100))" "$((height * 72 / 100)),address:$address" >/dev/null
    break
  fi
  sleep 0.1
done
