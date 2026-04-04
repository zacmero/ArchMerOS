#!/usr/bin/env bash

set -euo pipefail

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
repo_root="$(cd -- "$(dirname -- "$script_path")/../../.." && pwd)"
log_path="/tmp/archmeros-screensaver.log"
mpv_log_path="/tmp/archmeros-screensaver-mpv.log"
lock_path="${ARCHMEROS_SCREENSAVER_LOCK:-/tmp/archmeros-screensaver.pid}"
stamp_path="/tmp/archmeros-screensaver.started"
playlist_path="/tmp/archmeros-screensaver-playlist.m3u"
mpv_input_conf_path="/tmp/archmeros-screensaver-mpv-input.conf"
wallpaper_dir="${repo_root}/config/wallpapers"
night_drive_script="${HOME}/.config/archmeros/scripts/archmeros-night-drive.py"
config_path="${ARCHMEROS_SCREENSAVER_CONFIG:-${repo_root}/config/greetd/sysc-greet/share/ascii_configs/screensaver.conf}"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$log_path"
}

read_setting() {
  local key="$1"
  local default_value="$2"
  if [[ -f "$config_path" ]]; then
    local value
    value="$(sed -n "s/^${key}=//p" "$config_path" | head -n 1 | tr -d '\r')"
    if [[ -n "$value" ]]; then
      printf '%s\n' "$value"
      return 0
    fi
  fi
  printf '%s\n' "$default_value"
}

mode="${ARCHMEROS_SCREENSAVER_MODE:-$(read_setting mode nightdrive)}"
speed="${ARCHMEROS_SCREENSAVER_SPEED:-$(read_setting animation_speed 2)}"

cleanup() {
  log "window-cleanup"
  hyprctl dispatch dpms on >/dev/null 2>&1 || true
  "$HOME/.config/archmeros/scripts/archmeros-side-dpms.sh" on >/dev/null 2>&1 || true
  rm -f "$lock_path" "$stamp_path" "$playlist_path" "$mpv_input_conf_path"
}

collect_images() {
  find "$wallpaper_dir" -maxdepth 2 -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) \
    | shuf
}

normalize_speed() {
  local raw="${1:-2}"
  case "$raw" in
    ''|*[!0-9]*)
      printf '2\n'
      ;;
    *)
      printf '%s\n' "$raw"
      ;;
  esac
}

launch_night_drive() {
  local fps speed_value
  speed_value="$(normalize_speed "$speed")"
  fps=$(( 6 + speed_value * 2 ))

  if ! command -v wezterm >/dev/null 2>&1; then
    log "window-launcher missing-wezterm"
    exit 1
  fi

  log "window-launcher night-drive fps=$fps"
  date +%s >"$stamp_path"
  wezterm \
    --config 'enable_tab_bar=false' \
    --config 'use_fancy_tab_bar=false' \
    --config 'window_decorations="NONE"' \
    start \
    --always-new-process \
    --class ArchMerOS-Screensaver \
    --cwd "$HOME" \
    python3 "$night_drive_script" --fps "$fps" --screensaver >>"$log_path" 2>&1 &

  local night_pid=$!
  printf '%s\n' "$night_pid" >"$lock_path"
  place_window
  wait "$night_pid"
}

launch_slideshow() {
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

  local duration speed_value
  speed_value="$(normalize_speed "$speed")"
  duration=$(( 18 - speed_value ))
  if (( duration < 6 )); then
    duration=6
  fi

  log "window-launcher mpv duration=$duration"
  date +%s >"$stamp_path"
  cat >"$mpv_input_conf_path" <<'EOF'
ENTER quit
ESC quit
SPACE quit
MBTN_LEFT quit
MBTN_RIGHT quit
q quit
EOF
  mpv \
    --no-config \
    --no-audio \
    --no-osc \
    --fs \
    --force-window=yes \
    --title="ArchMerOS Screensaver" \
    --wayland-app-id=ArchMerOS-Screensaver \
    --cursor-autohide=always \
    --input-default-bindings=no \
    --input-conf="$mpv_input_conf_path" \
    --image-display-duration="$duration" \
    --loop-playlist=inf \
    --keep-open=no \
    --msg-level=all=info \
    --log-file="$mpv_log_path" \
    --shuffle \
    --playlist="$playlist_path" >>"$log_path" 2>&1 &

  local mpv_pid=$!
  printf '%s\n' "$mpv_pid" >"$lock_path"
  place_window
  wait "$mpv_pid"
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
printf '%s\n' "$$" >"$lock_path"
log "window-entry mode=$mode speed=$speed config=$config_path"

case "$mode" in
  nightdrive|night-drive|cyberpunk)
    launch_night_drive
    ;;
  slideshow|wallpaper|wallpapers)
    launch_slideshow
    ;;
  *)
    log "window-launcher unknown-mode=$mode fallback=slideshow"
    launch_slideshow
    ;;
esac
