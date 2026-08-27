#!/usr/bin/env bash

set -euo pipefail

cmd="${1:-terminal}"
shift || true

launch_class="archmeros-wezterm-$RANDOM-$RANDOM"
export ARCHMEROS_NATIVE_SPAWN=1
export ARCHMEROS_SPAWN_CLASS="$launch_class"

if [[ "$cmd" == "terminal" ]]; then
  exec ~/.config/archmeros/scripts/archmeros-launch-detached.sh \
    /usr/bin/wezterm start --always-new-process --class "$launch_class" --cwd "$HOME"
fi

exec ~/.config/archmeros/scripts/archmeros-launch-detached.sh \
  /usr/bin/wezterm start --always-new-process --class "$launch_class" --cwd "$HOME" -- nvim "$@"
