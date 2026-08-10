#!/usr/bin/env bash

set -euo pipefail

notify() {
  command -v notify-send >/dev/null 2>&1 && notify-send --app-name=ArchMerOS "$1" "$2" || true
}

mode="${1:-}"
shift || true

[[ "$#" -gt 0 ]] || exit 0

case "$mode" in
  gui)
    if command -v winzip >/dev/null 2>&1; then
      nohup winzip "$@" >/dev/null 2>&1 &
    elif command -v file-roller >/dev/null 2>&1; then
      nohup file-roller --add "$@" >/dev/null 2>&1 &
    else
      notify "Compression unavailable" "Install WinZip or file-roller."
      exit 1
    fi
    ;;
  here)
    command -v 7z >/dev/null 2>&1 || {
      notify "Compression unavailable" "Install the 7zip package."
      exit 1
    }

    first="$(realpath -- "$1")"
    target_dir="$(dirname -- "$first")"
    selected=()

    for path in "$@"; do
      absolute="$(realpath -- "$path")"
      [[ "$(dirname -- "$absolute")" == "$target_dir" ]] || {
        notify "Compression cancelled" "Select items from one folder."
        exit 1
      }
      selected+=("$(basename -- "$absolute")")
    done

    if [[ "${#selected[@]}" -eq 1 ]]; then
      archive_base="${selected[0]%.*}"
      [[ -n "$archive_base" ]] || archive_base=archive
    else
      archive_base=archive
    fi

    archive="$target_dir/$archive_base.zip"
    suffix=1
    while [[ -e "$archive" ]]; do
      archive="$target_dir/${archive_base}-${suffix}.zip"
      ((suffix += 1))
    done

    if ! (cd "$target_dir" && 7z a -tzip -mx=1 -mmt=on "$archive" -- "${selected[@]}" >/dev/null); then
      rm -f -- "$archive"
      notify "Compression failed" "Could not create $(basename -- "$archive")."
      exit 1
    fi

    notify "Compression complete" "Created $(basename -- "$archive")."
    ;;
  *)
    printf 'usage: %s {gui|here} FILE...\n' "$0" >&2
    exit 2
    ;;
esac
