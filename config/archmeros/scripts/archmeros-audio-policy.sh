#!/usr/bin/env bash

set -euo pipefail

wait_for_audio() {
  for _ in $(seq 1 40); do
    if pactl info >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.25
  done
  return 1
}

wait_for_audio || exit 0

default_sink="alsa_output.usb-Yamaha_Corporation_Steinberg_UR44-01.pro-output-0"
default_source="alsa_input.usb-Yamaha_Corporation_Steinberg_UR44-01.pro-input-0"

find_wpctl_id() {
  local section="$1"
  wpctl status 2>/dev/null | awk -v target="$section" '
    /├─ Sinks:/   { section = "sink"; next }
    /├─ Sources:/ { section = "source"; next }
    /├─ Filters:/ { section = ""; next }
    /Steinberg UR44 Pro/ && section == target {
      if (match($0, /[0-9]+\./)) {
        id = substr($0, RSTART, RLENGTH - 1)
        print id
        exit
      }
    }
  '
}

pactl set-card-profile alsa_card.pci-0000_01_00.1 off >/dev/null 2>&1 || true
pactl set-card-profile alsa_card.pci-0000_00_03.0 off >/dev/null 2>&1 || true
pactl set-card-profile alsa_card.pci-0000_00_1b.0 off >/dev/null 2>&1 || true
pactl set-card-profile alsa_card.usb-Yamaha_Corporation_Steinberg_UR44-01 pro-audio >/dev/null 2>&1 || true

sleep 0.4

pactl set-default-sink "$default_sink" >/dev/null 2>&1 || true
pactl set-default-source "$default_source" >/dev/null 2>&1 || true

source_id="$(find_wpctl_id source || true)"

if [[ -n "${source_id}" ]]; then
  wpctl set-default "${source_id}" >/dev/null 2>&1 || true
fi
