#!/usr/bin/env bash

set -euo pipefail

script="${HOME}/.config/archmeros/scripts/archmeros-night-drive.py"

for arg in "$@"; do
  case "$arg" in
    --snapshot|--help|-h)
      exec python3 "$script" "$@"
      ;;
  esac
done

if [[ -t 0 && -t 1 ]]; then
  exec python3 "$script" "$@"
fi

launch_class="archmeros-night-drive-$RANDOM-$RANDOM"

exec "${HOME}/.config/archmeros/scripts/archmeros-launch-detached.sh" \
  /usr/bin/wezterm start --always-new-process --class "$launch_class" --cwd "$HOME" -- \
  python3 "$script" "$@"
