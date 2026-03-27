#!/usr/bin/env bash
set -euo pipefail

exec uwsm start -D Hyprland hyprland.desktop \
  >/tmp/archmeros-hyprmero-session.log 2>&1
