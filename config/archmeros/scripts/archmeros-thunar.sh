#!/usr/bin/env bash

set -euo pipefail

dispatch_cmd="$HOME/.config/archmeros/scripts/archmeros-hyprctl-dispatch.sh"

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

monitor_width="$(printf '%s' "$monitors_json" | jq -r --argjson monitor "${focused_monitor:-0}" '.[] | select(.id == $monitor) | .width' | head -n 1)"
monitor_height="$(printf '%s' "$monitors_json" | jq -r --argjson monitor "${focused_monitor:-0}" '.[] | select(.id == $monitor) | .height' | head -n 1)"
target_width=""
target_height=""

if [[ -n "${monitor_width:-}" && -n "${monitor_height:-}" ]]; then
  if [[ "${occupied_windows:-1}" == "0" ]]; then
    monitor_json="$(printf '%s' "$monitors_json" | jq -c --argjson monitor "${focused_monitor:-0}" '.[] | select(.id == $monitor)')"
    reserved_left="$(printf '%s' "$monitor_json" | jq -r '.reserved[0] // 0')"
    reserved_top="$(printf '%s' "$monitor_json" | jq -r '.reserved[1] // 0')"
    reserved_right="$(printf '%s' "$monitor_json" | jq -r '.reserved[2] // 0')"
    reserved_bottom="$(printf '%s' "$monitor_json" | jq -r '.reserved[3] // 0')"
    gaps_css="$(hyprctl getoption general:gaps_out -j 2>/dev/null | jq -r '.css // "10 10 10 10"')"
    read -r gap_top gap_right gap_bottom gap_left <<< "$gaps_css"
    border_size="$(hyprctl getoption general:border_size -j 2>/dev/null | jq -r '.int // 2')"
    target_width="$(( monitor_width - reserved_left - reserved_right - gap_left - gap_right - border_size * 2 ))"
    target_height="$(( monitor_height - reserved_top - reserved_bottom - gap_top - gap_bottom - border_size * 2 ))"
  else
    target_width="$(( monitor_width * 72 / 100 ))"
    target_height="$(( monitor_height * 76 / 100 ))"
  fi
fi

spawn_rule_active=0
disable_spawn_rule() {
  if [[ "$spawn_rule_active" == "1" ]]; then
    hyprctl eval 'if archmeros_thunar_spawn_rule then archmeros_thunar_spawn_rule:set_enabled(false) end' >/dev/null 2>&1 || true
  fi
}
trap disable_spawn_rule EXIT

if [[ "${occupied_windows:-1}" == "0" &&
      -n "${focused_workspace:-}" &&
      -n "$target_width" &&
      -n "$target_height" ]] &&
   hyprctl systeminfo 2>/dev/null | grep -q 'configProvider: lua'; then
  hyprctl eval "archmeros_thunar_spawn_rule = hl.window_rule({ name = \"archmeros-thunar-spawn\", match = { class = \"^(thunar|Thunar)$\", workspace = \"${focused_workspace}\" }, float = true, size = {${target_width}, ${target_height}}, center = true })" >/dev/null
  spawn_rule_active=1
fi

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

if [[ -n "${monitor_width:-}" && -n "${monitor_height:-}" ]]; then
  width="$target_width"
  height="$target_height"

  client_floating="$(printf '%s' "$client" | jq -r '.floating // false')"
  client_monitor="$(printf '%s' "$client" | jq -r '.monitor // -1')"
  client_workspace="$(printf '%s' "$client" | jq -r '.workspace.id // -1')"
  client_width="$(printf '%s' "$client" | jq -r '.size[0] // 0')"
  client_height="$(printf '%s' "$client" | jq -r '.size[1] // 0')"

  if [[ "$client_floating" == "true" &&
        "$client_monitor" == "${focused_monitor:-}" &&
        "$client_workspace" == "${focused_workspace:-}" &&
        "$client_width" == "$width" &&
        "$client_height" == "$height" ]]; then
    exit 0
  fi

  "$dispatch_cmd" focuswindow "address:${address}" >/dev/null 2>&1 || true

  if [[ "$(printf '%s' "$client" | jq -r '.floating // false')" != "true" ]]; then
    "$dispatch_cmd" togglefloating >/dev/null 2>&1 || true
  fi

  "$dispatch_cmd" focuswindow "address:${address}" >/dev/null 2>&1 || true
  "$dispatch_cmd" movewindow "mon:${focused_monitor_name:-HDMI-A-1}" >/dev/null 2>&1 || true
  "$dispatch_cmd" movetoworkspace "${focused_workspace:-1}" >/dev/null 2>&1 || true
  "$dispatch_cmd" resizeactive exact "$width" "$height" >/dev/null 2>&1 || true
  "$dispatch_cmd" centerwindow 1 >/dev/null 2>&1 || true
fi
