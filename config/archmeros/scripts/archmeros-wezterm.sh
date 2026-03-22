#!/usr/bin/env bash

set -euo pipefail

cmd="${1:-terminal}"
shift || true

mode="none"
if command -v hyprctl >/dev/null 2>&1; then
  active="$(hyprctl activewindow -j 2>/dev/null || printf '{}')"
  if [[ "$active" != "{}" ]] && [[ "$(printf '%s' "$active" | jq -r '.floating // false')" == "true" ]]; then
    width="$(printf '%s' "$active" | jq -r '.size[0] // 0')"
    height="$(printf '%s' "$active" | jq -r '.size[1] // 0')"
    monitor="$(hyprctl -j monitors 2>/dev/null | jq -r '.[] | select(.focused == true) | .width, .height' | paste -sd' ' -)"
    monitor_width="$(printf '%s' "$monitor" | awk '{print $1}')"
    monitor_height="$(printf '%s' "$monitor" | awk '{print $2}')"
    if [[ -n "${monitor_width:-}" && -n "${monitor_height:-}" && "$monitor_width" != "0" && "$monitor_height" != "0" ]]; then
      if (( width * 100 / monitor_width >= 85 || height * 100 / monitor_height >= 85 )); then
        mode="full"
      else
        mode="medium"
      fi
    fi
    hyprctl dispatch alterzorder bottom >/dev/null 2>&1 || true
  fi
fi

launch_class="archmeros-wezterm-$RANDOM-$RANDOM"

if [[ "$cmd" == "terminal" ]]; then
  nohup /usr/bin/wezterm start --always-new-process --class "$launch_class" --cwd "$HOME" >/tmp/archmeros-wezterm.log 2>&1 &
  nohup python3 "$HOME/.config/archmeros/scripts/archmeros-promote-window.py" "^${launch_class}$" "$mode" >/tmp/archmeros-promote-wezterm.log 2>&1 &
  disown || true
  exit 0
fi

nohup /usr/bin/wezterm start --always-new-process --class "$launch_class" --cwd "$HOME" -- nvim "$@" >/tmp/archmeros-wezterm.log 2>&1 &
nohup python3 "$HOME/.config/archmeros/scripts/archmeros-promote-window.py" "^${launch_class}$" "$mode" >/tmp/archmeros-promote-wezterm.log 2>&1 &
disown || true
