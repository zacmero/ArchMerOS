#!/usr/bin/env bash

set -euo pipefail

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
repo_root="$(cd -- "$(dirname -- "$script_path")/../../.." && pwd)"
log_path="/tmp/archmeros-screensaver.log"
lock_path="/tmp/archmeros-screensaver.pid"

config_path="${HOME}/.config/archmeros/screensaver/screensaver.conf"
repo_binary="${repo_root}/.build/sysc-greet/archmeros-sysc-greet"
system_binary="/usr/local/bin/sysc-greet"
system_kitty_conf="/etc/greetd/kitty-greeter.conf"
repo_kitty_conf="${repo_root}/config/greetd/sysc-greet/kitty-greeter.conf"
theme_name="archmeros"
side_monitors=(DP-2 DP-3)

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$log_path"
}

log "invoke"

if ~/.config/archmeros/scripts/archmeros-idle-media-active.sh; then
  log "skip media-active"
  exit 0
fi

set_side_dpms() {
  local state="$1"
  local monitor
  for monitor in "${side_monitors[@]}"; do
    hyprctl dispatch dpms "$state" "$monitor" >/dev/null 2>&1 || true
  done
}

cleanup() {
  set_side_dpms on
  if [[ -f "$lock_path" ]] && [[ "$(cat "$lock_path" 2>/dev/null)" == "$$" ]]; then
    rm -f "$lock_path"
  fi
}

if [[ -f "$lock_path" ]]; then
  existing_pid="$(cat "$lock_path" 2>/dev/null || true)"
  if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
    log "skip locked pid=$existing_pid"
    exit 0
  fi
fi

printf '%s\n' "$$" >"$lock_path"
trap cleanup EXIT

binary_path="$repo_binary"
if [[ ! -x "$binary_path" ]]; then
  binary_path="$system_binary"
fi

if [[ ! -x "$binary_path" ]]; then
  log "skip missing-binary"
  exit 1
fi

kitty_conf="$system_kitty_conf"
if [[ ! -f "$kitty_conf" ]]; then
  kitty_conf="$repo_kitty_conf"
fi

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

if command -v kitty >/dev/null 2>&1; then
  log "launch kitty"
  cmd=("$binary_path" "--test" "--theme" "$theme_name" "--screensaver")
  env "${env_args[@]}" \
    kitty \
      --class ArchMerOS-Screensaver \
      --start-as=fullscreen \
      --config "$kitty_conf" \
      /bin/bash \
      -lc \
      'exec "$@" 2>>"$0"' \
      "$log_path" \
      "${cmd[@]}"
  exit $?
fi

log "launch binary"
env "${env_args[@]}" "$binary_path" --test --theme "$theme_name" --screensaver
