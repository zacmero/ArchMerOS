#!/usr/bin/env bash

set -euo pipefail

script_path="$(readlink -f -- "${BASH_SOURCE[0]}")"
script_dir="$(cd -- "$(dirname -- "$script_path")" && pwd)"
template_root="${script_dir}/../../firefox/profiles/youtube-music"
profile_root="${XDG_DATA_HOME:-$HOME/.local/share}/archmeros/firefox/youtube-music"
chrome_root="${profile_root}/chrome"
workspace_id="9"
target_monitor="DP-2"

mkdir -p "$chrome_root"

sync_file() {
  local src="$1"
  local dest="$2"
  if [[ ! -e "$dest" ]] || ! cmp -s "$src" "$dest" 2>/dev/null; then
    cp -f "$src" "$dest" >/dev/null 2>&1 || true
    chmod 0644 "$dest" >/dev/null 2>&1 || true
  fi
}

clear_broken_session_state() {
  pkill -f "$profile_root" >/dev/null 2>&1 || true
  rm -f "${profile_root}/.parentlock" \
        "${profile_root}/lock" \
        "${profile_root}/Telemetry.FailedProfileLocks.txt" \
        "${profile_root}"/sessionstore*.jsonlz4 \
        "${profile_root}"/store.json.mozlz4 \
        "${profile_root}"/sessionCheckpoints.json >/dev/null 2>&1 || true
  rm -f "${profile_root}"/sessionstore-backups/* >/dev/null 2>&1 || true
  sleep 1
}

sync_file "${template_root}/user.js" "${profile_root}/user.js"
sync_file "${template_root}/chrome/userChrome.css" "${chrome_root}/userChrome.css"
sync_file "${template_root}/chrome/userContent.css" "${chrome_root}/userContent.css"

if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  hyprctl dispatch moveworkspacetomonitor "$workspace_id" "$target_monitor" >/dev/null 2>&1 || true
  youtube_music_window="$(
    hyprctl clients -j 2>/dev/null \
      | jq -r '
          map(select(
            ((.class // "" | ascii_downcase) == "firefox" or (.initialClass // "" | ascii_downcase) == "firefox")
            and (
              (.title // "" | ascii_downcase | contains("youtube music"))
              or (.initialTitle // "" | ascii_downcase | contains("youtube music"))
              or (.title // "" | ascii_downcase | contains("music.youtube.com"))
              or (.initialTitle // "" | ascii_downcase | contains("music.youtube.com"))
            )
          ))
          | first
          | if . == null then empty else "\(.workspace.id)\t\(.address)" end
        ' 2>/dev/null || true
  )"

  if [[ -n "${youtube_music_window:-}" ]]; then
    existing_workspace="${youtube_music_window%%$'\t'*}"
    address="${youtube_music_window#*$'\t'}"
    if [[ -n "${existing_workspace:-}" && -n "${address:-}" ]]; then
      hyprctl dispatch workspace "${existing_workspace}" >/dev/null 2>&1 || true
      hyprctl dispatch focuswindow "address:${address}" >/dev/null 2>&1 || true
      exit 0
    fi
  fi

  broken_windows="$(
    hyprctl clients -j 2>/dev/null \
      | jq -r --arg workspace "$workspace_id" '
          map(select(
            ((.class // "" | ascii_downcase) == "firefox" or (.initialClass // "" | ascii_downcase) == "firefox")
            and ((.workspace.id | tostring) == $workspace)
            and (
              (.title // "" | ascii_downcase | contains("restore session"))
              or (.title // "" | ascii_downcase | contains("close firefox"))
              or (.initialTitle // "" | ascii_downcase | contains("restore session"))
              or (.initialTitle // "" | ascii_downcase | contains("close firefox"))
            )
          ))
          | length
        ' 2>/dev/null || true
  )"

  if [[ "${broken_windows:-0}" != "0" ]]; then
    clear_broken_session_state
  fi
fi

if [[ -e "${profile_root}/.parentlock" || -L "${profile_root}/lock" ]]; then
  clear_broken_session_state
fi

nohup env MOZ_ENABLE_WAYLAND=1 firefox \
  --new-instance \
  --profile "${profile_root}" \
  --new-window "https://music.youtube.com/" >/tmp/archmeros-youtube-music.log 2>&1 &

if command -v hyprctl >/dev/null 2>&1; then
  "$HOME/.config/archmeros/scripts/archmeros-place-window.py" \
    "youtube-music" \
    "YouTube Music" \
    "$workspace_id" >/tmp/archmeros-place-youtube-music.log 2>&1 &
fi

disown || true
