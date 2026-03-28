#!/usr/bin/env bash
set -euo pipefail

export HOME=/var/lib/greeter
export USER=greeter
export LOGNAME=greeter
export XDG_CACHE_HOME=/var/cache/sysc-greet
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_STATE_HOME="${HOME}/.local/state"
export XDG_DATA_HOME="${HOME}/.local/share"

mkdir -p \
  "${XDG_CACHE_HOME}" \
  "${XDG_CONFIG_HOME}/dconf" \
  "${XDG_STATE_HOME}" \
  "${XDG_DATA_HOME}"

exec Hyprland -c /etc/greetd/hyprland-greeter-config.conf \
  >/var/cache/sysc-greet/greeter-hyprland.log 2>&1
