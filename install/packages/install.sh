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
  - flatpak.txt

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
flatpak_apps=()

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

add_flatpak_manifest() {
  local manifest="$1"
  local path="${repo_root}/${manifest}"
  if [[ ! -f "$path" ]]; then
    printf 'install/packages/install.sh: missing manifest %s\n' "$manifest" >&2
    exit 1
  fi
  mapfile -t lines < <(read_manifest "$path")
  flatpak_apps+=("${lines[@]}")
}

add_repo_manifest "install/packages/base.txt"
add_repo_manifest "install/packages/media.txt"
add_repo_manifest "install/packages/audio.txt"
add_aur_manifest "install/packages/optional-aur.txt"
add_flatpak_manifest "install/packages/flatpak.txt"

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

if [[ "${#flatpak_apps[@]}" -gt 0 ]]; then
  if ! command -v flatpak >/dev/null 2>&1; then
    printf 'install/packages/install.sh: flatpak is required but was not found after package install\n' >&2
    exit 1
  fi

  if ! flatpak remotes --columns=name 2>/dev/null | grep -qx flathub; then
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  fi

  printf 'installing flatpak apps: %s\n' "${flatpak_apps[*]}"
  sudo flatpak install -y flathub "${flatpak_apps[@]}"
fi

printf 'archmeros package manifests applied\n'
