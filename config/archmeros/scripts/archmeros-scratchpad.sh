#!/usr/bin/env bash
set -euo pipefail

case "${1:-toggle}" in
  toggle)
    hyprctl eval 'archmeros_scratchpad.toggle()'
    ;;
  release)
    # Exit 1 means the normal card/tile command should proceed unchanged.
    hyprctl activewindow -j | jq -e '.workspace.name == "special:archmeros-scratchpad"' >/dev/null || exit 1
    hyprctl eval 'archmeros_scratchpad.release()'
    ;;
  *)
    printf 'Usage: %s [toggle|release]\n' "$0" >&2
    exit 2
    ;;
esac
