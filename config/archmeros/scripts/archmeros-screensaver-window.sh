#!/usr/bin/env bash

set -euo pipefail

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
repo_root="$(cd -- "$(dirname -- "$script_path")/../../.." && pwd)"
log_path="/tmp/archmeros-screensaver.log"
lock_path="${ARCHMEROS_SCREENSAVER_LOCK:-/tmp/archmeros-screensaver.pid}"

repo_binary="${repo_root}/.build/sysc-greet/archmeros-sysc-greet"
system_binary="/usr/local/bin/sysc-greet"
system_kitty_conf="/etc/greetd/kitty-greeter.conf"
repo_kitty_conf="${repo_root}/config/greetd/sysc-greet/kitty-greeter.conf"
theme_name="archmeros"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$log_path"
}

cleanup() {
  hyprctl dispatch dpms on >/dev/null 2>&1 || true
  "$HOME/.config/archmeros/scripts/archmeros-side-dpms.sh" on >/dev/null 2>&1 || true
  rm -f "$lock_path"
}

printf '%s\n' "$$" >"$lock_path"
trap cleanup EXIT

binary_path="$repo_binary"
if [[ ! -x "$binary_path" ]]; then
  binary_path="$system_binary"
fi

if [[ ! -x "$binary_path" ]]; then
  log "window-launcher missing-binary"
  exit 1
fi

kitty_conf="$system_kitty_conf"
if [[ ! -f "$kitty_conf" ]]; then
  kitty_conf="$repo_kitty_conf"
fi

cmd=("$binary_path" "--test" "--theme" "$theme_name" "--screensaver")

if command -v kitty >/dev/null 2>&1; then
  log "window-launcher kitty"
  exec kitty \
    --class ArchMerOS-Screensaver \
    --start-as=fullscreen \
    --config "$kitty_conf" \
    /bin/bash \
    -lc \
    'exec "$@" 2>>"$0"' \
    "$log_path" \
    "${cmd[@]}"
fi

if command -v wezterm >/dev/null 2>&1; then
  log "window-launcher wezterm"
  exec wezterm \
    --config 'enable_tab_bar=false' \
    --config 'use_fancy_tab_bar=false' \
    --config 'window_decorations="NONE"' \
    start \
    --always-new-process \
    --class ArchMerOS-Screensaver \
    --cwd "$HOME" \
    /bin/bash \
    -lc \
    'exec "$@" 2>>"$0"' \
    "$log_path" \
    "${cmd[@]}"
fi

log "window-launcher direct"
exec "${cmd[@]}"
