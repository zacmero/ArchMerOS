#!/usr/bin/env bash

set -euo pipefail

"$HOME/.config/archmeros/scripts/archmeros-scratchpad.sh" release >/dev/null || true

active="$(hyprctl activewindow -j 2>/dev/null || printf '{}')"
[[ "$active" != "{}" ]] || exit 0

dispatch_cmd="$HOME/.config/archmeros/scripts/archmeros-hyprctl-dispatch.sh"
if [[ "$(printf '%s' "$active" | jq -r '.floating // false')" == "true" ]]; then
  "$dispatch_cmd" settiled >/dev/null 2>&1
fi
