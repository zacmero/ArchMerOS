#!/usr/bin/env bash

set -euo pipefail

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/archmeros"
style_path="${HOME}/.config/waybar/style.css"
hidden_file="${state_dir}/waybar-hidden.json"

mkdir -p "$state_dir"

latest_instance_dir() {
  find "${runtime_dir}/hypr" -maxdepth 1 -mindepth 1 -type d \
    -exec test -S '{}/.socket.sock' ';' -print \
    | sort | tail -n 1
}

setup_hypr_env() {
  local instance_info sig sock

  if command -v hyprctl >/dev/null 2>&1; then
    instance_info="$(hyprctl instances -j 2>/dev/null || true)"
    if [[ -n "${instance_info:-}" && "${instance_info}" != "[]" ]]; then
      read -r sig sock < <(
        jq -r --arg current "${HYPRLAND_INSTANCE_SIGNATURE:-}" '
          ((map(select(.instance == $current)) | first) // max_by(.time))
          | [.instance, .wl_socket]
          | @tsv
        ' <<<"$instance_info" 2>/dev/null || true
      ) || true
      if [[ -n "$sig" && -n "$sock" && -S "${runtime_dir}/${sock}" ]]; then
        export XDG_RUNTIME_DIR="$runtime_dir"
        export WAYLAND_DISPLAY="$sock"
        export HYPRLAND_INSTANCE_SIGNATURE="$sig"
        return 0
      fi
    fi
  fi

  local instance_dir wayland_socket
  instance_dir="$(latest_instance_dir)"
  if [[ -z "${instance_dir:-}" ]]; then
    printf 'ArchMerOS waybar: no active Hyprland instance found.\n' >&2
    return 1
  fi

  wayland_socket="$(
    find "$runtime_dir" -maxdepth 1 -type s -name 'wayland-*' \
      | xargs -r -n1 basename \
      | sort | tail -n 1
  )"

  if [[ -z "${wayland_socket:-}" ]]; then
    printf 'ArchMerOS waybar: no Wayland socket found in %s\n' "$runtime_dir" >&2
    return 1
  fi

  export XDG_RUNTIME_DIR="$runtime_dir"
  export WAYLAND_DISPLAY="$wayland_socket"
  export HYPRLAND_INSTANCE_SIGNATURE="$(basename "$instance_dir")"
}

focused_monitor() {
  hyprctl -j monitors | jq -r '.[] | select(.focused == true) | .name' | head -n 1
}

monitor_name_for_slot() {
  case "${1:-}" in
    1) printf 'DP-3\n' ;;
    2) printf 'HDMI-A-1\n' ;;
    3) printf 'DP-2\n' ;;
    *)
      return 1
      ;;
  esac
}

hidden_monitors_json() {
  if [[ -f "$hidden_file" ]]; then
    cat "$hidden_file"
  else
    printf '[]\n'
  fi
}

monitor_visible() {
  local monitor="$1"
  ! jq -e --arg monitor "$monitor" 'index($monitor)' <<<"$(hidden_monitors_json)" >/dev/null
}

start_bar() {
  local config="$1"
  local name="$2"
  setsid waybar -c "$config" -s "$style_path" >"/tmp/archmeros-waybar-${name}.log" 2>&1 < /dev/null &
  sleep 0.35
}

wait_for_waybar_stop() {
  local attempt
  for attempt in {1..20}; do
    pgrep -x waybar >/dev/null 2>&1 || return 0
    sleep 0.1
  done
}

restart_waybar() {
  pkill -x waybar >/dev/null 2>&1 || true
  wait_for_waybar_stop

  if monitor_visible "DP-3"; then
    start_bar "${HOME}/.config/waybar/left.jsonc" "left"
  fi

  if monitor_visible "HDMI-A-1"; then
    start_bar "${HOME}/.config/waybar/center.jsonc" "center"
  fi

  if monitor_visible "DP-2"; then
    start_bar "${HOME}/.config/waybar/right.jsonc" "right"
  fi
}

toggle_focused_monitor() {
  local monitor current_json
  monitor="$(focused_monitor)"
  if [[ -z "${monitor:-}" ]]; then
    printf 'ArchMerOS waybar: no focused monitor detected.\n' >&2
    return 1
  fi

  current_json="$(hidden_monitors_json)"
  jq \
    --arg monitor "$monitor" \
    '
      if index($monitor)
      then map(select(. != $monitor))
      else . + [$monitor]
      end
    ' <<<"$current_json" >"${hidden_file}.tmp"
  mv "${hidden_file}.tmp" "$hidden_file"
  restart_waybar
}

toggle_monitor_slot() {
  local slot monitor current_json
  slot="${1:-}"
  monitor="$(monitor_name_for_slot "$slot")" || {
    printf 'ArchMerOS waybar: unknown monitor slot %s\n' "$slot" >&2
    return 1
  }

  current_json="$(hidden_monitors_json)"
  jq \
    --arg monitor "$monitor" \
    '
      if index($monitor)
      then map(select(. != $monitor))
      else . + [$monitor]
      end
    ' <<<"$current_json" >"${hidden_file}.tmp"
  mv "${hidden_file}.tmp" "$hidden_file"
  restart_waybar
}

show_all() {
  rm -f "$hidden_file"
  restart_waybar
}

toggle_all() {
  local current_json hidden_count

  current_json="$(hidden_monitors_json)"
  hidden_count="$(jq 'length' <<<"$current_json")"

  if [[ "$hidden_count" -ge 3 ]]; then
    show_all
    return
  fi

  jq -n '["DP-3","HDMI-A-1","DP-2"]' >"$hidden_file"
  restart_waybar
}

case "${1:-start}" in
  start|restart)
    setup_hypr_env
    restart_waybar
    ;;
  stop)
    pkill -x waybar >/dev/null 2>&1 || true
    ;;
  toggle)
    setup_hypr_env
    toggle_focused_monitor
    ;;
  toggleall)
    setup_hypr_env
    toggle_all
    ;;
  toggle1|toggle2|toggle3)
    setup_hypr_env
    toggle_monitor_slot "${1#toggle}"
    ;;
  toggle-monitor)
    setup_hypr_env
    toggle_monitor_slot "${2:-}"
    ;;
  showall)
    setup_hypr_env
    show_all
    ;;
  output)
    setup_hypr_env
    focused_monitor
    ;;
  hidden)
    hidden_monitors_json
    ;;
  *)
    printf 'Usage: %s {start|restart|stop|toggle|toggleall|showall|output|hidden}\n' "$0" >&2
    exit 1
    ;;
esac
