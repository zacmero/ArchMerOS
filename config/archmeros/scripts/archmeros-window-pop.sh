#!/usr/bin/env bash

set -euo pipefail

requested_mode="${1:-medium}"
mode="$requested_mode"

active="$(hyprctl activewindow -j)"
pinned="$(printf '%s' "$active" | jq -r '.pinned')"
floating="$(printf '%s' "$active" | jq -r '.floating')"

if [[ "$active" == "{}" ]]; then
  exit 0
fi

monitor_json="$(hyprctl -j monitors | jq -c '.[] | select(.focused == true)' | head -n 1)"
monitor="$(printf '%s' "$monitor_json" | jq -r '.name // empty')"
monitor_width="$(printf '%s' "$monitor_json" | jq -r '.width // 0')"
monitor_height="$(printf '%s' "$monitor_json" | jq -r '.height // 0')"
reserved_left="$(printf '%s' "$monitor_json" | jq -r '.reserved[0] // 0')"
reserved_top="$(printf '%s' "$monitor_json" | jq -r '.reserved[1] // 0')"
reserved_right="$(printf '%s' "$monitor_json" | jq -r '.reserved[2] // 0')"
reserved_bottom="$(printf '%s' "$monitor_json" | jq -r '.reserved[3] // 0')"
gaps_css="$(hyprctl getoption general:gaps_out -j 2>/dev/null | jq -r '.css // "10 10 10 10"')"
read -r gap_top gap_right gap_bottom gap_left <<< "$gaps_css"
border_size="$(hyprctl getoption general:border_size -j 2>/dev/null | jq -r '.int // 2')"
usable_width="$(( monitor_width - reserved_left - reserved_right ))"
usable_height="$(( monitor_height - reserved_top - reserved_bottom ))"
max_width="$(( usable_width - gap_left - gap_right - border_size * 2 ))"
max_height="$(( usable_height - gap_top - gap_bottom - border_size * 2 ))"
active_width="$(printf '%s' "$active" | jq -r '.size[0] // 0')"
active_height="$(printf '%s' "$active" | jq -r '.size[1] // 0')"
current_mode="none"

if (( usable_width > 0 && usable_height > 0 )); then
  if (( active_width >= max_width - 6 && active_height >= max_height - 6 )); then
    current_mode="max"
  elif (( active_width * 100 >= usable_width * 85 && active_height * 100 >= usable_height * 85 )); then
    current_mode="full"
  elif (( active_width * 100 >= usable_width * 64 && active_height * 100 >= usable_height * 64 )); then
    current_mode="medium"
  elif [[ "$floating" == "true" ]]; then
    current_mode="small"
  fi
fi

dispatch_cmd="$HOME/.config/archmeros/scripts/archmeros-hyprctl-dispatch.sh"

if [[ "$pinned" == "true" ]]; then
  "$dispatch_cmd" pin >/dev/null 2>&1 || true
  "$dispatch_cmd" settiled >/dev/null 2>&1 || true
  exit 0
fi

case "$requested_mode" in
  shrink)
    case "$current_mode" in
      max) mode="full" ;;
      full) mode="medium" ;;
      *) mode="small" ;;
    esac
    ;;
  full)
    case "$current_mode" in
      max) mode="max" ;;
      full) mode="max" ;;
      medium) mode="full" ;;
      *) mode="medium" ;;
    esac
    ;;
esac

if [[ "$floating" == "true" && "$current_mode" == "$mode" ]]; then
  exit 0
fi

if [[ -z "${monitor:-}" || -z "${monitor_width:-}" || -z "${monitor_height:-}" ]]; then
  exit 1
fi

case "$mode" in
  max)
    width="$max_width"
    height="$max_height"
    ;;
  full)
    width="$(( monitor_width * 96 / 100 ))"
    height="$(( monitor_height * 92 / 100 ))"
    ;;
  medium)
    width="$(( monitor_width * 72 / 100 ))"
    height="$(( monitor_height * 76 / 100 ))"
    ;;
  small)
    width="$(( monitor_width * 42 / 100 ))"
    height="$(( monitor_height * 52 / 100 ))"
    ;;
  *)
    printf 'ArchMerOS window pop: unknown mode %s\n' "$mode" >&2
    exit 1
    ;;
esac

dispatch_cmd="$HOME/.config/archmeros/scripts/archmeros-hyprctl-dispatch.sh"

if [[ "$floating" != "true" ]]; then
  "$dispatch_cmd" togglefloating >/dev/null 2>&1 || true
fi

"$dispatch_cmd" movewindow "mon:${monitor}" >/dev/null 2>&1 || true
"$dispatch_cmd" resizeactive exact "$width" "$height" >/dev/null 2>&1 || true
"$dispatch_cmd" centerwindow 1 >/dev/null 2>&1 || true
