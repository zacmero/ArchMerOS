#!/usr/bin/env bash

set -euo pipefail

exec uwsm start -e -D Hyprland hyprland.desktop -- -- \
  -c "${HOME}/.config/hypr/hyprland.lua" \
  >/tmp/archmeros-hyprlua-session.log 2>&1
