#!/usr/bin/env bash

set -euo pipefail

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
repo_root="$(cd -- "$(dirname -- "$script_path")/../../.." && pwd)"
log_path="/tmp/archmeros-screensaver.log"
lock_path="/tmp/archmeros-screensaver.pid"
stamp_path="/tmp/archmeros-screensaver.started"
launch_script_path="/tmp/archmeros-screensaver-launch.sh"
window_launcher="$HOME/.config/archmeros/scripts/archmeros-screensaver-window.sh"

config_path="${HOME}/.config/archmeros/screensaver/screensaver.conf"
default_config_path="${repo_root}/config/greetd/sysc-greet/share/ascii_configs/screensaver.conf"

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

read_setting() {
  local source_path="$1"
  local key="$2"
  local default_value="${2:-}"
  default_value="${3:-}"
  if [[ -f "$source_path" ]]; then
    local value
    value="$(sed -n "s/^${key}=//p" "$source_path" | head -n 1 | tr -d '\r')"
    if [[ -n "$value" ]]; then
      printf '%s\n' "$value"
      return 0
    fi
  fi
  printf '%s\n' "$default_value"
}

cleanup() {
  set_side_dpms on
  rm -f "$lock_path" "$stamp_path" "$launch_script_path"
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
effective_config_path="$default_config_path"
if [[ -f "$config_path" ]]; then
  effective_config_path="$config_path"
fi

enabled_value="$(read_setting "$effective_config_path" enabled true | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
if [[ "$enabled_value" == "false" ]]; then
  log "skip disabled"
  exit 0
fi

mode_value="$(read_setting "$effective_config_path" mode nightdrive)"
speed_value="$(read_setting "$effective_config_path" animation_speed 2)"
env_args+=("ARCHMEROS_SCREENSAVER_CONFIG=$effective_config_path")
env_args+=("ARCHMEROS_SCREENSAVER_MODE=$mode_value")
env_args+=("ARCHMEROS_SCREENSAVER_SPEED=$speed_value")

set_side_dpms off

if [[ ! -x "$window_launcher" ]]; then
  log "skip missing-window-launcher"
  exit 1
fi

log "launch hyprland-window"
log "launch mode=$mode_value speed=$speed_value config=$effective_config_path"
cat >"$launch_script_path" <<EOF
#!/usr/bin/env bash
export ARCHMEROS_SCREENSAVER_LOCK=$(printf '%q' "$lock_path")
export ARCHMEROS_SCREENSAVER_CONFIG=$(printf '%q' "$effective_config_path")
export ARCHMEROS_SCREENSAVER_MODE=$(printf '%q' "$mode_value")
export ARCHMEROS_SCREENSAVER_SPEED=$(printf '%q' "$speed_value")
exec $(printf '%q' "$window_launcher")
EOF
chmod +x "$launch_script_path"

if hyprctl dispatch exec "$launch_script_path" >/dev/null 2>&1; then
  trap - EXIT
  exit 0
fi

log "launch failed"
exit 1
