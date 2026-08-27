#!/usr/bin/env bash

set -euo pipefail

"$HOME/.config/archmeros/scripts/archmeros-hyprctl-dispatch.sh" workspace 5 >/dev/null 2>&1 || true

~/.config/archmeros/scripts/archmeros-todoist.sh >/tmp/archmeros-todoist.log 2>&1 &
~/.config/archmeros/scripts/archmeros-obsidian.sh >/tmp/archmeros-obsidian.log 2>&1 &

disown || true
