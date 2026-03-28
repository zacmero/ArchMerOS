#!/usr/bin/env bash

set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  printf 'apply-nvidia-system: run as root\n' >&2
  exit 1
fi

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
modprobe_target="/etc/modprobe.d/archmeros-nvidia.conf"
dracut_target="/etc/dracut.conf.d/archmeros-nvidia.conf"
grub_default="/etc/default/grub"
grub_cfg="/boot/grub/grub.cfg"
nvidia_cmdline="rd.driver.blacklist=nouveau modprobe.blacklist=nouveau nvidia_drm.modeset=1 nvidia_drm.fbdev=1"

install -Dm644 \
  "${repo_root}/install/system/etc/modprobe.d/archmeros-nvidia.conf" \
  "${modprobe_target}"
install -Dm644 \
  "${repo_root}/install/system/etc/dracut.conf.d/archmeros-nvidia.conf" \
  "${dracut_target}"

python3 - <<'PY' "${grub_default}" "${nvidia_cmdline}"
import shlex
import sys

path, additions = sys.argv[1], sys.argv[2].split()

with open(path, "r", encoding="utf-8") as handle:
    lines = handle.readlines()

found = False
for index, raw_line in enumerate(lines):
    if not raw_line.startswith("GRUB_CMDLINE_LINUX_DEFAULT="):
        continue
    key, value = raw_line.rstrip("\n").split("=", 1)
    current = value.strip().strip("'\"")
    args = shlex.split(current)
    for item in additions:
        if item not in args:
            args.append(item)
    lines[index] = f"{key}='{' '.join(args)}'\n"
    found = True
    break

if not found:
    lines.append(f"GRUB_CMDLINE_LINUX_DEFAULT='{' '.join(additions)}'\n")

with open(path, "w", encoding="utf-8") as handle:
    handle.writelines(lines)
PY

dracut --force --regenerate-all
grub-mkconfig -o "${grub_cfg}"

printf 'archmeros nvidia system profile applied\n'
printf 'modprobe: %s\n' "${modprobe_target}"
printf 'dracut:   %s\n' "${dracut_target}"
printf 'grub:     %s\n' "${grub_cfg}"
printf 'reboot:   required\n'
