#!/usr/bin/env bash

set -euo pipefail

workspace="${1:-}"
if [[ ! "$workspace" =~ ^[1-9][0-9]*$ ]]; then
  printf 'Usage: %s <workspace-number>\n' "$0" >&2
  exit 2
fi

active="$(hyprctl activewindow -j 2>/dev/null || printf '{}')"
address="$(printf '%s' "$active" | jq -r '.address // empty')"
[[ -n "$address" ]] || exit 0

dispatch_cmd="$HOME/.config/archmeros/scripts/archmeros-hyprctl-dispatch.sh"

"$dispatch_cmd" movetoworkspace "$workspace,address:${address}" >/dev/null 2>&1 || exit 1

while IFS= read -r client_address; do
  [[ -n "$client_address" ]] || continue
  "$dispatch_cmd" settiled "address:${client_address}" >/dev/null 2>&1 || true
done < <(
  hyprctl clients -j 2>/dev/null \
    | jq -r --argjson workspace "$workspace" '.[] | select(.mapped == true and .hidden == false and .floating == true) | select((.workspace.id // -1) == $workspace) | .address'
)

"$dispatch_cmd" focuswindow "address:${address}" >/dev/null 2>&1 || true
"$dispatch_cmd" bringactivetotop >/dev/null 2>&1 || true
