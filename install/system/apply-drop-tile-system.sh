#!/usr/bin/env bash
set -euo pipefail
[[ $EUID == 0 ]] || { printf 'Run with sudo.\n' >&2; exit 1; }
root="$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)"
target=/etc/udev/rules.d/70-archmeros-drop-tile.rules
if [[ -f "$target" ]]; then
  cp -a "$target" "${target}.before-repair-$(date +%Y%m%d-%H%M%S)"
fi
install -m 644 "$root/install/udev/70-archmeros-drop-tile.rules" "$target"
udevadm control --reload-rules
udevadm trigger --subsystem-match=input --action=change
udevadm settle
