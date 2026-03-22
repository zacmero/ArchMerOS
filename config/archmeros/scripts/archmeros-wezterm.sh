#!/usr/bin/env bash

set -euo pipefail

cmd="${1:-terminal}"
shift || true

if [[ "$cmd" == "terminal" ]]; then
  nohup /usr/bin/wezterm start --always-new-process --cwd "$HOME" >/tmp/archmeros-wezterm.log 2>&1 &
  disown || true
  exit 0
fi

nohup /usr/bin/wezterm start --always-new-process --cwd "$HOME" -- nvim "$@" >/tmp/archmeros-wezterm.log 2>&1 &
disown || true
