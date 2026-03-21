#!/usr/bin/env bash

set -euo pipefail

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
hypr_root="${runtime_dir}/hypr"

if [[ ! -d "$hypr_root" ]]; then
  printf 'ArchMerOS refresh: Hyprland runtime dir not found at %s\n' "$hypr_root" >&2
  exit 1
fi

instance_dir="$(
  find "$hypr_root" -maxdepth 1 -mindepth 1 -type d \
    -exec test -S '{}/.socket.sock' ';' -print \
    | sort | tail -n 1
)"

if [[ -z "$instance_dir" ]]; then
  printf 'ArchMerOS refresh: no active Hyprland instance socket found.\n' >&2
  exit 1
fi

wayland_socket="$(
  find "$runtime_dir" -maxdepth 1 -type s -name 'wayland-*' \
    | xargs -r -n1 basename \
    | sort | tail -n 1
)"

if [[ -z "$wayland_socket" ]]; then
  printf 'ArchMerOS refresh: no Wayland socket found in %s\n' "$runtime_dir" >&2
  exit 1
fi

export XDG_RUNTIME_DIR="$runtime_dir"
export WAYLAND_DISPLAY="$wayland_socket"
export HYPRLAND_INSTANCE_SIGNATURE="$(basename "$instance_dir")"

python3 "${HOME}/.config/archmeros/scripts/archmeros-theme.py" --reapply-current --no-refresh >/tmp/archmeros-theme-reapply.log 2>&1 || true
hyprctl reload >/tmp/archmeros-hyprctl-reload.log 2>&1 || true
systemctl --user stop archmeros-elephant.service archmeros-walker.service >/dev/null 2>&1 || true
pkill -x walker >/dev/null 2>&1 || true
pkill -x elephant >/dev/null 2>&1 || true
pkill -f 'archmeros-waybar.sh' >/dev/null 2>&1 || true
pkill -f 'waybar.runtime.jsonc' >/dev/null 2>&1 || true
pkill -x mako >/dev/null 2>&1 || true

pkill -x waybar >/dev/null 2>&1 || true
setsid waybar \
  -c "${HOME}/.config/waybar/config.jsonc" \
  -s "${HOME}/.config/waybar/style.css" \
  >/tmp/archmeros-waybar.log 2>&1 < /dev/null &

setsid mako -c "${HOME}/.config/mako/config" >/tmp/archmeros-mako.log 2>&1 < /dev/null &

"${HOME}/.config/archmeros/scripts/archmeros-wallpaper.sh" --no-theme-sync
systemctl --user start archmeros-elephant.service archmeros-walker.service >/dev/null 2>&1 || true

printf 'ArchMerOS shell refreshed on %s (%s)\n' "$HYPRLAND_INSTANCE_SIGNATURE" "$WAYLAND_DISPLAY"
