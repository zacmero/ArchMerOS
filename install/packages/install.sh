#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

usage() {
  cat <<'EOF'
Usage: install/packages/install.sh [--workstation] [--nvidia-pascal]

Installs ArchMerOS package manifests:
  - base.txt
  - media.txt
  - audio.txt
  - optional-aur.txt

Optional profiles:
  --workstation    install install/profiles/workstation.txt
  --nvidia-pascal  install install/profiles/nvidia-pascal.txt and nvidia-pascal-aur.txt
EOF
}

want_workstation=0
want_nvidia=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workstation)
      want_workstation=1
      ;;
    --nvidia-pascal)
      want_nvidia=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'install/packages/install.sh: unknown option %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

read_manifest() {
  local path="$1"
  while IFS= read -r line; do
    [[ -z "${line//[[:space:]]/}" ]] && continue
    [[ "${line:0:1}" == "#" ]] && continue
    printf '%s\n' "$line"
  done < "$path"
}

repo_packages=()
aur_packages=()

add_repo_manifest() {
  local manifest="$1"
  local path="${repo_root}/${manifest}"
  if [[ ! -f "$path" ]]; then
    printf 'install/packages/install.sh: missing manifest %s\n' "$manifest" >&2
    exit 1
  fi
  mapfile -t lines < <(read_manifest "$path")
  repo_packages+=("${lines[@]}")
}

add_aur_manifest() {
  local manifest="$1"
  local path="${repo_root}/${manifest}"
  if [[ ! -f "$path" ]]; then
    printf 'install/packages/install.sh: missing manifest %s\n' "$manifest" >&2
    exit 1
  fi
  mapfile -t lines < <(read_manifest "$path")
  aur_packages+=("${lines[@]}")
}

add_repo_manifest "install/packages/base.txt"
add_repo_manifest "install/packages/media.txt"
add_repo_manifest "install/packages/audio.txt"
add_aur_manifest "install/packages/optional-aur.txt"

if [[ "$want_workstation" -eq 1 ]]; then
  add_repo_manifest "install/profiles/workstation.txt"
fi

if [[ "$want_nvidia" -eq 1 ]]; then
  add_repo_manifest "install/profiles/nvidia-pascal.txt"
  add_aur_manifest "install/profiles/nvidia-pascal-aur.txt"
fi

if [[ "${#repo_packages[@]}" -gt 0 ]]; then
  printf 'installing repo packages: %s\n' "${repo_packages[*]}"
  sudo pacman -S --needed --noconfirm "${repo_packages[@]}"
fi

if [[ "${#aur_packages[@]}" -gt 0 ]]; then
  printf 'installing aur packages: %s\n' "${aur_packages[*]}"
  yay -S --needed --answerclean All --noconfirm "${aur_packages[@]}"
fi

printf 'archmeros package manifests applied\n'
