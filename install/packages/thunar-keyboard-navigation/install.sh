#!/usr/bin/env bash
set -euo pipefail

package_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for command in makepkg pacman sudo; do
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'thunar-keyboard-navigation: missing command: %s\n' "$command" >&2
    exit 1
  fi
done

cd "$package_dir"
makepkg --cleanbuild --clean --force --noconfirm
mapfile -t packages < <(makepkg --packagelist)
sudo pacman -U --noconfirm "${packages[@]}"

printf 'thunar-keyboard-navigation: installed; restart Thunar to load it\n'
