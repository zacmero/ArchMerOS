#!/usr/bin/env bash

set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  printf 'apply-system: run as root\n' >&2
  exit 1
fi

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

should_apply_shared_esp() {
  if [[ -n "${ARCHMEROS_SKIP_SHARED_ESP:-}" ]]; then
    return 1
  fi

  if [[ -n "${ARCHMEROS_FORCE_SHARED_ESP:-}" ]]; then
    return 0
  fi

  if [[ ! -d /sys/firmware/efi ]]; then
    return 0
  fi

  if [[ -d /boot/efi/EFI/Microsoft ]]; then
    return 0
  fi

  if command -v efibootmgr >/dev/null 2>&1 && efibootmgr -v 2>/dev/null | grep -qi 'Windows Boot Manager'; then
    return 0
  fi

  return 1
}

should_apply_nvidia() {
  if [[ -n "${ARCHMEROS_SKIP_NVIDIA_PROFILE:-}" ]]; then
    return 1
  fi

  if [[ -n "${ARCHMEROS_FORCE_NVIDIA_PROFILE:-}" ]]; then
    return 0
  fi

  if ! command -v lspci >/dev/null 2>&1; then
    return 1
  fi

  lspci -nnk 2>/dev/null | grep -qi 'NVIDIA'
}

bash "${repo_root}/install/system/apply-audio-system.sh"
bash "${repo_root}/install/system/apply-bluetooth-system.sh"
bash "${repo_root}/install/system/apply-keyboard-system.sh"
bash "${repo_root}/install/system/apply-kernel-install-system.sh"
bash "${repo_root}/install/system/apply-monitor-system.sh"

if should_apply_shared_esp; then
  printf 'apply-system: shared ESP layout detected, applying shared-ESP bootloader path\n'
  bash "${repo_root}/install/system/apply-bootloader-shared-esp-system.sh"
else
  bash "${repo_root}/install/system/apply-bootloader-system.sh"
fi

if should_apply_nvidia; then
  printf 'apply-system: NVIDIA GPU detected, applying NVIDIA system profile\n'
  bash "${repo_root}/install/system/apply-nvidia-system.sh"
else
  printf 'apply-system: NVIDIA profile skipped; no NVIDIA GPU detected\n'
fi

bash "${repo_root}/install/system/apply-hibernate-system.sh"
bash "${repo_root}/install/system/apply-greeter-system.sh"

printf 'archmeros system defaults applied\n'
