#!/usr/bin/env bash
set -euo pipefail

# Elephant passes its existing launch prefix followed by the desktop Exec argv.
launch=("$@")
if [[ "${1:-}" == uwsm-app && "${2:-}" == -- ]]; then
  shift 2
fi

is_bottles=0
command_name="${1:-}"
case "${command_name##*/}" in
  bottles|bottles-cli) is_bottles=1 ;;
  flatpak)
    for arg in "$@"; do
      if [[ "$arg" == com.usebottles.bottles ]]; then
        is_bottles=1
        break
      fi
    done
    ;;
esac

if (( is_bottles )); then
  if ! "$HOME/.config/archmeros/scripts/archmeros-bottles-debug.sh" sync-sentinel; then
    printf 'archmeros: Sentinel startup failed; launching game without guaranteed achievement notifications\n' >&2
  fi
fi

exec "${launch[@]}"
