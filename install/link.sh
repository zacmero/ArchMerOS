#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config_root="${repo_root}/config"

declare -A links=(
  ["${config_root}/hypr"]="${HOME}/.config/hypr"
  ["${config_root}/waybar"]="${HOME}/.config/waybar"
  ["${config_root}/rofi"]="${HOME}/.config/rofi"
  ["${config_root}/walker"]="${HOME}/.config/walker"
  ["${config_root}/mako"]="${HOME}/.config/mako"
  ["${config_root}/archmeros"]="${HOME}/.config/archmeros"
  ["${config_root}/gtk-3.0"]="${HOME}/.config/gtk-3.0"
  ["${config_root}/gtk-4.0"]="${HOME}/.config/gtk-4.0"
  ["${config_root}/systemd/user"]="${HOME}/.config/systemd/user"
  ["${repo_root}/local/share/applications/thunar.desktop"]="${HOME}/.local/share/applications/thunar.desktop"
)

backup_root="${HOME}/.config/archmeros-backups/$(date +%Y%m%d-%H%M%S)"
made_backup=0

backup_path() {
  local target="$1"
  local rel
  if [[ "$target" == "${HOME}/.config/"* ]]; then
    rel="${target#${HOME}/.config/}"
  elif [[ "$target" == "${HOME}/.local/share/"* ]]; then
    rel="local-share/${target#${HOME}/.local/share/}"
  else
    rel="$(basename "$target")"
  fi
  local dest="${backup_root}/${rel}"
  mkdir -p "$(dirname "$dest")"
  mv "$target" "$dest"
  made_backup=1
}

for source in "${!links[@]}"; do
  target="${links[$source]}"

  if [[ ! -e "$source" ]]; then
    printf 'skip: missing source %s\n' "$source"
    continue
  fi

  mkdir -p "$(dirname "$target")"

  if [[ -L "$target" ]]; then
    current="$(readlink -f "$target")"
    desired="$(readlink -f "$source")"
    if [[ "$current" == "$desired" ]]; then
      printf 'ok: %s already linked\n' "$target"
      continue
    fi
    backup_path "$target"
  elif [[ -e "$target" ]]; then
    backup_path "$target"
  fi

  ln -sfn "$source" "$target"
  printf 'linked: %s -> %s\n' "$target" "$source"
done

if [[ "$made_backup" -eq 1 ]]; then
  printf 'backup: conflicting paths moved to %s\n' "$backup_root"
fi
