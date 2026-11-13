#!/usr/bin/env bash

set -euo pipefail

# One capture at a time, even if overlapping shortcuts launch together.
exec 9>"${XDG_RUNTIME_DIR:?}/archmeros-screenshot.lock"
flock -n 9 || exit 0

mode="${1:-region}"
target_dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
log_file="${XDG_RUNTIME_DIR:-/tmp}/archmeros-screenshot.log"
mkdir -p "$target_dir"

: >> "$log_file" 2>/dev/null || log_file="/tmp/archmeros-screenshot.log"

stamp="$(date +%Y%m%d-%H%M%S)"
output_file="${target_dir}/archmeros-${stamp}.png"

printf '%s mode=%s\n' "$(date '+%F %T')" "$mode" >> "$log_file" || true

case "$mode" in
  full)
    grim "$output_file"
    ;;
  region)
    geometry="$(slurp)" || exit 0
    [[ -n "$geometry" ]] || exit 0
    grim -g "$geometry" "$output_file"
    ;;
  *)
    printf 'Usage: %s {full|region}\n' "$0" >&2
    exit 1
    ;;
esac

clipboard_note="saved"
if command -v wl-copy >/dev/null 2>&1; then
  if wl-copy 9>&- < "$output_file" 2>>"$log_file"; then
    clipboard_note="copied to clipboard"
  fi
fi

notify-send "ArchMerOS Screenshot" "$(basename "$output_file") ${clipboard_note}" 2>>"$log_file" || true
printf '%s\n' "$output_file"
