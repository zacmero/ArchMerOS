#!/usr/bin/env bash
set -euo pipefail

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
  WAYLAND_DISPLAY="$(ls "$XDG_RUNTIME_DIR"/wayland-* 2>/dev/null | head -n 1 | xargs -r basename || true)"
  export WAYLAND_DISPLAY
fi

export DISPLAY="${DISPLAY:-:0}"
export GDK_BACKEND="${GDK_BACKEND:-wayland,x11}"

log_file=/tmp/archmeros-calendar-click.log
{
  printf '== %s ==\n' "$(date --iso-8601=seconds)"
  printf 'DISPLAY=%s\n' "${DISPLAY:-}"
  printf 'WAYLAND_DISPLAY=%s\n' "${WAYLAND_DISPLAY:-}"
  printf 'XDG_RUNTIME_DIR=%s\n' "${XDG_RUNTIME_DIR:-}"
} >>"$log_file"

exec python3 "$HOME/.config/archmeros/scripts/archmeros-calendar-popup.py" >>"$log_file" 2>&1
