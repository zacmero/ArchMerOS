#!/usr/bin/env bash

set -euo pipefail

[[ $# -gt 0 ]] || exit 1

native_spawn=0
spawn_class=""
if [[ "${1:-}" == "--native-spawn" ]]; then
  [[ $# -ge 3 && -n "${2:-}" ]] || exit 2
  native_spawn=1
  spawn_class="$2"
  shift 2
fi

process_name="$(basename -- "$1" 2>/dev/null || printf '%s' "$1")"
force_pop_mode="${ARCHMEROS_FORCE_POP_MODE:-}"
skip_history="${ARCHMEROS_SKIP_HISTORY:-0}"
unset ARCHMEROS_NATIVE_SPAWN ARCHMEROS_SPAWN_CLASS ARCHMEROS_FORCE_POP_MODE ARCHMEROS_SKIP_HISTORY

json_or_default() {
  local raw="${1:-}"
  local fallback="${2:-}"
  case "$raw" in
    \[*|\{*)
      printf '%s\n' "$raw"
      ;;
    *)
      printf '%s\n' "$fallback"
      ;;
  esac
}

if [[ "$skip_history" != "1" ]]; then
  track_command=(
    python3 "$HOME/.config/archmeros/scripts/archmeros-reopen-history.py"
    track-launch general "" "" "$process_name" --
    "$HOME/.config/archmeros/scripts/archmeros-launch-detached.sh" "$@"
  )
  if [[ "$native_spawn" == "1" ]]; then
    nohup "${track_command[@]}" >/tmp/archmeros-reopen-track-general.log 2>&1 &
  else
    "${track_command[@]}" >/tmp/archmeros-reopen-track-general.log 2>&1 || true
  fi
fi

mode="none"
monitor_name=""
workspace_id=""
dispatch_cmd="$HOME/.config/archmeros/scripts/archmeros-hyprctl-dispatch.sh"
monitor_width=0
monitor_height=0
target_width=0
target_height=0
lua_provider=0
spawn_rule_active=0
spawn_rule_var=""

if [[ -n "$force_pop_mode" ]]; then
  mode="$force_pop_mode"
fi

if command -v hyprctl >/dev/null 2>&1; then
  if hyprctl systeminfo 2>/dev/null | grep -q 'configProvider: lua'; then
    lua_provider=1
  fi
  monitors_json="$(json_or_default "$(hyprctl -j monitors 2>/dev/null || true)" '[]')"
  monitor_name="$(printf '%s' "$monitors_json" | jq -r '.[] | select(.focused == true) | .name' | head -n 1)"
  workspace_json="$(json_or_default "$(hyprctl activeworkspace -j 2>/dev/null || true)" '{}')"
  workspace_id="$(printf '%s' "$workspace_json" | jq -r '.id // empty' 2>/dev/null || true)"
  active="$(json_or_default "$(hyprctl activewindow -j 2>/dev/null || true)" '{}')"
  monitor_size="$(printf '%s' "$monitors_json" | jq -r '.[] | select(.focused == true) | .width, .height' | paste -sd" " -)"
  monitor_width="$(printf '%s' "$monitor_size" | awk '{print $1}')"
  monitor_height="$(printf '%s' "$monitor_size" | awk '{print $2}')"

  if [[ "$mode" == "none" && -n "$workspace_id" ]]; then
    clients_json="$(json_or_default "$(hyprctl -j clients 2>/dev/null || true)" '[]')"
    occupied_windows="$(printf '%s' "$clients_json" | jq -r --argjson workspace "$workspace_id" '[.[] | select(.mapped == true and .hidden == false) | select((.workspace.id // -1) == $workspace)] | length')"
    if [[ "$occupied_windows" == "0" ]]; then
      mode="max"
    else
      mode="medium"
    fi
  fi

  if [[ "$active" != "{}" ]]; then
    if [[ "$(printf '%s' "$active" | jq -r '.floating // false')" == "true" ]]; then
      "$dispatch_cmd" alterzorder bottom >/dev/null 2>&1 || true
    fi
  fi
fi

if (( monitor_width > 0 && monitor_height > 0 )); then
  if [[ "$mode" == "max" ]]; then
    monitor_json="$(printf '%s' "$monitors_json" | jq -c '.[] | select(.focused == true)' | head -n 1)"
    reserved_left="$(printf '%s' "$monitor_json" | jq -r '.reserved[0] // 0')"
    reserved_top="$(printf '%s' "$monitor_json" | jq -r '.reserved[1] // 0')"
    reserved_right="$(printf '%s' "$monitor_json" | jq -r '.reserved[2] // 0')"
    reserved_bottom="$(printf '%s' "$monitor_json" | jq -r '.reserved[3] // 0')"
    gaps_css="$(hyprctl getoption general:gaps_out -j 2>/dev/null | jq -r '.css // "10 10 10 10"')"
    read -r gap_top gap_right gap_bottom gap_left <<< "$gaps_css"
    border_size="$(hyprctl getoption general:border_size -j 2>/dev/null | jq -r '.int // 2')"
    target_width="$(( monitor_width - reserved_left - reserved_right - gap_left - gap_right - border_size * 2 ))"
    target_height="$(( monitor_height - reserved_top - reserved_bottom - gap_top - gap_bottom - border_size * 2 ))"
  elif [[ "$mode" == "full" ]]; then
    target_width="$(( monitor_width * 96 / 100 ))"
    target_height="$(( monitor_height * 92 / 100 ))"
  elif [[ "$mode" == "medium" ]]; then
    target_width="$(( monitor_width * 72 / 100 ))"
    target_height="$(( monitor_height * 76 / 100 ))"
  fi
fi

if [[ "$native_spawn" == "1" && "$lua_provider" == "1" && -n "$spawn_class" && "$mode" =~ ^(max|full|medium)$ ]]; then
  spawn_rule_var="archmeros_wezterm_spawn_${spawn_class//[^a-zA-Z0-9_]/_}"
  if (( target_width > 0 && target_height > 0 )) && hyprctl eval \
    "_G[\"${spawn_rule_var}\"] = hl.window_rule({ name = \"${spawn_rule_var}\", match = { class = \"^${spawn_class}$\", workspace = \"${workspace_id}\" }, float = true, size = {${target_width}, ${target_height}}, center = true })" \
    >/dev/null 2>&1; then
    spawn_rule_active=1
  fi
fi

setsid "$@" >/tmp/archmeros-launch-detached.log 2>&1 < /dev/null &
app_pid=$!

if [[ "$spawn_rule_active" == "1" ]]; then
  (
    for _ in $(seq 1 80); do
      if hyprctl -j clients 2>/dev/null | jq -e --arg class "$spawn_class" '.[] | select(.class == $class)' >/dev/null; then
        break
      fi
      sleep 0.05
    done
    sleep 0.05
    hyprctl eval \
      "if _G[\"${spawn_rule_var}\"] then _G[\"${spawn_rule_var}\"]:set_enabled(false); _G[\"${spawn_rule_var}\"] = nil end" \
      >/dev/null 2>&1 || true
  ) &
fi

if [[ "$native_spawn" == "1" && "$lua_provider" == "1" && ( "$mode" == "none" || "$spawn_rule_active" == "1" ) ]]; then
  disown || true
  exit 0
fi

nohup python3 "$HOME/.config/archmeros/scripts/archmeros-promote-pid.py" \
  "$app_pid" "$mode" "${monitor_name:-}" "${workspace_id:-}" \
  "$target_width" "$target_height" \
  >/tmp/archmeros-promote-pid.log 2>&1 &

disown || true
exit 0
