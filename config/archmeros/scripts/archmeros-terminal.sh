#!/usr/bin/env bash

set -euo pipefail

launch() {
  nohup "$@" >/tmp/archmeros-terminal.log 2>&1 &
  disown || true
  exit 0
}

if command -v xfce4-terminal >/dev/null 2>&1; then
  launch xfce4-terminal --disable-server
fi

if command -v wezterm >/dev/null 2>&1; then
  launch wezterm start --always-new-process
fi

if command -v xterm >/dev/null 2>&1; then
  launch xterm
fi

printf 'No terminal binary could be launched.\n' >&2
exit 1
