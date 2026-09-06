#!/usr/bin/env bash

set -euo pipefail

python3 "$HOME/.config/archmeros/scripts/archmeros-reopen-history.py" \
  track-launch general bottles bottles "" -- \
  "$HOME/.config/archmeros/scripts/archmeros-bottles.sh" "$@" \
  >/tmp/archmeros-reopen-track-bottles.log 2>&1 || true

# Ensure Sentinel achievement companion service is active and prefixes synced
if [[ -x "$HOME/.config/archmeros/scripts/archmeros-bottles-debug.sh" ]]; then
  "$HOME/.config/archmeros/scripts/archmeros-bottles-debug.sh" sync-sentinel >/dev/null 2>&1 || true
elif command -v systemctl >/dev/null 2>&1; then
  systemctl --user start archmeros-sentinel.service >/dev/null 2>&1 || true
fi

if command -v flatpak >/dev/null 2>&1 && flatpak info com.usebottles.bottles >/dev/null 2>&1; then
  flatpak override --user --filesystem=xdg-download --filesystem=~/Games --filesystem=/mnt/windows-ssd --filesystem=/home/zacmero/mnt com.usebottles.bottles 2>/dev/null || true
  exec flatpak run \
    --branch=stable \
    --arch=x86_64 \
    --command=bottles \
    com.usebottles.bottles \
    "$@"
elif command -v bottles >/dev/null 2>&1; then
  exec bottles "$@"
else
  printf 'archmeros-bottles: Bottles is not installed (neither flatpak com.usebottles.bottles nor native bottles binary found)\n' >&2
  exit 1
fi
