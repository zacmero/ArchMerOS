#!/usr/bin/env bash

set -euo pipefail

if ~/.config/archmeros/scripts/archmeros-idle-media-active.sh; then
  exit 0
fi

exec "$HOME/.config/archmeros/scripts/archmeros-hyprctl-dispatch.sh" dpms off
