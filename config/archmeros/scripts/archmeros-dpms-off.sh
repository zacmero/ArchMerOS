#!/usr/bin/env bash

set -euo pipefail

if ~/.config/archmeros/scripts/archmeros-idle-media-active.sh; then
  exit 0
fi

hyprctl dispatch dpms off
