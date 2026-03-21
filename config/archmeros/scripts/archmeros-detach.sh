#!/usr/bin/env bash

set -euo pipefail

if [[ $# -eq 0 ]]; then
  printf 'Usage: %s <command> [args...]\n' "$0" >&2
  exit 1
fi

setsid "$@" >/tmp/archmeros-detach.log 2>&1 < /dev/null &
disown || true
