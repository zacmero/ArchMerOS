#!/usr/bin/env bash

set -euo pipefail

find_thunar_address() {
  local monitor_id="$1"
  local workspace_id="$2"
  local clients
  clients="$(hyprctl -j clients 2>/dev/null || printf '[]')"

  printf '%s' "$clients" | jq -r \
    --argjson monitor "$monitor_id" \
    --argjson workspace "$workspace_id" '
      [
        .[]
        | select(((.class // .initialClass // "") | ascii_downcase) == "thunar")
        | select((.workspace.id // -1) == $workspace or (.monitor // -1) == $monitor)
      ]
      | sort_by(.focusHistoryID // -1)
      | last
      | .address // empty
    '
}

if ! command -v thunar >/dev/null 2>&1; then
  exec xdg-open "${1:-$HOME/Desktop}"
fi

focused_monitor="$(hyprctl -j monitors 2>/dev/null | jq -r '.[] | select(.focused == true) | .id' | head -n 1)"
focused_workspace="$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // empty')"

thunar "$@" >/tmp/archmeros-thunar.log 2>&1 &

address=""
for _ in $(seq 1 40); do
  sleep 0.1
  address="$(find_thunar_address "${focused_monitor:-0}" "${focused_workspace:-0}")"
  [[ -n "$address" ]] && break
done

if [[ -z "$address" ]]; then
  exit 0
fi

client="$(hyprctl -j clients 2>/dev/null | jq -r --arg address "$address" '
  .[]
  | select(.address == $address)
')"

if [[ -z "$client" ]]; then
  exit 0
fi

monitor_width="$(hyprctl -j monitors 2>/dev/null | jq -r --argjson monitor "${focused_monitor:-0}" '.[] | select(.id == $monitor) | .width' | head -n 1)"
monitor_height="$(hyprctl -j monitors 2>/dev/null | jq -r --argjson monitor "${focused_monitor:-0}" '.[] | select(.id == $monitor) | .height' | head -n 1)"

if [[ -n "${monitor_width:-}" && -n "${monitor_height:-}" ]]; then
  width="$(( monitor_width * 72 / 100 ))"
  height="$(( monitor_height * 76 / 100 ))"

  hyprctl dispatch focuswindow "address:${address}" >/dev/null 2>&1 || true

  if [[ "$(printf '%s' "$client" | jq -r '.floating // false')" != "true" ]]; then
    hyprctl dispatch togglefloating >/dev/null 2>&1 || true
  fi

  hyprctl -q --batch \
    "dispatch focuswindow address:${address};" \
    "dispatch resizeactive exact $width $height;" \
    "dispatch centerwindow 1;" >/dev/null 2>&1 || true
fi
