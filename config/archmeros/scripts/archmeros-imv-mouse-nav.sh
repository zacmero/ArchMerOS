#!/usr/bin/env bash

set -euo pipefail

direction="${1:-}"
active="$(hyprctl activewindow -j 2>/dev/null || printf '{}')"
class="$(printf '%s' "$active" | jq -r '.class // .initialClass // empty')"

if [[ "$class" == "imv" ]]; then
  pid="$(printf '%s' "$active" | jq -r '.pid // empty')"
  if [[ "$pid" =~ ^[0-9]+$ ]]; then
    exec imv-msg "$pid" "$direction"
  fi
fi

case "$direction" in
  prev) exec wtype -M alt -k Left -m alt ;;
  next) exec wtype -M alt -k Right -m alt ;;
  *) exit 2 ;;
esac
