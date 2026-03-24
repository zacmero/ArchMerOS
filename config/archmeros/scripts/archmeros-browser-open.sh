#!/usr/bin/env bash

set -euo pipefail

browser=""
for candidate in chromium brave-browser google-chrome-stable google-chrome chrome; do
  if command -v "$candidate" >/dev/null 2>&1; then
    browser="$candidate"
    break
  fi
done

if [[ -z "$browser" ]]; then
  exec xdg-open "$@"
fi

mode="none"
monitor_name=""
workspace_id=""
full_threshold=85
medium_threshold=64

if command -v hyprctl >/dev/null 2>&1; then
  monitors_json="$(hyprctl -j monitors 2>/dev/null || printf '[]')"
  monitor_name="$(printf '%s' "$monitors_json" | jq -r '.[] | select(.focused == true) | .name' | head -n 1)"
  workspace_id="$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // empty' 2>/dev/null || true)"
  active="$(hyprctl activewindow -j 2>/dev/null || printf '{}')"

  if [[ "$active" != "{}" ]]; then
    width="$(printf '%s' "$active" | jq -r '.size[0] // 0')"
    height="$(printf '%s' "$active" | jq -r '.size[1] // 0')"
    monitor_size="$(printf '%s' "$monitors_json" | jq -r '.[] | select(.focused == true) | .width, .height' | paste -sd" " -)"
    monitor_width="$(printf '%s' "$monitor_size" | awk '{print $1}')"
    monitor_height="$(printf '%s' "$monitor_size" | awk '{print $2}')"
    if [[ -n "${monitor_width:-}" && -n "${monitor_height:-}" && "$monitor_width" != "0" && "$monitor_height" != "0" ]]; then
      if (( width * 100 / monitor_width >= full_threshold || height * 100 / monitor_height >= full_threshold )); then
        mode="full"
      elif (( width * 100 / monitor_width >= medium_threshold || height * 100 / monitor_height >= medium_threshold )); then
        mode="medium"
      fi
    fi
    if [[ "$(printf '%s' "$active" | jq -r '.floating // false')" == "true" ]]; then
      hyprctl dispatch alterzorder bottom >/dev/null 2>&1 || true
    fi
  fi
fi

nohup "$browser" --new-window "$@" >/tmp/archmeros-browser-open.log 2>&1 &
python3 "$HOME/.config/archmeros/scripts/archmeros-promote-window.py" \
  '^(chromium|Chromium|brave-browser|Brave-browser|BraveBrowser|google-chrome|Google-chrome|google-chrome-stable|Google-chrome-stable|chrome|Chrome)$' \
  "$mode" \
  "${monitor_name:-}" \
  "${workspace_id:-}" >/tmp/archmeros-promote-browser.log 2>&1 &
disown || true
