#!/usr/bin/env bash

set -euo pipefail

dispatch_cmd="$HOME/.config/archmeros/scripts/archmeros-hyprctl-dispatch.sh"

previous_window_address="$(
  hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty' 2>/dev/null || true
)"
previous_workspace="$(
  hyprctl activewindow -j 2>/dev/null | jq -r '.workspace.id // empty' 2>/dev/null || true
)"

selected_emoji="$(
  rofimoji \
    --selector rofi \
    --selector-args "-theme ~/.config/rofi/launchers/emoji.rasi" \
    --clipboarder wl-copy \
    --typer wtype \
    --prompt "Emoji" \
    --hidden-descriptions \
    --use-icons \
    --action print
)"

[[ -z "${selected_emoji}" ]] && exit 0

printf '%s' "$selected_emoji" | wl-copy

if [[ -n "$previous_workspace" && "$previous_workspace" != "null" ]]; then
  "$dispatch_cmd" workspace "$previous_workspace" >/dev/null 2>&1 || true
fi

if [[ -n "$previous_window_address" && "$previous_window_address" != "null" ]]; then
  "$dispatch_cmd" focuswindow "address:${previous_window_address}" >/dev/null 2>&1 || true
fi

sleep 0.18
wtype "$selected_emoji"

exit 0
