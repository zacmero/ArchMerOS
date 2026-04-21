#!/usr/bin/env bash

set -euo pipefail

mode="${1:-toggle}"
window_class="archmeros-side-blackout"
window_script="$HOME/.config/archmeros/scripts/archmeros-side-blackout-window.sh"

blackout_pids() {
  hyprctl clients -j 2>/dev/null \
    | jq -r --arg class "$window_class" '.[] | select(.class == $class) | .pid' 2>/dev/null \
    | awk 'NF'
}

blackout_running() {
  [[ -n "$(blackout_pids)" ]]
}

start_blackout() {
  blackout_running && return 0
  hyprctl dispatch exec "$window_script" >/dev/null 2>&1 || true
}

stop_blackout() {
  local pid
  while read -r pid; do
    [[ -n "$pid" ]] || continue
    kill "$pid" >/dev/null 2>&1 || true
  done < <(blackout_pids)
}

case "$mode" in
  start|on)
    start_blackout
    ;;
  stop|off)
    stop_blackout
    ;;
  toggle)
    if blackout_running; then
      stop_blackout
    else
      start_blackout
    fi
    ;;
  running)
    blackout_running
    ;;
  *)
    printf 'usage: %s [start|stop|toggle|running]\n' "$0" >&2
    exit 1
    ;;
esac
