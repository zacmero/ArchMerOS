#!/usr/bin/env bash

set -euo pipefail

card_index="${ARCHMEROS_AUDIO_CARD_INDEX:-0}"
playback_status="/proc/asound/card${card_index}/pcm0p/sub0/status"
playback_hw="/proc/asound/card${card_index}/pcm0p/sub0/hw_params"
capture_status="/proc/asound/card${card_index}/pcm0c/sub0/status"
capture_hw="/proc/asound/card${card_index}/pcm0c/sub0/hw_params"

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

print_file() {
  local path="$1"
  printf '## %s\n' "$path"
  if [[ -r "$path" ]]; then
    sed -n '1,80p' "$path"
  else
    printf 'unavailable\n'
  fi
  printf '\n'
}

while :; do
  clear
  printf 'ArchMerOS Audio Debug\n'
  printf 'time: %s\n\n' "$(date '+%F %T')"

  printf '== Scheduling ==\n'
  if have_cmd ps; then
    ps -eLo pid,tid,cls,rtprio,pri,nice,comm \
      | awk '/pipewire|wireplumber/ { print }'
  else
    printf 'ps unavailable\n'
  fi
  printf '\n'

  printf '== PipeWire ==\n'
  if have_cmd pw-top; then
    pw-top -b -n 1 2>/dev/null | sed -n '1,14p' || printf 'pw-top unavailable\n'
  else
    printf 'pw-top unavailable\n'
  fi
  printf '\n'

  printf '== Playback ==\n'
  print_file "$playback_status"
  print_file "$playback_hw"

  printf '== Capture ==\n'
  print_file "$capture_status"
  print_file "$capture_hw"

  printf 'Ctrl+C to exit\n'
  sleep 1
done
