#!/usr/bin/env bash

set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  printf 'apply-bootloader-shared-esp-system: run as root\n' >&2
  exit 1
fi

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
efi_mount="/boot/efi"
timestamp="$(date +%Y%m%d-%H%M%S)"
backup_root="/boot/grub/archmeros-backups/${timestamp}/shared-esp"

detect_esp_device() {
  if [[ -n "${ARCHMEROS_SHARED_ESP_DEVICE:-}" ]]; then
    printf '%s\n' "${ARCHMEROS_SHARED_ESP_DEVICE}"
    return 0
  fi

  if [[ -n "${ARCHMEROS_SHARED_ESP_UUID:-}" ]]; then
    blkid -U "${ARCHMEROS_SHARED_ESP_UUID}"
    return 0
  fi

  if blkid -t PARTLABEL='EFI system partition' -o device 2>/dev/null | head -n 1 | grep -q .; then
    blkid -t PARTLABEL='EFI system partition' -o device 2>/dev/null | head -n 1
    return 0
  fi

  lsblk -nrpo NAME,FSTYPE | awk '$2 == "vfat" { print $1; exit }'
}

esp_device="$(detect_esp_device)"
if [[ -z "${esp_device:-}" || ! -b "${esp_device}" ]]; then
  printf 'apply-bootloader-shared-esp-system: could not determine EFI partition\n' >&2
  exit 1
fi

esp_uuid="$(blkid -s UUID -o value "${esp_device}")"
if [[ -z "${esp_uuid:-}" ]]; then
  printf 'apply-bootloader-shared-esp-system: could not read EFI UUID from %s\n' "${esp_device}" >&2
  exit 1
fi

mkdir -p "${backup_root}"
mkdir -p "${efi_mount}"

if mountpoint -q "${efi_mount}"; then
  mounted_here="$(findmnt -no SOURCE "${efi_mount}")"
  if [[ "${mounted_here}" != "${esp_device}" ]]; then
    printf 'apply-bootloader-shared-esp-system: %s already mounted from %s, expected %s\n' "${efi_mount}" "${mounted_here}" "${esp_device}" >&2
    exit 1
  fi
else
  mount "${esp_device}" "${efi_mount}"
fi

cp -a "${efi_mount}/." "${backup_root}/esp-backup"

if grep -Eq '^[[:space:]]*UUID=.*[[:space:]]+/boot/efi[[:space:]]+vfat' /etc/fstab; then
  python3 - <<'PY' "/etc/fstab" "${esp_uuid}"
import re
import sys

path, uuid = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

text = re.sub(
    r'^[ \t]*UUID=[^\s]+[ \t]+/boot/efi[ \t]+vfat[ \t]+.*$',
    f'UUID={uuid} /boot/efi vfat umask=0077,shortname=winnt 0 2',
    text,
    flags=re.MULTILINE,
)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)
PY
else
  printf '\nUUID=%s /boot/efi vfat umask=0077,shortname=winnt 0 2\n' "${esp_uuid}" >> /etc/fstab
fi

bash "${repo_root}/install/system/apply-bootloader-system.sh"

grub_install_args=(
  --target=x86_64-efi
  --efi-directory="${efi_mount}"
  --bootloader-id=ArchMerOS
  --recheck
)

if [[ ! -d /sys/firmware/efi ]]; then
  grub_install_args+=(--no-nvram)
fi

grub-install "${grub_install_args[@]}"

printf 'archmeros shared ESP bootloader applied\n'
printf 'efi-device: %s\n' "${esp_device}"
printf 'efi-uuid:   %s\n' "${esp_uuid}"
printf 'efi-mount:  %s\n' "${efi_mount}"
printf 'backup:     %s\n' "${backup_root}"
printf 'loader:     %s\n' "${efi_mount}/EFI/ArchMerOS/grubx64.efi"

if [[ ! -d /sys/firmware/efi ]]; then
  printf 'note: system is currently booted in BIOS/CSM mode, so no UEFI NVRAM boot entry was created\n'
  printf 'next: either add \\EFI\\ArchMerOS\\grubx64.efi as a BIOS boot option manually or boot ArchMerOS once in UEFI mode and rerun this script\n'
fi
