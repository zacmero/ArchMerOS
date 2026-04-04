#!/usr/bin/env bash

set -euo pipefail

lock_path="/tmp/archmeros-screensaver.pid"

if [[ -f "$lock_path" ]]; then
  lock_value="$(cat "$lock_path" 2>/dev/null || true)"
  if [[ "$lock_value" == launching:* ]]; then
    launch_ts="${lock_value#launching:}"
    now_ts="$(date +%s)"
    if [[ "$launch_ts" =~ ^[0-9]+$ ]] && (( now_ts - launch_ts < 3 )); then
      exit 0
    fi
  elif [[ "$lock_value" =~ ^[0-9]+$ ]]; then
    kill "$lock_value" >/dev/null 2>&1 || true
  fi
fi

pkill -f 'mpv.*ArchMerOS-Screensaver|ArchMerOS Screensaver' >/dev/null 2>&1 || true
hyprctl dispatch dpms on >/dev/null 2>&1 || true
"$HOME/.config/archmeros/scripts/archmeros-side-dpms.sh" on >/dev/null 2>&1 || true
rm -f "$lock_path"
