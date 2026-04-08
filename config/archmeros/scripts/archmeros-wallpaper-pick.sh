#!/usr/bin/env bash

set -euo pipefail

printf '%s launch wallpaper picker\n' "$(date '+%Y-%m-%d %H:%M:%S')" >>/tmp/archmeros-wallpaper-picker.log
exec python3 "$HOME/.config/archmeros/scripts/archmeros-wallpaper-browser.py"
