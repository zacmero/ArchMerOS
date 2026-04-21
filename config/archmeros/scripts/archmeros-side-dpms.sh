#!/usr/bin/env bash

set -euo pipefail

dpms_monitors=(DP-2)
mode="${1:-toggle}"
monitor_service="turzx-monitor.service"
log_file="/tmp/archmeros-side-dpms.log"
blackout_script="$HOME/.config/archmeros/scripts/archmeros-side-blackout.sh"

monitors_json="$(hyprctl monitors -j 2>/dev/null || printf '[]')"

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" >>"$log_file" 2>/dev/null || true
}

set_monitor_service_state() {
  local state="$1"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --no-pager --quiet --no-ask-password "$state" "$monitor_service" >/dev/null 2>&1 || true
  fi
}

case "$mode" in
  toggle)
    target_state="off"
    if "$blackout_script" running >/dev/null 2>&1; then
      target_state="on"
    fi
    for monitor in "${dpms_monitors[@]}"; do
      if printf '%s\n' "$monitors_json" | jq -e --arg name "$monitor" '.[] | select(.name == $name and .dpmsStatus == false)' >/dev/null 2>&1; then
        target_state="on"
        break
      fi
    done
    ;;
  on|off)
    target_state="$mode"
    ;;
  *)
    printf 'usage: %s [toggle|on|off]\n' "$0" >&2
    exit 1
    ;;
esac

if [[ "$target_state" == "off" ]]; then
  log "stopping ${monitor_service}"
  set_monitor_service_state stop
  log "starting DP-3 blackout"
  "$blackout_script" start >/dev/null 2>&1 || true
fi

for monitor in "${dpms_monitors[@]}"; do
  if hyprctl dispatch dpms "$target_state" "$monitor" >/dev/null 2>&1; then
    log "dpms ${target_state} ${monitor}"
  else
    log "dpms ${target_state} ${monitor} failed"
  fi
done

if [[ "$target_state" == "on" ]]; then
  log "stopping DP-3 blackout"
  "$blackout_script" stop >/dev/null 2>&1 || true
  hyprctl dispatch dpms on DP-3 >/dev/null 2>&1 || true
  log "starting ${monitor_service}"
  set_monitor_service_state start
fi
