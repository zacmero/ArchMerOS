#!/usr/bin/env bash

set -euo pipefail

pkill -f 'kitty --class ArchMerOS-Screensaver|sysc-greet.*--test --theme archmeros --screensaver' >/dev/null 2>&1 || true
hyprctl dispatch dpms on >/dev/null 2>&1 || true
rm -f /tmp/archmeros-screensaver.pid
