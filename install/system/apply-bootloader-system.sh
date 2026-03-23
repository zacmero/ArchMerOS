#!/usr/bin/env bash

set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  printf 'apply-bootloader-system: run as root\n' >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
theme_source_dir="${repo_root}/config/grub/themes/archmeros-80s"
theme_target_dir="/boot/grub/themes/archmeros-80s"
grub_default="/etc/default/grub"
grub_custom="/etc/grub.d/40_custom"
grub_cfg="/boot/grub/grub.cfg"
backup_root="/boot/grub/archmeros-backups/$(date +%Y%m%d-%H%M%S)"

mkdir -p "${backup_root}"
mkdir -p "${theme_target_dir}"

cp -a "${grub_default}" "${backup_root}/grub.default.bak"
cp -a "${grub_custom}" "${backup_root}/40_custom.bak" 2>/dev/null || true
cp -a "${grub_cfg}" "${backup_root}/grub.cfg.bak" 2>/dev/null || true

install -m 0644 "${theme_source_dir}/theme.txt" "${theme_target_dir}/theme.txt"

mono_font="$(fc-match -f '%{file}\n' 'CaskaydiaCove Nerd Font Mono' | head -n 1)"
if [[ -z "${mono_font:-}" || ! -f "${mono_font}" ]]; then
  printf 'apply-bootloader-system: could not find CaskaydiaCove Nerd Font Mono via fontconfig\n' >&2
  exit 1
fi

grub-mkfont -s 14 -o "${theme_target_dir}/CaskaydiaCoveNerdFontMono14.pf2" "${mono_font}"
grub-mkfont -s 16 -o "${theme_target_dir}/CaskaydiaCoveNerdFontMono16.pf2" "${mono_font}"
grub-mkfont -s 18 -o "${theme_target_dir}/CaskaydiaCoveNerdFontMono18.pf2" "${mono_font}"

root_uuid="$(findmnt -no UUID /)"
boot_has_intel_ucode=0
[[ -f /boot/intel-ucode.img ]] && boot_has_intel_ucode=1

quiet_args="usbcore.autosuspend=-1 quiet loglevel=3 systemd.show_status=false vt.global_cursor_default=0"
safe_args="usbcore.autosuspend=-1 systemd.show_status=true loglevel=4"

{
  printf '#!/bin/sh\n'
  printf 'exec tail -n +3 $0\n'
  printf '\n'
  printf "menuentry 'ArchMerOS' --hotkey=a {\n"
  printf "  search --no-floppy --fs-uuid --set=root %s\n" "${root_uuid}"
  printf "  linux /boot/vmlinuz-linux root=UUID=%s rw %s\n" "${root_uuid}" "${quiet_args}"
  if [[ "${boot_has_intel_ucode}" -eq 1 ]]; then
    printf "  initrd /boot/intel-ucode.img /boot/initramfs-linux.img\n"
  else
    printf "  initrd /boot/initramfs-linux.img\n"
  fi
  printf "}\n\n"
  printf "menuentry 'ArchMerOS LTS' --hotkey=l {\n"
  printf "  search --no-floppy --fs-uuid --set=root %s\n" "${root_uuid}"
  printf "  linux /boot/vmlinuz-linux-lts root=UUID=%s rw %s\n" "${root_uuid}" "${quiet_args}"
  if [[ "${boot_has_intel_ucode}" -eq 1 ]]; then
    printf "  initrd /boot/intel-ucode.img /boot/initramfs-linux-lts.img\n"
  else
    printf "  initrd /boot/initramfs-linux-lts.img\n"
  fi
  printf "}\n\n"
  printf "menuentry 'ArchMerOS Safe Verbose' --hotkey=s {\n"
  printf "  search --no-floppy --fs-uuid --set=root %s\n" "${root_uuid}"
  printf "  linux /boot/vmlinuz-linux root=UUID=%s rw %s\n" "${root_uuid}" "${safe_args}"
  if [[ "${boot_has_intel_ucode}" -eq 1 ]]; then
    printf "  initrd /boot/intel-ucode.img /boot/initramfs-linux.img\n"
  else
    printf "  initrd /boot/initramfs-linux.img\n"
  fi
  printf "}\n\n"
  printf "menuentry 'ArchMerOS LTS Safe Verbose' --hotkey=v {\n"
  printf "  search --no-floppy --fs-uuid --set=root %s\n" "${root_uuid}"
  printf "  linux /boot/vmlinuz-linux-lts root=UUID=%s rw %s\n" "${root_uuid}" "${safe_args}"
  if [[ "${boot_has_intel_ucode}" -eq 1 ]]; then
    printf "  initrd /boot/intel-ucode.img /boot/initramfs-linux-lts.img\n"
  else
    printf "  initrd /boot/initramfs-linux-lts.img\n"
  fi
  printf "}\n"
} > "${grub_custom}"

chmod 0755 "${grub_custom}"

python3 - <<'PY' "${grub_default}" "${theme_target_dir}/theme.txt"
import re
import sys

path, theme = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

replacements = {
    r"^GRUB_DEFAULT=.*$": "GRUB_DEFAULT=saved",
    r"^GRUB_DISTRIBUTOR=.*$": "GRUB_DISTRIBUTOR='ArchMerOS'",
    r"^GRUB_TIMEOUT=.*$": "GRUB_TIMEOUT='4'",
    r"^GRUB_TIMEOUT_STYLE=.*$": "GRUB_TIMEOUT_STYLE=hidden",
    r"^GRUB_CMDLINE_LINUX_DEFAULT=.*$": "GRUB_CMDLINE_LINUX_DEFAULT='usbcore.autosuspend=-1 quiet loglevel=3 systemd.show_status=false vt.global_cursor_default=0'",
    r"^GRUB_BACKGROUND=.*$": "#GRUB_BACKGROUND='/usr/share/endeavouros/splash.png'",
    r"^#?GRUB_THEME=.*$": f"GRUB_THEME='{theme}'",
}

for pattern, repl in replacements.items():
    text, count = re.subn(pattern, repl, text, flags=re.MULTILINE)
    if count == 0 and not pattern.startswith("^#?GRUB_THEME"):
        text += "\n" + repl + "\n"

if "GRUB_THEME=" not in text:
    text += f"\nGRUB_THEME='{theme}'\n"

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
PY

grub-mkconfig -o "${grub_cfg}"

printf 'archmeros bootloader applied\n'
printf 'backup: %s\n' "${backup_root}"
printf 'theme: %s\n' "${theme_target_dir}/theme.txt"
printf 'entries: %s\n' "${grub_custom}"
printf 'one-time test: grub-reboot "ArchMerOS" && reboot\n'
