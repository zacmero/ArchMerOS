#!/usr/bin/env bash

set -euo pipefail

if ! command -v obsidian >/dev/null 2>&1; then
  printf 'archmeros-obsidian: obsidian is not installed\n' >&2
  exit 1
fi

python3 "$HOME/.config/archmeros/scripts/archmeros-reopen-history.py" \
  track-launch general obsidian obsidian obsidian -- \
  "$HOME/.config/archmeros/scripts/archmeros-obsidian.sh" "$@" \
  >/tmp/archmeros-reopen-track-obsidian.log 2>&1 || true

exec obsidian "$@"
