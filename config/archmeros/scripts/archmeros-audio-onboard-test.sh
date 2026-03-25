#!/usr/bin/env bash

set -euo pipefail

printf 'ArchMerOS audio test: switching to onboard analog stereo\n'

wait_for_audio() {
  for _ in $(seq 1 40); do
    if pactl info >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.25
  done
  return 1
}

systemctl --user restart wireplumber pipewire pipewire-pulse >/dev/null 2>&1 || true

wait_for_audio || exit 0

printf 'Audio server is up\n'
printf 'Before:\n'
pactl info | sed -n 's/^Default Sink: /  sink: /p; s/^Default Source: /  source: /p'

onboard_card="alsa_card.pci-0000_00_1b.0"
onboard_duplex="output:analog-stereo+input:analog-stereo"
onboard_output_only="output:analog-stereo"
onboard_sink="alsa_output.pci-0000_00_1b.0.analog-stereo"
onboard_source="alsa_input.pci-0000_00_1b.0.analog-stereo"
ur44_card="alsa_card.usb-Yamaha_Corporation_Steinberg_UR44-01"

pactl set-card-profile alsa_card.pci-0000_01_00.1 off >/dev/null 2>&1 || true
pactl set-card-profile alsa_card.pci-0000_00_03.0 off >/dev/null 2>&1 || true
pactl set-card-profile "$ur44_card" off >/dev/null 2>&1 || true
printf 'UR44 disabled\n'

if pactl set-card-profile "$onboard_card" "$onboard_duplex" >/dev/null 2>&1; then
  printf 'Onboard profile: %s\n' "$onboard_duplex"
elif pactl set-card-profile "$onboard_card" "$onboard_output_only" >/dev/null 2>&1; then
  printf 'Onboard profile: %s\n' "$onboard_output_only"
else
  printf 'Onboard profile switch failed\n' >&2
fi

onboard_sink="$(pactl list short sinks | awk '/pci-0000_00_1b\\.0/ {print $2; exit}')"
onboard_source="$(pactl list short sources | awk '/pci-0000_00_1b\\.0/ {print $2; exit}')"
if [[ -z "${onboard_sink}" ]]; then
  onboard_sink="alsa_output.pci-0000_00_1b.0.analog-stereo"
fi
if [[ -z "${onboard_source}" ]]; then
  onboard_source="alsa_input.pci-0000_00_1b.0.analog-stereo"
fi

sleep 0.4

if pactl set-default-sink "$onboard_sink" >/dev/null 2>&1; then
  printf 'Default sink set to %s\n' "$onboard_sink"
else
  printf 'Could not set default sink to %s\n' "$onboard_sink" >&2
fi

if pactl set-default-source "$onboard_source" >/dev/null 2>&1; then
  printf 'Default source set to %s\n' "$onboard_source"
else
  printf 'Could not set default source to %s\n' "$onboard_source" >&2
fi

printf 'After:\n'
pactl info | sed -n 's/^Default Sink: /  sink: /p; s/^Default Source: /  source: /p'
