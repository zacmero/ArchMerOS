#!/usr/bin/env bash

set -euo pipefail

direction="${1:-}"
case "$direction" in
  l|r|u|d) ;;
  *) exit 1 ;;
esac

active="$(hyprctl activewindow -j 2>/dev/null || printf '{}')"
[[ "$active" != "{}" ]] || exit 0

dispatch_cmd="$HOME/.config/archmeros/scripts/archmeros-hyprctl-dispatch.sh"
if [[ "$(printf '%s' "$active" | jq -r '.floating // false')" == "true" ]]; then
  "$dispatch_cmd" settiled >/dev/null 2>&1
fi

"$dispatch_cmd" swapwindow "$direction" >/dev/null 2>&1 || true
