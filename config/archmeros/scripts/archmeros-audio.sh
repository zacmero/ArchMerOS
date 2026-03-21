#!/usr/bin/env bash

set -euo pipefail

if command -v easyeffects >/dev/null 2>&1; then
  exec easyeffects
fi

if command -v qpwgraph >/dev/null 2>&1; then
  exec qpwgraph
fi

printf 'ArchMerOS audio tools are not installed yet.\n' >&2
exit 1
