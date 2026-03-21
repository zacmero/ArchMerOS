#!/usr/bin/env bash

set -euo pipefail

hyprctl dispatch workspace 4 >/dev/null 2>&1 || true

~/.config/archmeros/scripts/archmeros-webapp.sh todoist >/tmp/archmeros-todoist.log 2>&1 &
~/.config/archmeros/scripts/archmeros-webapp.sh evernote >/tmp/archmeros-evernote.log 2>&1 &

disown || true
