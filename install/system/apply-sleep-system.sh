#!/usr/bin/env bash

set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  printf 'apply-sleep-system: run as root\n' >&2
  exit 1
fi

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source_file="${repo_root}/install/system/etc/systemd/sleep.conf.d/90-archmeros-resume.conf"
target_file="/etc/systemd/sleep.conf.d/90-archmeros-resume.conf"

if [[ -f "${target_file}" ]] && ! cmp -s "${source_file}" "${target_file}"; then
  backup="${target_file}.before-archmeros-$(date +%Y%m%d-%H%M%S)"
  cp -a -- "${target_file}" "${backup}"
  printf 'apply-sleep-system: backed up existing policy to %s\n' "${backup}"
fi

install -Dm644 "${source_file}" "${target_file}"

printf 'archmeros sleep policy applied\n'
printf 'suspend backend: s2idle (avoids failing ACPI S3/deep resume)\n'
printf 'verification: systemd-analyze cat-config systemd/sleep.conf\n'
