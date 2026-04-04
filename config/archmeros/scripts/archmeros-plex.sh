#!/usr/bin/env bash

set -euo pipefail

app_support_dir="${XDG_DATA_HOME:-$HOME/.local/share}/archmeros/plex"
log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/archmeros"
log_path="${log_dir}/plex-server.log"
pid_path="${app_support_dir}/plex.pid"
media_root="/run/media/zacmero/New Volume/Plex"
plex_home="/usr/lib/plexmediaserver"
plex_bin="${plex_home}/Plex Media Server"
prefs_dir="${app_support_dir}/Plex Media Server"
prefs_path="${prefs_dir}/Preferences.xml"

mkdir -p "$app_support_dir" "$log_dir"

usage() {
  cat <<'EOF'
usage: archmeros-plex.sh <start|stop|restart|status|web>

start   start Plex Media Server as the current user
stop    stop the user-run Plex Media Server
restart restart the user-run Plex Media Server
status  show whether the user-run Plex Media Server is active
web     open Plex Web in app mode
EOF
}

is_running() {
  if [[ -f "$pid_path" ]]; then
    local pid
    pid="$(cat "$pid_path" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
  fi

  pgrep -u "$USER" -f "${plex_bin}" >/dev/null 2>&1
}

write_pid() {
  local pid="$1"
  printf '%s\n' "$pid" >"$pid_path"
}

cleanup_stale_pid() {
  if [[ -f "$pid_path" ]]; then
    local pid
    pid="$(cat "$pid_path" 2>/dev/null || true)"
    if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
      rm -f "$pid_path"
    fi
  fi
}

ensure_network_prefs() {
  if [[ -f "$prefs_path" ]]; then
    "$HOME/.config/archmeros/scripts/archmeros-plex-preferences.py" "$prefs_path" >/dev/null 2>&1 || true
  fi
}

start_server() {
  if [[ ! -x "$plex_bin" ]]; then
    printf 'plex binary missing: %s\n' "$plex_bin" >&2
    exit 1
  fi

  if [[ ! -d "$media_root" ]]; then
    printf 'plex media path missing: %s\n' "$media_root" >&2
    exit 1
  fi

  cleanup_stale_pid
  ensure_network_prefs

  if is_running; then
    return 0
  fi

  nohup env \
    LD_LIBRARY_PATH="${plex_home}/lib" \
    PLEX_MEDIA_SERVER_HOME="${plex_home}" \
    PLEX_MEDIA_SERVER_APPLICATION_SUPPORT_DIR="${app_support_dir}" \
    PLEX_MEDIA_SERVER_MAX_PLUGIN_PROCS=6 \
    PLEX_MEDIA_SERVER_TMPDIR=/tmp \
    TMPDIR=/tmp \
    "${plex_bin}" >>"$log_path" 2>&1 &

  write_pid "$!"
}

stop_server() {
  cleanup_stale_pid
  if [[ -f "$pid_path" ]]; then
    local pid
    pid="$(cat "$pid_path" 2>/dev/null || true)"
    if [[ -n "$pid" ]]; then
      kill "$pid" >/dev/null 2>&1 || true
      sleep 1
      kill -9 "$pid" >/dev/null 2>&1 || true
    fi
    rm -f "$pid_path"
    return 0
  fi

  pkill -u "$USER" -f "${plex_bin}" >/dev/null 2>&1 || true
  rm -f "$pid_path"
}

status_server() {
  cleanup_stale_pid
  if is_running; then
    printf 'plex: running\n'
  else
    printf 'plex: stopped\n'
    return 1
  fi
}

open_web() {
  "$HOME/.config/archmeros/scripts/archmeros-webapp.sh" plex
}

case "${1:-help}" in
  start)
    start_server
    ;;
  stop)
    stop_server
    ;;
  restart)
    stop_server
    start_server
    ;;
  status)
    status_server
    ;;
  web)
    open_web
    ;;
  *)
    usage
    exit 1
    ;;
esac
