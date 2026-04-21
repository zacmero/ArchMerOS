#!/usr/bin/env bash

set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  printf 'apply-monitor-system: run as root\n' >&2
  exit 1
fi

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
polkit_rule_path="/etc/polkit-1/rules.d/86-monitor.rules"

install -Dm644 "${repo_root}/install/system/etc/polkit-1/rules.d/86-monitor.rules" \
  "${polkit_rule_path}"

printf 'archmeros monitor policy applied\n'
printf 'rule: %s\n' "${polkit_rule_path}"
