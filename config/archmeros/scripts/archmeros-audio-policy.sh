#!/usr/bin/env bash

set -euo pipefail

exec 9>"${XDG_RUNTIME_DIR:?}/archmeros-audio-policy.lock"
flock 9

find_ur44_card() {
  local card
  for _ in $(seq 1 40); do
    card="$(pactl list short cards 2>/dev/null |
      awk '$2 ~ /^alsa_card\.usb-Yamaha_Corporation_Steinberg_UR44-[0-9]+$/ { print $2; exit }')" || true
    if [[ -n "$card" ]]; then
      printf '%s\n' "$card"
      return 0
    fi
    sleep 0.25
  done
  return 1
}

if ! ur44_card="$(find_ur44_card)"; then
  printf 'UR44 unavailable. The audio policy will run again when it connects.\n'
  exit 0
fi
ur44_device="${ur44_card#alsa_card.}"
default_sink="alsa_output.${ur44_device}.pro-output-0"
ur44_source="alsa_input.${ur44_device}.pro-input-0"
mic_source="archmeros_ur44_mic"

pactl set-card-profile alsa_card.pci-0000_01_00.1 off >/dev/null 2>&1 || true
pactl set-card-profile alsa_card.pci-0000_00_03.0 off >/dev/null 2>&1 || true
pactl set-card-profile alsa_card.pci-0000_00_1b.0 off >/dev/null 2>&1 || true
pactl set-card-profile "$ur44_card" pro-audio >/dev/null 2>&1 || true

wait_for_source() {
  local source="$1"
  for _ in $(seq 1 40); do
    if pactl get-source-mute "$source" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.25
  done
  printf 'Audio source did not appear: %s\n' "$source" >&2
  return 1
}

wait_for_source "$ur44_source"
pactl set-default-sink "$default_sink" >/dev/null 2>&1 || true

# The mic uses jack 4 (AUX3). Voice apps requesting mono or stereo otherwise
# receive the first two channels from the multichannel Pro Audio source.
if ! pactl get-source-mute "$mic_source" >/dev/null 2>&1; then
  pactl load-module module-remap-source master="$ur44_source" \
    source_name="$mic_source" channels=1 master_channel_map=aux3 channel_map=mono remix=no \
    "source_properties='device.description=\"Steinberg UR44 Mic (Input 4)\"'" >/dev/null
fi

wait_for_source "$mic_source"
pactl set-default-source "$mic_source"
