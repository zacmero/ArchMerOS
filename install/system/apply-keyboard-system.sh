#!/usr/bin/env bash

set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  printf 'apply-keyboard-system: run as root\n' >&2
  exit 1
fi

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
hwdb_src="${repo_root}/install/system/etc/udev/hwdb.d/90-archmeros-zx-k22.hwdb"
hwdb_dest="/etc/udev/hwdb.d/90-archmeros-zx-k22.hwdb"

install -Dm644 "$hwdb_src" "$hwdb_dest"

systemd-hwdb update
udevadm control --reload
udevadm trigger --subsystem-match=input

printf 'archmeros keyboard hwdb applied\n'
printf 'rule: %s\n' "$hwdb_dest"
