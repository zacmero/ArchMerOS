#!/usr/bin/env bash

set -euo pipefail

find_new_thunar_address() {
  local known_addresses="$1"
  local clients
  clients="$(hyprctl -j clients 2>/dev/null || printf '[]')"

  printf '%s' "$clients" | jq -r \
    --argjson known "$known_addresses" '
      [
        .[]
        | select(((.class // .initialClass // "") | ascii_downcase) == "thunar")
        | select(.address as $address | ($known | index($address) | not))
        | . + { score: (.focusHistoryID // -1) }
      ]
      | sort_by(.score)
      | last
      | .address // empty
    '
}

if ! command -v thunar >/dev/null 2>&1; then
  exec xdg-open "${1:-$HOME/Desktop}"
fi

python3 "$HOME/.config/archmeros/scripts/archmeros-reopen-history.py" \
  track-launch folder thunar "" thunar -- \
  "$HOME/.config/archmeros/scripts/archmeros-thunar.sh" "$@" \
  >/tmp/archmeros-reopen-track-thunar.log 2>&1 || true

monitors_json="$(hyprctl -j monitors 2>/dev/null || printf '[]')"
focused_monitor="$(printf '%s' "$monitors_json" | jq -r '.[] | select(.focused == true) | .id' | head -n 1)"
focused_monitor_name="$(printf '%s' "$monitors_json" | jq -r '.[] | select(.focused == true) | .name' | head -n 1)"
focused_workspace="$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // empty' 2>/dev/null || true)"
prelaunch_clients="$(hyprctl -j clients 2>/dev/null || printf '[]')"
known_thunar_addresses="$(printf '%s' "$prelaunch_clients" | jq '[.[] | select(((.class // .initialClass // "") | ascii_downcase) == "thunar") | .address]')"
occupied_windows="$(printf '%s' "$prelaunch_clients" | jq -r \
  --argjson monitor "${focused_monitor:-0}" \
  --argjson workspace "${focused_workspace:-0}" \
  '[.[] | select((.monitor // -1) == $monitor and (.workspace.id // -1) == $workspace)] | length')"

thunar -w "$@" >/tmp/archmeros-thunar.log 2>&1 &

address=""
for _ in $(seq 1 40); do
  sleep 0.1
  address="$(find_new_thunar_address "$known_thunar_addresses")"
  [[ -n "$address" ]] && break
done

if [[ -z "$address" ]]; then
  exit 0
fi

clients_json="$(hyprctl -j clients 2>/dev/null || printf '[]')"
client="$(printf '%s' "$clients_json" | jq -r --arg address "$address" '
  .[]
  | select(.address == $address)
')"

if [[ -z "$client" ]]; then
  exit 0
fi

monitor_width="$(printf '%s' "$monitors_json" | jq -r --argjson monitor "${focused_monitor:-0}" '.[] | select(.id == $monitor) | .width' | head -n 1)"
monitor_height="$(printf '%s' "$monitors_json" | jq -r --argjson monitor "${focused_monitor:-0}" '.[] | select(.id == $monitor) | .height' | head -n 1)"

if [[ -n "${monitor_width:-}" && -n "${monitor_height:-}" ]]; then
  if [[ "${occupied_windows:-1}" == "0" ]]; then
    width="$(( monitor_width * 96 / 100 ))"
    height="$(( monitor_height * 92 / 100 ))"
  else
    width="$(( monitor_width * 72 / 100 ))"
    height="$(( monitor_height * 76 / 100 ))"
  fi

  hyprctl dispatch focuswindow "address:${address}" >/dev/null 2>&1 || true

  if [[ "$(printf '%s' "$client" | jq -r '.floating // false')" != "true" ]]; then
    hyprctl dispatch togglefloating >/dev/null 2>&1 || true
  fi

  hyprctl -q --batch \
    "dispatch focuswindow address:${address};" \
    "dispatch movewindow mon:${focused_monitor_name:-HDMI-A-1};" \
    "dispatch movetoworkspace ${focused_workspace:-1};" \
    "dispatch resizeactive exact $width $height;" \
    "dispatch centerwindow 1;" >/dev/null 2>&1 || true
fi
