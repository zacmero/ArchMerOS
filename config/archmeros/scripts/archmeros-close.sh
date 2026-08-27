#!/usr/bin/env bash

set -euo pipefail

printf '%s close %s\n' "$(date +%s.%N)" "${1:-direct}" >> /tmp/archmeros-close.log 2>/dev/null || true

active_window="$(hyprctl activewindow -j 2>/dev/null)"
active_class="$(jq -r '.class // empty' <<<"$active_window" | tr '[:upper:]' '[:lower:]')"
active_floating="$(jq -r '.floating // false' <<<"$active_window")"

python3 "$HOME/.config/archmeros/scripts/archmeros-reopen-history.py" record-close >/tmp/archmeros-reopen-record-close.log 2>&1 || true

dispatch_cmd="$HOME/.config/archmeros/scripts/archmeros-hyprctl-dispatch.sh"

if [[ "$active_class" == "firefox" && "$active_floating" != "true" ]]; then
  exec "$dispatch_cmd" sendshortcut "CTRL,W,class:^(firefox)$"
fi

exec "$dispatch_cmd" killactive
