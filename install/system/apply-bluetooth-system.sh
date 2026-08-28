#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

install -Dm644 \
  "$repo_root/install/system/etc/modprobe.d/archmeros-bluetooth.conf" \
  /etc/modprobe.d/archmeros-bluetooth.conf

install -Dm644 \
  "$repo_root/install/system/etc/udev/rules.d/99-archmeros-btusb-power.rules" \
  /etc/udev/rules.d/99-archmeros-btusb-power.rules

if [[ -f /etc/bluetooth/main.conf ]]; then
  if rg -q '^#?AutoEnable=' /etc/bluetooth/main.conf; then
    sed -i 's/^#\?AutoEnable=.*/AutoEnable=true/' /etc/bluetooth/main.conf
  else
    printf '\nAutoEnable=true\n' >> /etc/bluetooth/main.conf
  fi
fi

udevadm control --reload
udevadm trigger --subsystem-match=usb

for d in /sys/bus/usb/devices/*; do
  [[ -f "$d/idVendor" && -f "$d/idProduct" ]] || continue
  vendor="$(cat "$d/idVendor")"
  product="$(cat "$d/idProduct")"
  if [[ ("$vendor" == "0a12" && "$product" == "0001") || ("$vendor" == "2357" && "$product" == "0604") ]]; then
    if [[ -w "$d/power/control" ]]; then
      printf 'on' > "$d/power/control"
    fi
  fi
done
