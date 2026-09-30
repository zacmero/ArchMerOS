#!/usr/bin/env bash

set -euo pipefail

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/archmeros"
state_file="$state_dir/cinema-mode.json"
dispatch="$HOME/.config/archmeros/scripts/archmeros-hyprctl-dispatch.sh"
blackout="$HOME/.config/archmeros/scripts/archmeros-side-blackout.sh"
monitor_service="turzx-monitor.service"
telemetry_service="archmeros-gaming-telemetry.service"
telemetry=0
action=toggle
requested_monitor=""
while (( $# )); do
  case "$1" in
    --t|--telemetry) telemetry=1 ;;
    --monitor)
      [[ $# -ge 2 ]] || { printf 'Missing monitor name\n' >&2; exit 2; }
      requested_monitor="$2"
      shift
      ;;
    toggle|enter|restore|status) action="$1" ;;
    *) printf 'Usage: cinema [toggle|enter|restore|status] [--t] [--monitor OUTPUT]\n' >&2; exit 2 ;;
  esac
  shift
done

restore() {
  [[ -f "$state_file" ]] || return 0
  jq -e '.keep and (.dpms_off | type == "array")' "$state_file" >/dev/null

  local failed=0 monitor
  while IFS= read -r monitor; do
    "$dispatch" dpms on "$monitor" >/dev/null 2>&1 || failed=1
  done < <(jq -r '.dpms_off[]' "$state_file")

  if jq -e '.blackout_started == true' "$state_file" >/dev/null; then
    "$blackout" stop >/dev/null 2>&1 || failed=1
  fi
  if jq -e '.turzx_stopped == true' "$state_file" >/dev/null; then
    systemctl --no-pager --quiet --no-ask-password start "$monitor_service" >/dev/null 2>&1 || failed=1
  fi
  if jq -e '.telemetry_started == true' "$state_file" >/dev/null; then
    systemctl --user stop "$telemetry_service" >/dev/null 2>&1 || failed=1
  fi
  if jq -e '.turzx_started == true' "$state_file" >/dev/null; then
    systemctl --no-pager --quiet --no-ask-password stop "$monitor_service" >/dev/null 2>&1 || failed=1
  fi

  if (( failed == 0 )); then
    rm -f "$state_file"
  else
    printf 'Cinema mode: some displays could not be restored; retry the toggle.\n' >&2
    return 1
  fi
}

enter() {
  [[ ! -f "$state_file" ]] || return 0
  local monitors keep dpms_off blackout_started=false turzx_stopped=false monitor
  local telemetry_started=false turzx_started=false
  monitors="$(hyprctl monitors -j)"
  keep="$(jq -r '.[] | select(.focused == true) | .name' <<<"$monitors" | head -n 1)"
  if [[ -n "$requested_monitor" ]]; then
    jq -e --arg name "$requested_monitor" 'any(.[]; .name == $name and .dpmsStatus == true)' <<<"$monitors" >/dev/null || { printf 'Requested monitor is not connected and awake\n' >&2; return 1; }
    keep="$requested_monitor"
  fi
  [[ -n "$keep" ]] || { printf 'Cinema mode: no focused monitor.\n' >&2; return 1; }

  dpms_off="$(jq -c --arg keep "$keep" '[.[] | select(.name != $keep and .name != "DP-3" and .dpmsStatus == true) | .name]' <<<"$monitors")"
  # The AOC's existing blackout path is more reliable than DPMS on this panel.
  if [[ "$keep" != "DP-3" ]] && jq -e 'any(.[]; .name == "DP-3" and .dpmsStatus == true)' <<<"$monitors" >/dev/null && ! "$blackout" running >/dev/null 2>&1; then
    blackout_started=true
  fi
  if (( telemetry == 0 )) && systemctl is-active --quiet "$monitor_service"; then
    turzx_stopped=true
  fi
  if (( telemetry )); then
    if ! systemctl is-active --quiet "$monitor_service"; then turzx_started=true; fi
    if ! systemctl --user is-active --quiet "$telemetry_service"; then telemetry_started=true; fi
  fi

  mkdir -p "$state_dir"
  jq -n --arg keep "$keep" --argjson dpms_off "$dpms_off" \
    --argjson blackout_started "$blackout_started" --argjson turzx_stopped "$turzx_stopped" \
    --argjson telemetry_started "$telemetry_started" --argjson turzx_started "$turzx_started" \
    '{keep: $keep, dpms_off: $dpms_off, blackout_started: $blackout_started, turzx_stopped: $turzx_stopped, telemetry_started: $telemetry_started, turzx_started: $turzx_started}' >"$state_file.tmp"
  mv "$state_file.tmp" "$state_file"
  if (( telemetry )); then
    systemctl --no-pager --quiet --no-ask-password start "$monitor_service" >/dev/null 2>&1 || { restore; return 1; }
    systemctl --user start "$telemetry_service" || { restore; return 1; }
  fi

  if [[ "$turzx_stopped" == true ]]; then
    systemctl --no-pager --quiet --no-ask-password stop "$monitor_service" >/dev/null 2>&1 || { restore; return 1; }
  fi
  if [[ "$blackout_started" == true ]]; then
    "$blackout" start >/dev/null 2>&1 || { restore; return 1; }
  fi
  while IFS= read -r monitor; do
    "$dispatch" dpms off "$monitor" >/dev/null 2>&1 || { restore; return 1; }
  done < <(jq -r '.dpms_off[]' "$state_file")
}

case "$action" in
  toggle) if [[ -f "$state_file" ]]; then restore; else enter; fi ;;
  enter) enter ;;
  restore) restore ;;
  status) if [[ -f "$state_file" ]]; then jq . "$state_file"; else printf '{"active":false}\n'; fi ;;
  *) printf 'Usage: %s [toggle|enter|restore|status]\n' "$0" >&2; exit 2 ;;
esac
