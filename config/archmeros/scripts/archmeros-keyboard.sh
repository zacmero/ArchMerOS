#!/usr/bin/env bash

set -euo pipefail

action="${1:-status}"

case "$action" in
  toggle)
    exec hyprctl switchxkblayout current next
    ;;
esac

active_keymap="$(
  hyprctl -j devices \
    | jq -r '
        (.keyboards[] | select(.main == true) | .active_keymap),
        (.keyboards[] | select(.name == "at-translated-set-2-keyboard") | .active_keymap),
        (.keyboards[] | .active_keymap)
      ' \
    | sed -n '1p'
)"

if [[ -z "${active_keymap:-}" || "$active_keymap" == "null" ]]; then
  active_keymap="Unknown"
fi

short_label="$active_keymap"
case "$active_keymap" in
  "English (US)")
    short_label="US"
    ;;
  "Portuguese (Brazil)")
    short_label="BR"
    ;;
esac

printf '{"text":"⌨ %s","tooltip":"%s\\nClick to toggle keyboard layout"}\n' "$short_label" "$active_keymap"
