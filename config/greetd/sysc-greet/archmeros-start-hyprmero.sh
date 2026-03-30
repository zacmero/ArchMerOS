#!/usr/bin/env bash
set -euo pipefail

exec uwsm start -D Hyprland hyprland-uwsm.desktop \
  >/tmp/archmeros-hyprmero-session.log 2>&1
