#!/usr/bin/env bash

set -euo pipefail

browser=""
for candidate in chromium brave-browser google-chrome-stable google-chrome chrome; do
  if command -v "$candidate" >/dev/null 2>&1; then
    browser="$candidate"
    break
  fi
done

if [[ -z "$browser" ]]; then
  exec xdg-open "$@"
fi

if [[ "${ARCHMEROS_SKIP_HISTORY:-0}" != "1" ]]; then
  python3 "$HOME/.config/archmeros/scripts/archmeros-reopen-history.py" \
    track-launch general "" "" "$browser" -- \
    "$HOME/.config/archmeros/scripts/archmeros-browser-open.sh" "$@" \
    >/tmp/archmeros-reopen-track-browser.log 2>&1 || true
fi

launch_class="archmeros-browser-$RANDOM-$RANDOM"

ARCHMEROS_SKIP_HISTORY=1 exec "$HOME/.config/archmeros/scripts/archmeros-launch-detached.sh" \
  --native-spawn "$launch_class" \
  "$browser" --class="$launch_class" --new-window "$@"
