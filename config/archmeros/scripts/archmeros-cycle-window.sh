#!/usr/bin/env bash

set -euo pipefail

cycle_scope="${1:-recent}"
direction="${2:-next}"

active="$(hyprctl activewindow -j 2>/dev/null || printf '{}')"
[[ "$active" != "{}" ]] || exit 0

monitor="$(hyprctl -j monitors | jq -r '.[] | select(.focused == true) | .name' | head -n 1)"
monitor_width="$(hyprctl -j monitors | jq -r '.[] | select(.focused == true) | .width' | head -n 1)"
monitor_height="$(hyprctl -j monitors | jq -r '.[] | select(.focused == true) | .height' | head -n 1)"

[[ -n "${monitor:-}" && -n "${monitor_width:-}" && -n "${monitor_height:-}" ]] || exit 1

floating="$(printf '%s' "$active" | jq -r '.floating // false')"
active_width="$(printf '%s' "$active" | jq -r '.size[0] // 0')"
active_height="$(printf '%s' "$active" | jq -r '.size[1] // 0')"
active_address="$(printf '%s' "$active" | jq -r '.address // empty')"

mode=""
if [[ "$floating" == "true" ]]; then
  if (( active_width >= monitor_width * 82 / 100 || active_height >= monitor_height * 82 / 100 )); then
    mode="full"
  elif (( active_width >= monitor_width * 64 / 100 || active_height >= monitor_height * 64 / 100 )); then
    mode="medium"
  fi
fi

if [[ -n "$mode" ]]; then
  hyprctl dispatch settiled >/dev/null 2>&1 || true
fi

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
      hyprctl dispatch focuswindow "address:${target_address}" >/dev/null 2>&1 || true
    fi
    ;;
  recent|*)
    hyprctl dispatch focuscurrentorlast >/dev/null 2>&1 || true
    target_address="$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty' 2>/dev/null || true)"
    ;;
esac

hyprctl dispatch bringactivetotop >/dev/null 2>&1 || true

if [[ -n "$mode" ]]; then
  ~/.config/archmeros/scripts/archmeros-window-pop.sh "$mode" >/dev/null 2>&1 || true
fi
