#!/usr/bin/env bash

set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  printf 'apply-build-system: run as root\n' >&2
  exit 1
fi

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
profile_src="${repo_root}/install/system/etc/profile.d/90-archmeros-build.sh"
profile_dest="/etc/profile.d/90-archmeros-build.sh"
sudoers_src="${repo_root}/install/system/etc/sudoers.d/90-archmeros-build-env"
sudoers_dest="/etc/sudoers.d/90-archmeros-build-env"

install -Dm644 "${profile_src}" "${profile_dest}"
install -Dm440 "${sudoers_src}" "${sudoers_dest}"

if command -v visudo >/dev/null 2>&1; then
  visudo -cf "${sudoers_dest}"
fi

printf 'archmeros build throttle applied\n'
printf 'profile:  %s\n' "${profile_dest}"
printf 'sudoers:  %s\n' "${sudoers_dest}"
