#!/usr/bin/env bash

set -euo pipefail

log() {
  printf 'archmeros-post-update-check: %s\n' "$*"
}

warn() {
  printf 'archmeros-post-update-check: WARNING: %s\n' "$*" >&2
}

ensure_greeter_seat_membership() {
  if ! id greeter >/dev/null 2>&1; then
    return 0
  fi

  if ! getent group seat >/dev/null 2>&1; then
    return 0
  fi

  if id -nG greeter | tr ' ' '\n' | grep -qx 'seat'; then
    return 0
  fi

  usermod -aG seat greeter
  log 'added greeter to seat group'
}

check_nvidia_modules() {
  local missing=0
  local kver
  local modules_dir

  if ! pacman -Qq nvidia-580xx-dkms >/dev/null 2>&1; then
    return 0
  fi

  for modules_dir in /usr/lib/modules/*; do
    [[ -d "${modules_dir}" ]] || continue
    [[ -f "${modules_dir}/pkgbase" ]] || continue
    [[ -f "${modules_dir}/vmlinuz" ]] || continue

    kver="${modules_dir##*/}"
    if ! modinfo -k "${kver}" nvidia >/dev/null 2>&1; then
      warn "missing NVIDIA DKMS module for installed kernel ${kver}; do not reboot until nvidia-580xx-dkms is rebuilt for that kernel"
      missing=1
    fi
  done

  return "${missing}"
}

main() {
  local failed=0

  ensure_greeter_seat_membership

  if ! check_nvidia_modules; then
    failed=1
  fi

  if [[ "${failed}" -ne 0 ]]; then
    warn 'graphics update safety check failed'
    exit 1
  fi

  log 'graphics update safety check passed'
}

main "$@"
