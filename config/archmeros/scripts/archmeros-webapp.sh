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
    ;;
  *)
    printf 'Unknown web app: %s\n' "$app_id" >&2
    exit 1
    ;;
esac

profile_root="${XDG_DATA_HOME:-$HOME/.local/share}/archmeros/webapps/${app_id}"
mkdir -p "$profile_root"

exec "$browser" \
  --ozone-platform-hint=auto \
  --class="archmeros-${app_id}" \
  --name="$name" \
  --user-data-dir="$profile_root" \
  --app="$url"
