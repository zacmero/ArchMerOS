#!/usr/bin/env bash

set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  printf 'apply-update-safety-system: run as root\n' >&2
  exit 1
fi

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
hook_target="/etc/pacman.d/hooks/95-archmeros-graphics-safety.hook"
script_target="/usr/local/bin/archmeros-post-update-check"

install -Dm755 \
  "${repo_root}/install/system/archmeros-post-update-check.sh" \
  "${script_target}"
install -Dm644 \
  "${repo_root}/install/system/etc/pacman.d/hooks/95-archmeros-graphics-safety.hook" \
  "${hook_target}"

printf 'archmeros update safety applied\n'
printf 'hook:   %s\n' "${hook_target}"
printf 'script: %s\n' "${script_target}"
