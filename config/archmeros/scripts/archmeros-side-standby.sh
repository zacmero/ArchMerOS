#!/usr/bin/env bash

set -euo pipefail

side_monitors=(DP-3 DP-2)
monitors_json="$(hyprctl monitors -j 2>/dev/null || printf '[]')"
target_state="off"

for monitor in "${side_monitors[@]}"; do
  if printf '%s\n' "$monitors_json" | jq -e --arg name "$monitor" '.[] | select(.name == $name and .dpmsStatus == false)' >/dev/null 2>&1; then
    target_state="on"
    break
  fi
done

for monitor in "${side_monitors[@]}"; do
  hyprctl dispatch dpms "$target_state" "$monitor" >/dev/null 2>&1 || true
done
