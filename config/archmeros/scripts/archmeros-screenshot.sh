#!/usr/bin/env bash

set -euo pipefail

mode="${1:-region}"
target_dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$target_dir"

stamp="$(date +%Y%m%d-%H%M%S)"
output_file="${target_dir}/archmeros-${stamp}.png"

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

wl-copy < "$output_file"
notify-send "ArchMerOS Screenshot" "$(basename "$output_file") copied to clipboard"
printf '%s\n' "$output_file"
