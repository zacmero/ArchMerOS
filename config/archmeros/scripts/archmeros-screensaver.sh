#!/usr/bin/env bash

set -euo pipefail

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
repo_root="$(cd -- "$(dirname -- "$script_path")/../../.." && pwd)"

config_path="${HOME}/.config/archmeros/screensaver/screensaver.conf"
repo_binary="${repo_root}/.build/sysc-greet/archmeros-sysc-greet"
system_binary="/usr/local/bin/sysc-greet"
system_kitty_conf="/etc/greetd/kitty-greeter.conf"
repo_kitty_conf="${repo_root}/config/greetd/sysc-greet/kitty-greeter.conf"
theme_name="archmeros"

if pgrep -af 'sysc-greet.*--screensaver' >/dev/null 2>&1; then
  exit 0
fi

binary_path="$repo_binary"
if [[ ! -x "$binary_path" ]]; then
  binary_path="$system_binary"
fi

if [[ ! -x "$binary_path" ]]; then
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
    exit 0
  fi
  env_args+=("ARCHMEROS_SCREENSAVER_CONFIG=$config_path")
fi

if command -v kitty >/dev/null 2>&1; then
  exec env "${env_args[@]}" \
    kitty \
      --class ArchMerOS-Screensaver \
      --start-as=fullscreen \
      --config "$kitty_conf" \
      "$binary_path" \
      --theme "$theme_name" \
      --screensaver
fi

exec env "${env_args[@]}" "$binary_path" --theme "$theme_name" --screensaver
