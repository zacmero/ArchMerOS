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
  disown || true
  exit 0
fi

exec "$browser" \
  --ozone-platform-hint=auto \
  --class="archmeros-${app_id}" \
  --name="$name" \
  --user-data-dir="$profile_root" \
  "${extra_args[@]}" \
  --app="$url"
