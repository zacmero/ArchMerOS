#!/usr/bin/env bash

set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  printf 'apply-system: run as root\n' >&2
  exit 1
fi

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

bash "${repo_root}/install/system/apply-audio-system.sh"
bash "${repo_root}/install/system/apply-bluetooth-system.sh"
bash "${repo_root}/install/system/apply-keyboard-system.sh"
bash "${repo_root}/install/system/apply-bootloader-system.sh"
bash "${repo_root}/install/system/apply-greeter-system.sh"

printf 'archmeros system defaults applied\n'
