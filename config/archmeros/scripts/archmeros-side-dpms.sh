#!/usr/bin/env bash

set -euo pipefail

side_monitors=(DP-3 DP-2)
mode="${1:-toggle}"

monitors_json="$(hyprctl monitors -j 2>/dev/null || printf '[]')"

case "$mode" in
  toggle)
    target_state="off"
    for monitor in "${side_monitors[@]}"; do
      if printf '%s\n' "$monitors_json" | jq -e --arg name "$monitor" '.[] | select(.name == $name and .dpmsStatus == false)' >/dev/null 2>&1; then
        target_state="on"
        break
      fi
    done
    ;;
  on|off)
    target_state="$mode"
    ;;
  *)
    printf 'usage: %s [toggle|on|off]\n' "$0" >&2
    exit 1
    ;;
esac

for monitor in "${side_monitors[@]}"; do
  hyprctl dispatch dpms "$target_state" "$monitor" >/dev/null 2>&1 || true
done
