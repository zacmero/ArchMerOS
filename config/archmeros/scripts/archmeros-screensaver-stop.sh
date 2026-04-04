#!/usr/bin/env bash

set -euo pipefail

pkill -f 'wezterm start --always-new-process --class ArchMerOS-Screensaver|kitty --class ArchMerOS-Screensaver|sysc-greet.*--test --theme archmeros --screensaver' >/dev/null 2>&1 || true
hyprctl dispatch dpms on >/dev/null 2>&1 || true
"$HOME/.config/archmeros/scripts/archmeros-side-dpms.sh" on >/dev/null 2>&1 || true
rm -f /tmp/archmeros-screensaver.pid
