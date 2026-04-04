#!/usr/bin/env bash

set -euo pipefail

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
repo_root="$(cd -- "$(dirname -- "$script_path")/../../.." && pwd)"
log_path="/tmp/archmeros-screensaver.log"
lock_path="/tmp/archmeros-screensaver.pid"
window_launcher="$HOME/.config/archmeros/scripts/archmeros-screensaver-window.sh"

config_path="${HOME}/.config/archmeros/screensaver/screensaver.conf"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$log_path"
}

log "invoke"

if ~/.config/archmeros/scripts/archmeros-idle-media-active.sh; then
  log "skip media-active"
  exit 0
fi

set_side_dpms() {
  "$HOME/.config/archmeros/scripts/archmeros-side-dpms.sh" "$1" >/dev/null 2>&1 || true
}

cleanup() {
  set_side_dpms on
  rm -f "$lock_path"
}

if [[ -f "$lock_path" ]]; then
  existing_pid="$(cat "$lock_path" 2>/dev/null || true)"
  if [[ "$existing_pid" == launching:* ]]; then
    launch_ts="${existing_pid#launching:}"
    now_ts="$(date +%s)"
    if [[ "$launch_ts" =~ ^[0-9]+$ ]] && (( now_ts - launch_ts < 15 )); then
      log "skip launching lock=$existing_pid"
      exit 0
    fi
    rm -f "$lock_path"
  elif [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
    log "skip locked pid=$existing_pid"
    exit 0
  else
    rm -f "$lock_path"
  fi
fi

printf 'launching:%s\n' "$(date +%s)" >"$lock_path"
trap cleanup EXIT

env_args=()
if [[ -f "$config_path" ]]; then
  enabled_value="$(sed -n 's/^enabled=//p' "$config_path" | head -n 1 | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  if [[ "$enabled_value" == "false" ]]; then
    log "skip disabled"
    exit 0
  fi
  env_args+=("ARCHMEROS_SCREENSAVER_CONFIG=$config_path")
fi

set_side_dpms off

if [[ ! -x "$window_launcher" ]]; then
  log "skip missing-window-launcher"
  exit 1
fi

log "launch hyprland-window"
launch_cmd="ARCHMEROS_SCREENSAVER_LOCK=$lock_path"
launch_cmd+=" ${window_launcher@Q}"

if hyprctl dispatch exec "$launch_cmd" >/dev/null 2>&1; then
  trap - EXIT
  exit 0
fi

log "launch failed"
exit 1
