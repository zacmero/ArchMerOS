#!/usr/bin/env bash

set -euo pipefail

~/.config/archmeros/scripts/archmeros-desktop-sync.sh >/tmp/archmeros-desktop-sync.log 2>&1 || true

exec ~/.config/archmeros/scripts/archmeros-thunar.sh "$HOME/Desktop"
