#!/usr/bin/env bash

set -euo pipefail

source_root="${ARCHMEROS_WINDOWS_DESKTOP:-/mnt/windows-desktop}"
target_root="${ARCHMEROS_LINUX_DESKTOP:-$HOME/Desktop}"

mkdir -p "$target_root"

if ! ls "$source_root" >/dev/null 2>&1; then
  printf 'archmeros-desktop-sync: source unavailable: %s\n' "$source_root" >&2
  exit 1
fi

is_managed_link() {
  local path="$1"
  [[ -L "$path" ]] || return 1
  local raw
  raw="$(readlink "$path" 2>/dev/null || true)"
  local resolved
  resolved="$(readlink -f "$path" 2>/dev/null || true)"
  [[ "$raw" == /run/media/zacmero/FC0C31860C313D48/Users/Administrator/Desktop/* ]] \
    || [[ "$raw" == /mnt/windows-desktop/* ]] \
    || [[ "$resolved" == /run/media/zacmero/FC0C31860C313D48/Users/Administrator/Desktop/* ]] \
    || [[ "$resolved" == /mnt/windows-desktop/* ]]
}

should_skip_name() {
  local name="$1"
  [[ "$name" == *.lnk ]] && return 0
  [[ "$name" == "desktop.ini" ]] && return 0
  [[ "${name,,}" == "trash" ]] && return 0
  [[ "${name,,}" == "softwares" ]] && return 0
  return 1
}

while IFS= read -r -d '' existing; do
  if is_managed_link "$existing"; then
    rm -f "$existing"
  fi
done < <(find "$target_root" -mindepth 1 -maxdepth 1 -print0)

while IFS= read -r -d '' source; do
  name="$(basename "$source")"
  if should_skip_name "$name"; then
    continue
  fi

  target="${target_root}/${name}"
  if [[ -e "$target" || -L "$target" ]]; then
    if ! is_managed_link "$target"; then
      continue
    fi
    rm -f "$target"
  fi

  ln -s "$source" "$target"
done < <(find -L "$source_root" -mindepth 1 -maxdepth 1 -print0 | sort -z)
