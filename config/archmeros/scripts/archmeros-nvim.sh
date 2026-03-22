#!/usr/bin/env bash

set -euo pipefail

launch() {
  nohup "$@" >/tmp/archmeros-nvim.log 2>&1 &
  disown || true
  exit 0
}

if command -v xfce4-terminal >/dev/null 2>&1; then
  launch xfce4-terminal --disable-server -x nvim "$@"
fi

if command -v wezterm >/dev/null 2>&1; then
  launch wezterm start --always-new-process -- nvim "$@"
fi

printf 'No terminal binary could be launched for Neovim.\n' >&2
exit 1
