#!/usr/bin/env bash

set -euo pipefail

if ! command -v flatpak >/dev/null 2>&1; then
  printf 'archmeros-termius: flatpak is not installed\n' >&2
  exit 1
fi

scale="${ARCHMEROS_TERMIUS_SCALE:-1.25}"
window_size="${ARCHMEROS_TERMIUS_WINDOW_SIZE:-1440,900}"

python3 "$HOME/.config/archmeros/scripts/archmeros-reopen-history.py" \
  track-launch general termius termius "" -- \
  "$HOME/.config/archmeros/scripts/archmeros-termius.sh" "$@" \
  >/tmp/archmeros-reopen-track-termius.log 2>&1 || true

exec flatpak run \
  --branch=stable \
  --arch=x86_64 \
  --command=termius \
  com.termius.Termius \
  --high-dpi-support=1 \
  --force-device-scale-factor="${scale}" \
  --window-size="${window_size}" \
  "$@"
