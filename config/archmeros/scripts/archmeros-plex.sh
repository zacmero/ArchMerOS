#!/usr/bin/env bash

set -euo pipefail

media_root="/run/media/zacmero/New Volume/Plex"
action="${1:-help}"

usage() {
  cat <<'EOF'
usage: archmeros-plex.sh <start|stop|restart|status|web>

start   grant Plex access to the external media path and start plexmediaserver
stop    stop plexmediaserver
restart restart plexmediaserver
status  show service status
web     open Plex Web at http://127.0.0.1:32400/web
EOF
}

ensure_access() {
  if [[ ! -d "$media_root" ]]; then
    printf 'plex media path missing: %s\n' "$media_root" >&2
    exit 1
  fi

  sudo setfacl -m u:plex:rx /run/media/zacmero >/dev/null
  sudo setfacl -R -m u:plex:rX "$media_root" >/dev/null
}

start_service() {
  ensure_access
  sudo systemctl start plexmediaserver
}

case "$action" in
  start)
    start_service
    ;;
  stop)
    sudo systemctl stop plexmediaserver
    ;;
  restart)
    ensure_access
    sudo systemctl restart plexmediaserver
    ;;
  status)
    sudo systemctl status plexmediaserver --no-pager -l
    ;;
  web)
    xdg-open "http://127.0.0.1:32400/web" >/dev/null 2>&1 &
    ;;
  *)
    usage
    exit 1
    ;;
esac
