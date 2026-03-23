#!/usr/bin/env bash

set -euo pipefail

cmd="${1:-terminal}"
shift || true

launch_class="archmeros-wezterm-$RANDOM-$RANDOM"

if [[ "$cmd" == "terminal" ]]; then
  exec ~/.config/archmeros/scripts/archmeros-launch-detached.sh \
    /usr/bin/wezterm start --always-new-process --class "$launch_class" --cwd "$HOME"
fi

exec ~/.config/archmeros/scripts/archmeros-launch-detached.sh \
  /usr/bin/wezterm start --always-new-process --class "$launch_class" --cwd "$HOME" -- nvim "$@"
