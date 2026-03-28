#!/usr/bin/env bash

set -euo pipefail

if command -v playerctl >/dev/null 2>&1; then
  if playerctl --all-players status 2>/dev/null | grep -qx 'Playing'; then
    exit 0
  fi
fi

exit 1
