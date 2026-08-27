#!/usr/bin/env bash

set -euo pipefail

cycle_scope="${1:-recent}"
direction="${2:-next}"
lock_file="${XDG_RUNTIME_DIR:-/tmp}/archmeros-cycle-window.lock"
exec 9>"$lock_file"
flock 9

active="$(hyprctl activewindow -j 2>/dev/null || printf '{}')"
[[ "$active" != "{}" ]] || exit 0

active_address="$(printf '%s' "$active" | jq -r '.address // empty')"

dispatch_cmd="$HOME/.config/archmeros/scripts/archmeros-hyprctl-dispatch.sh"

target_address=""
case "$cycle_scope" in
  all)
    active_workspace="$(printf '%s' "$active" | jq -r '.workspace.id // empty')"

    target_address="$(
      hyprctl -j clients 2>/dev/null \
        | jq -r \
            --arg active "$active_address" \
            --argjson workspace "${active_workspace:-0}" \
            --arg direction "$direction" '
            [
              .[]
              | select(.mapped == true and .hidden == false)
              | select((.workspace.id // -1) == $workspace)
            ]
            | sort_by(.focusHistoryID // -1)
            | reverse
            | (map(.address) as $addresses
               | ($addresses | index($active)) as $idx
               | if ($idx == null) or ($addresses | length) <= 1 then
                   empty
                 else
                   if $direction == "prev" then
                     $addresses[($idx - 1 + ($addresses | length)) % ($addresses | length)]
                   else
                     $addresses[($idx + 1) % ($addresses | length)]
                   end
                 end)
          ' 2>/dev/null || true
    )"

    if [[ -n "${target_address:-}" ]]; then
      "$dispatch_cmd" focuswindow "address:${target_address}" >/dev/null 2>&1 || true
    fi
    ;;
  recent|*)
    "$dispatch_cmd" focuscurrentorlast >/dev/null 2>&1 || true
    target_address="$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty' 2>/dev/null || true)"
    ;;
esac

"$dispatch_cmd" bringactivetotop >/dev/null 2>&1 || true

cycled="$(hyprctl activewindow -j 2>/dev/null || printf '{}')"
if [[ "$(printf '%s' "$cycled" | jq -r '.floating // false')" == "true" ]]; then
  if [[ "$direction" == "prev" ]]; then
    offset=-36
  else
    offset=36
  fi
  "$dispatch_cmd" moveactive "$offset" 0 >/dev/null 2>&1 || true
  sleep 0.035
  "$dispatch_cmd" moveactive "$(( -offset ))" 0 >/dev/null 2>&1 || true
fi
