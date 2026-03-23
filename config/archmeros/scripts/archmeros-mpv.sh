#!/usr/bin/env bash

set -euo pipefail

exec ~/.config/archmeros/scripts/archmeros-launch-detached.sh \
  mpv \
  --player-operation-mode=pseudo-gui \
  -- \
  "$@"
