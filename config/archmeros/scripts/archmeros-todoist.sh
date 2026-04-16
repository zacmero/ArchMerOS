#!/usr/bin/env bash

set -euo pipefail

python3 "$HOME/.config/archmeros/scripts/archmeros-reopen-history.py" \
  track-launch general "com.todoist.Todoist" "com.todoist" "" -- \
  "$HOME/.config/archmeros/scripts/archmeros-todoist.sh" "$@" \
  >/tmp/archmeros-reopen-track-todoist.log 2>&1 || true

if flatpak info com.todoist.Todoist >/dev/null 2>&1; then
  exec flatpak run com.todoist.Todoist "$@"
fi

exec "$HOME/.config/archmeros/scripts/archmeros-webapp.sh" todoist "$@"
