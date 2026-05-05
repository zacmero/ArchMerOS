#!/usr/bin/env bash

set -euo pipefail

config_dir="${HOME}/.config/qBittorrent"
lockfile="${config_dir}/lockfile"
ipc_socket="${config_dir}/ipc-socket"

if ! pgrep -x qbittorrent >/dev/null 2>&1; then
  rm -f "${lockfile}" "${ipc_socket}" 2>/dev/null || true
fi

exec ~/.config/archmeros/scripts/archmeros-launch-detached.sh \
  qbittorrent \
  "$@"
