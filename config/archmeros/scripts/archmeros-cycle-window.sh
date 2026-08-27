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
active_floating="$(printf '%s' "$active" | jq -r '.floating // false')"
active_width="$(printf '%s' "$active" | jq -r '.size[0] // 0')"
active_height="$(printf '%s' "$active" | jq -r '.size[1] // 0')"

dispatch_cmd="$HOME/.config/archmeros/scripts/archmeros-hyprctl-dispatch.sh"

target_address=""
case "$cycle_scope" in
  all)
    active_workspace="$(printf '%s' "$active" | jq -r '.workspace.id // empty')"
    clients_json="$(hyprctl -j clients 2>/dev/null || printf '[]')"
    state_file="${XDG_RUNTIME_DIR:-/tmp}/archmeros-card-sizes-${active_workspace:-0}.json"
    workspace_addresses="$(printf '%s' "$clients_json" | jq -c --argjson workspace "${active_workspace:-0}" '[.[] | select((.workspace.id // -1) == $workspace) | .address]')"
    floating_count="$(printf '%s' "$clients_json" | jq -r --argjson workspace "${active_workspace:-0}" '[.[] | select((.workspace.id // -1) == $workspace and .floating == true)] | length')"

    state='{}'
    if (( floating_count > 0 )) && [[ -r "$state_file" ]]; then
      state="$(jq -c --argjson addresses "$workspace_addresses" 'with_entries(select(.key as $key | ($addresses | index($key)) != null))' "$state_file" 2>/dev/null || printf '{}')"
    fi

    if [[ "$active_floating" == "true" ]]; then
      state="$(printf '%s' "$state" | jq -c --arg address "$active_address" --argjson width "$active_width" --argjson height "$active_height" '.[$address] = [$width, $height]')"
    fi

    target_address="$(
      printf '%s' "$clients_json" \
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

    ;;
  recent|*)
    "$dispatch_cmd" focuscurrentorlast >/dev/null 2>&1 || true
    "$dispatch_cmd" bringactivetotop >/dev/null 2>&1 || true
    exit 0
    ;;
esac

[[ -n "${target_address:-}" ]] || target_address="$active_address"

if [[ "$active_floating" == "true" ]]; then
  "$dispatch_cmd" settiled >/dev/null 2>&1 || true
fi

"$dispatch_cmd" focuswindow "address:${target_address}" >/dev/null 2>&1 || true
target="$(hyprctl activewindow -j 2>/dev/null || printf '{}')"
target_floating="$(printf '%s' "$target" | jq -r '.floating // false')"

if [[ "$target_floating" == "true" ]]; then
  card_width="$(printf '%s' "$target" | jq -r '.size[0] // 0')"
  card_height="$(printf '%s' "$target" | jq -r '.size[1] // 0')"
else
  card_width="$(printf '%s' "$state" | jq -r --arg address "$target_address" '.[$address][0] // 0')"
  card_height="$(printf '%s' "$state" | jq -r --arg address "$target_address" '.[$address][1] // 0')"

  if (( floating_count == 0 || card_width <= 0 || card_height <= 0 )); then
    monitor_json="$(hyprctl -j monitors 2>/dev/null | jq -c '.[] | select(.focused == true)' | head -n 1)"
    monitor_width="$(printf '%s' "$monitor_json" | jq -r '.width // 0')"
    monitor_height="$(printf '%s' "$monitor_json" | jq -r '.height // 0')"
    card_width="$(( monitor_width * 72 / 100 ))"
    card_height="$(( monitor_height * 76 / 100 ))"
  fi

  (( card_width > 0 && card_height > 0 )) || exit 0
  "$dispatch_cmd" togglefloating >/dev/null 2>&1 || true
  "$dispatch_cmd" resizeactive exact "$card_width" "$card_height" >/dev/null 2>&1 || true
fi

state="$(printf '%s' "$state" | jq -c --arg address "$target_address" --argjson width "$card_width" --argjson height "$card_height" '.[$address] = [$width, $height]')"
umask 077
printf '%s\n' "$state" > "$state_file"

"$dispatch_cmd" centerwindow 1 >/dev/null 2>&1 || true
"$dispatch_cmd" focuswindow "address:${target_address}" >/dev/null 2>&1 || true
"$dispatch_cmd" bringactivetotop >/dev/null 2>&1 || true
