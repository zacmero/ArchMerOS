#!/usr/bin/env bash

set -euo pipefail

hyprctl dispatch workspace 5 >/dev/null 2>&1 || true

~/.config/archmeros/scripts/archmeros-webapp.sh todoist >/tmp/archmeros-todoist.log 2>&1 &
~/.config/archmeros/scripts/archmeros-obsidian.sh >/tmp/archmeros-obsidian.log 2>&1 &

disown || true
