#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

install -Dm644 \
  "$repo_root/install/system/etc/modprobe.d/archmeros-audio.conf" \
  /etc/modprobe.d/archmeros-audio.conf

if [[ -w /sys/module/snd_hda_intel/parameters/power_save ]]; then
  printf '0' > /sys/module/snd_hda_intel/parameters/power_save || true
fi

if [[ -w /sys/module/snd_hda_intel/parameters/power_save_controller ]]; then
  printf 'N' > /sys/module/snd_hda_intel/parameters/power_save_controller || true
fi
