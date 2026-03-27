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
        | . + {
            score:
              (if (.workspace.id // -1) == $workspace then 20 else 0 end) +
              (if (.monitor // -1) == $monitor then 10 else 0 end) +
              (.focusHistoryID // -1)
          }
      ]
      | sort_by(.score)
      | last
      | .address // empty
    '
}

if ! command -v thunar >/dev/null 2>&1; then
  exec xdg-open "${1:-$HOME/Desktop}"
fi

monitors_json="$(hyprctl -j monitors 2>/dev/null || printf '[]')"
focused_monitor="$(printf '%s' "$monitors_json" | jq -r '.[] | select(.focused == true) | .id' | head -n 1)"
focused_monitor_name="$(printf '%s' "$monitors_json" | jq -r '.[] | select(.focused == true) | .name' | head -n 1)"
focused_workspace="$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // empty' 2>/dev/null || true)"
active_window="$(hyprctl activewindow -j 2>/dev/null || printf '{}')"

if [[ "$active_window" != "{}" ]] && [[ "$(printf '%s' "$active_window" | jq -r '.floating // false')" == "true" ]]; then
  hyprctl dispatch alterzorder bottom >/dev/null 2>&1 || true
fi

thunar -w "$@" >/tmp/archmeros-thunar.log 2>&1 &

address=""
for _ in $(seq 1 40); do
  sleep 0.1
  address="$(find_thunar_address "${focused_monitor:-0}" "${focused_workspace:-0}")"
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
  width="$(( monitor_width * 72 / 100 ))"
  height="$(( monitor_height * 76 / 100 ))"

  hyprctl dispatch focuswindow "address:${address}" >/dev/null 2>&1 || true

  if [[ "$(printf '%s' "$client" | jq -r '.floating // false')" != "true" ]]; then
    hyprctl dispatch togglefloating >/dev/null 2>&1 || true
  fi

  hyprctl -q --batch \
    "dispatch focuswindow address:${address};" \
    "dispatch movewindow mon:${focused_monitor_name:-HDMI-A-4};" \
    "dispatch movetoworkspace ${focused_workspace:-1};" \
    "dispatch resizeactive exact $width $height;" \
    "dispatch centerwindow 1;" >/dev/null 2>&1 || true
fi
