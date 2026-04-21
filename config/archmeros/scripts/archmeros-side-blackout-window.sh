#!/usr/bin/env bash

set -euo pipefail

exec kitty \
  --class archmeros-side-blackout \
  --title 'ArchMerOS Side Blackout' \
  --config NONE \
  --override background='#000000' \
  --override foreground='#000000' \
  --override cursor='#000000' \
  --override cursor_blink_interval=0 \
  --override background_opacity=1.0 \
  bash -lc 'printf "\033[?25l\033[2J\033[H"; exec sleep infinity'
