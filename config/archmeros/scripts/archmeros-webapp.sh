#!/usr/bin/env bash

set -euo pipefail

app_id="${1:-}"

if [[ -z "$app_id" ]]; then
  printf 'Usage: %s <app-id>\n' "$0" >&2
  exit 1
fi

browser=""
for candidate in chromium brave-browser google-chrome-stable google-chrome chrome; do
  if command -v "$candidate" >/dev/null 2>&1; then
    browser="$candidate"
    break
  fi
done

if [[ -z "$browser" ]]; then
  printf 'No Chromium-style browser found for web apps.\n' >&2
  exit 1
fi

case "$app_id" in
  todoist)
    name="Todoist"
    url="https://todoist.com/app"
    ;;
  evernote)
    name="Evernote"
    url="https://www.evernote.com/client/web"
    ;;
  chatgpt)
    name="ChatGPT"
    url="https://chatgpt.com/"
    ;;
  gemini)
    name="Gemini"
    url="https://gemini.google.com/"
    ;;
  plex)
    name="Plex"
    url="http://127.0.0.1:32400/web"
    ;;
  youtube-music)
    name="YouTube Music"
    url="https://music.youtube.com/"
    target_workspace="9"
    ;;
  *)
    printf 'Unknown web app: %s\n' "$app_id" >&2
    exit 1
    ;;
esac

profile_root="${XDG_DATA_HOME:-$HOME/.local/share}/archmeros/webapps/${app_id}"
mkdir -p "$profile_root"

track_command=("$HOME/.config/archmeros/scripts/archmeros-webapp.sh" "$app_id")
if [[ "$app_id" == "plex" ]]; then
  track_command=("$HOME/.config/archmeros/scripts/archmeros-plex-launch.sh")
fi

python3 "$HOME/.config/archmeros/scripts/archmeros-reopen-history.py" \
  track-launch general "archmeros-${app_id}" "archmeros-${app_id}" "$browser" -- \
  "${track_command[@]}" \
  >/tmp/archmeros-reopen-track-"${app_id}".log 2>&1 || true

mode="none"
if command -v hyprctl >/dev/null 2>&1; then
  active="$(hyprctl activewindow -j 2>/dev/null || printf '{}')"
  if [[ "$active" != "{}" ]] && [[ "$(printf '%s' "$active" | jq -r '.floating // false')" == "true" ]]; then
    width="$(printf '%s' "$active" | jq -r '.size[0] // 0')"
    height="$(printf '%s' "$active" | jq -r '.size[1] // 0')"
    monitor="$(hyprctl -j monitors 2>/dev/null | jq -r '.[] | select(.focused == true) | .width, .height' | paste -sd' ' -)"
    monitor_width="$(printf '%s' "$monitor" | awk '{print $1}')"
    monitor_height="$(printf '%s' "$monitor" | awk '{print $2}')"
    if [[ -n "${monitor_width:-}" && -n "${monitor_height:-}" && "$monitor_width" != "0" && "$monitor_height" != "0" ]]; then
      if (( width * 100 / monitor_width >= 85 || height * 100 / monitor_height >= 85 )); then
        mode="full"
      else
        mode="medium"
      fi
    fi
    hyprctl dispatch alterzorder bottom >/dev/null 2>&1 || true
  fi
fi

extra_args=()

if [[ "$app_id" == "youtube-music" && -d /usr/lib/ublock-origin ]]; then
  extra_args+=(
    --disable-extensions-except=/usr/lib/ublock-origin
    --load-extension=/usr/lib/ublock-origin
  )
fi

if [[ -n "${target_workspace:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
  "$browser" \
    --ozone-platform-hint=auto \
    --class="archmeros-${app_id}" \
    --name="$name" \
    --user-data-dir="$profile_root" \
    "${extra_args[@]}" \
    --app="$url" >/tmp/archmeros-"${app_id}".log 2>&1 &
  app_pid=$!
  disown "$app_pid" || true
  ~/.config/archmeros/scripts/archmeros-place-window.py "$app_id" "$name" "$target_workspace" >/dev/null 2>&1 &
  python3 "$HOME/.config/archmeros/scripts/archmeros-promote-window.py" "^archmeros-${app_id}$" "$mode" >/tmp/archmeros-promote-${app_id}.log 2>&1 &
  disown || true
  exit 0
fi

nohup "$browser" \
  --ozone-platform-hint=auto \
  --class="archmeros-${app_id}" \
  --name="$name" \
  --user-data-dir="$profile_root" \
  "${extra_args[@]}" \
  --app="$url" >/tmp/archmeros-"${app_id}".log 2>&1 &
python3 "$HOME/.config/archmeros/scripts/archmeros-promote-window.py" "^archmeros-${app_id}$" "$mode" >/tmp/archmeros-promote-${app_id}.log 2>&1 &
disown || true
