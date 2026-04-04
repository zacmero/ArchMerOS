#!/usr/bin/env bash

set -euo pipefail

lock_path="/tmp/archmeros-screensaver.pid"
stamp_path="/tmp/archmeros-screensaver.started"
log_path="/tmp/archmeros-screensaver.log"
minimum_runtime_seconds=5

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$log_path"
}

log "stop-invoke"

if [[ -f "$stamp_path" ]]; then
  started_at="$(cat "$stamp_path" 2>/dev/null || true)"
  now_ts="$(date +%s)"
  if [[ "$started_at" =~ ^[0-9]+$ ]] && (( now_ts - started_at < minimum_runtime_seconds )); then
    log "stop-skip early-resume started_at=$started_at"
    exit 0
  fi
fi

if [[ -f "$lock_path" ]]; then
  lock_value="$(cat "$lock_path" 2>/dev/null || true)"
  if [[ "$lock_value" == launching:* ]]; then
    launch_ts="${lock_value#launching:}"
    now_ts="$(date +%s)"
    if [[ "$launch_ts" =~ ^[0-9]+$ ]] && (( now_ts - launch_ts < 3 )); then
      log "stop-skip launching lock=$lock_value"
      exit 0
    fi
  elif [[ "$lock_value" =~ ^[0-9]+$ ]]; then
    log "stop-kill pid=$lock_value"
    kill "$lock_value" >/dev/null 2>&1 || true
  fi
fi

log "stop-pkill"
pkill -f 'mpv.*ArchMerOS-Screensaver|ArchMerOS Screensaver|wezterm.*ArchMerOS-Screensaver.*archmeros-night-drive.py|python3 .*archmeros-night-drive.py --fps' >/dev/null 2>&1 || true
hyprctl dispatch dpms on >/dev/null 2>&1 || true
"$HOME/.config/archmeros/scripts/archmeros-side-dpms.sh" on >/dev/null 2>&1 || true
rm -f "$lock_path"
log "stop-done"
