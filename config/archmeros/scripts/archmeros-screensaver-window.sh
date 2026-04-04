#!/usr/bin/env bash

set -euo pipefail

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
repo_root="$(cd -- "$(dirname -- "$script_path")/../../.." && pwd)"
log_path="/tmp/archmeros-screensaver.log"
lock_path="${ARCHMEROS_SCREENSAVER_LOCK:-/tmp/archmeros-screensaver.pid}"
playlist_path="/tmp/archmeros-screensaver-playlist.m3u"
wallpaper_dir="${repo_root}/config/wallpapers"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$log_path"
}

cleanup() {
  hyprctl dispatch dpms on >/dev/null 2>&1 || true
  "$HOME/.config/archmeros/scripts/archmeros-side-dpms.sh" on >/dev/null 2>&1 || true
  rm -f "$lock_path" "$playlist_path"
}

collect_images() {
  find "$wallpaper_dir" -maxdepth 2 -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
    | shuf
}

place_window() {
  local address=""
  for _ in $(seq 1 60); do
    address="$(
      hyprctl -j clients 2>/dev/null \
        | python3 -c 'import json,sys
clients=json.load(sys.stdin)
for c in clients:
    klass=(c.get("class") or "")
    title=(c.get("title") or "")
    if klass=="ArchMerOS-Screensaver" or title=="ArchMerOS Screensaver":
        print(c.get("address",""))
        break
' 2>/dev/null || true
    )"
    if [[ -n "$address" ]]; then
      hyprctl dispatch movetoworkspacesilent 1,address:"$address" >/dev/null 2>&1 || true
      hyprctl dispatch pin address:"$address" >/dev/null 2>&1 || true
      hyprctl dispatch fullscreen 1,address:"$address" >/dev/null 2>&1 || true
      break
    fi
    sleep 0.1
  done
}

trap cleanup EXIT

mkdir -p "$(dirname "$playlist_path")"
collect_images >"$playlist_path"

if [[ ! -s "$playlist_path" ]]; then
  log "window-launcher no-images"
  exit 1
fi

if ! command -v mpv >/dev/null 2>&1; then
  log "window-launcher missing-mpv"
  exit 1
fi

printf '%s\n' "$$" >"$lock_path"

log "window-launcher mpv"
mpv \
  --no-config \
  --no-audio \
  --no-osc \
  --fs \
  --force-window=yes \
  --title="ArchMerOS Screensaver" \
  --wayland-app-id=ArchMerOS-Screensaver \
  --cursor-autohide=always \
  --image-display-duration=12 \
  --loop-playlist=inf \
  --keep-open=no \
  --really-quiet \
  --shuffle \
  --playlist="$playlist_path" >>"$log_path" 2>&1 &

mpv_pid=$!
printf '%s\n' "$mpv_pid" >"$lock_path"
place_window
wait "$mpv_pid"
