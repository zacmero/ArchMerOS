#!/usr/bin/env bash

set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  printf 'apply-hibernate-system: run as root\n' >&2
  exit 1
fi

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
dracut_target="/etc/dracut.conf.d/archmeros-hibernate.conf"
grub_default="/etc/default/grub"
grub_cfg="/boot/grub/grub.cfg"

detect_resume_uuid() {
  local swap_source swap_uuid

  if [[ -r /proc/swaps ]]; then
    swap_source="$(
      awk 'NR > 1 && $1 ~ "^/dev/" && $1 !~ /^\/dev\/zram/ { print $1; exit }' /proc/swaps
    )"
    if [[ -n "${swap_source:-}" ]]; then
      swap_uuid="$(blkid -s UUID -o value "${swap_source}" 2>/dev/null || true)"
      if [[ -n "${swap_uuid:-}" ]]; then
        printf '%s\n' "${swap_uuid}"
        return 0
      fi
    fi
  fi

  if [[ -r /etc/fstab ]]; then
    swap_source="$(
      awk '$3 == "swap" && $1 ~ /^UUID=/ { sub(/^UUID=/, "", $1); print $1; exit }' /etc/fstab
    )"
    if [[ -n "${swap_source:-}" ]]; then
      printf '%s\n' "${swap_source}"
      return 0
    fi

    swap_source="$(
      awk '$3 == "swap" && $1 ~ "^/dev/" { print $1; exit }' /etc/fstab
    )"
    if [[ -n "${swap_source:-}" ]]; then
      swap_uuid="$(blkid -s UUID -o value "${swap_source}" 2>/dev/null || true)"
      if [[ -n "${swap_uuid:-}" ]]; then
        printf '%s\n' "${swap_uuid}"
        return 0
      fi
    fi
  fi

  return 1
}

resume_uuid="$(detect_resume_uuid || true)"
if [[ -z "${resume_uuid:-}" ]]; then
  printf 'apply-hibernate-system: no swap UUID found, skipping resume configuration\n'
  exit 0
fi

install -Dm644 \
  "${repo_root}/install/system/etc/dracut.conf.d/archmeros-hibernate.conf" \
  "${dracut_target}"

python3 - <<'PY' "${grub_default}" "${resume_uuid}"
import shlex
import sys

path, resume_uuid = sys.argv[1], sys.argv[2]
resume_arg = f"resume=UUID={resume_uuid}"

with open(path, "r", encoding="utf-8") as handle:
    lines = handle.readlines()

found = False
for index, raw_line in enumerate(lines):
    if not raw_line.startswith("GRUB_CMDLINE_LINUX_DEFAULT="):
        continue
    key, value = raw_line.rstrip("\n").split("=", 1)
    current = value.strip().strip("'\"")
    args = shlex.split(current)
    filtered = [item for item in args if not item.startswith("resume=")]
    if resume_arg not in filtered:
        filtered.append(resume_arg)
    lines[index] = f"{key}='{' '.join(filtered)}'\n"
    found = True
    break

if not found:
    lines.append(f"GRUB_CMDLINE_LINUX_DEFAULT='{resume_arg}'\n")

with open(path, "w", encoding="utf-8") as handle:
    handle.writelines(lines)
PY

for modules_dir in /usr/lib/modules/*; do
  [[ -d "${modules_dir}" ]] || continue
  [[ -f "${modules_dir}/pkgbase" ]] || continue
  [[ -f "${modules_dir}/vmlinuz" ]] || continue

  kver="${modules_dir##*/}"
  pkgbase="$(<"${modules_dir}/pkgbase")"

  install -Dm644 "${modules_dir}/vmlinuz" "/boot/vmlinuz-${pkgbase}"

  printf 'dracut: building hostonly initramfs for %s (%s)\n' "${pkgbase}" "${kver}"
  dracut --force --hostonly --no-hostonly-cmdline "/boot/initramfs-${pkgbase}.img" "${kver}"

  printf 'dracut: building fallback initramfs for %s (%s)\n' "${pkgbase}" "${kver}"
  dracut --force --no-hostonly "/boot/initramfs-${pkgbase}-fallback.img" "${kver}"
done

grub-mkconfig -o "${grub_cfg}"

printf 'archmeros hibernate profile applied\n'
printf 'resume:   UUID=%s\n' "${resume_uuid}"
printf 'dracut:   %s\n' "${dracut_target}"
printf 'grub:     %s\n' "${grub_cfg}"
printf 'reboot:   required\n'
