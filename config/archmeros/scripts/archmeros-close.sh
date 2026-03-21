#!/usr/bin/env bash

set -euo pipefail

active_class="$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // empty' | tr '[:upper:]' '[:lower:]')"

if [[ "$active_class" == "firefox" ]]; then
  exec hyprctl dispatch sendshortcut "CTRL,W,class:^(firefox)$"
fi

exec hyprctl dispatch killactive
