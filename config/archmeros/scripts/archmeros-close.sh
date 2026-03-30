#!/usr/bin/env bash

set -euo pipefail

printf '%s close %s\n' "$(date +%s.%N)" "${1:-direct}" >> /tmp/archmeros-close.log 2>/dev/null || true

active_class="$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // empty' | tr '[:upper:]' '[:lower:]')"

python3 "$HOME/.config/archmeros/scripts/archmeros-reopen-history.py" record-close >/tmp/archmeros-reopen-record-close.log 2>&1 || true

if [[ "$active_class" == "firefox" ]]; then
  exec hyprctl dispatch sendshortcut "CTRL,W,class:^(firefox)$"
fi

exec hyprctl dispatch killactive
