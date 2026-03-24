#!/usr/bin/env bash

set -euo pipefail

mode="none"
monitor_name=""
workspace_id=""
launch_id="archmeros-mpv-$RANDOM-$RANDOM"

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
      if (( width * 100 / monitor_width >= 85 || height * 100 / monitor_height >= 85 )); then
        mode="full"
      elif (( width * 100 / monitor_width >= 64 || height * 100 / monitor_height >= 64 )); then
        mode="medium"
      fi
    fi
    if [[ "$(printf '%s' "$active" | jq -r '.floating // false')" == "true" ]]; then
      hyprctl dispatch alterzorder bottom >/dev/null 2>&1 || true
    fi
  fi
fi

nohup mpv \
  --player-operation-mode=pseudo-gui \
  --title="$launch_id" \
  -- \
  "$@" >/tmp/archmeros-mpv.log 2>&1 &

nohup python3 "$HOME/.config/archmeros/scripts/archmeros-promote-window.py" \
  "^${launch_id}$" \
  "$mode" \
  "${monitor_name:-}" \
  "${workspace_id:-}" >/tmp/archmeros-promote-mpv.log 2>&1 &

disown || true
exit 0
