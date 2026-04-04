#!/usr/bin/env bash

set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  printf 'apply-kernel-install-system: run as root\n' >&2
  exit 1
fi

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
kernel_install_target="/etc/kernel/install.conf"

install -Dm644 \
  "${repo_root}/install/system/etc/kernel/install.conf" \
  "${kernel_install_target}"

printf 'archmeros kernel-install profile applied\n'
printf 'kernel-install: %s\n' "${kernel_install_target}"
