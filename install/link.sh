#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config_root="${repo_root}/config"
firefox_root="${HOME}/.mozilla/firefox"
firefox_profiles_ini="${firefox_root}/profiles.ini"

declare -A links=(
  ["${config_root}/hypr"]="${HOME}/.config/hypr"
  ["${config_root}/waybar"]="${HOME}/.config/waybar"
  ["${config_root}/rofi"]="${HOME}/.config/rofi"
  ["${config_root}/walker"]="${HOME}/.config/walker"
  ["${config_root}/mako"]="${HOME}/.config/mako"
  ["${config_root}/archmeros"]="${HOME}/.config/archmeros"
  ["${config_root}/easyeffects"]="${HOME}/.config/easyeffects"
  ["${config_root}/pipewire"]="${HOME}/.config/pipewire"
  ["${config_root}/wireplumber"]="${HOME}/.config/wireplumber"
  ["${config_root}/gtk-3.0"]="${HOME}/.config/gtk-3.0"
  ["${config_root}/gtk-4.0"]="${HOME}/.config/gtk-4.0"
  ["${config_root}/rofimoji.rc"]="${HOME}/.config/rofimoji.rc"
  ["${config_root}/mimeapps.list"]="${HOME}/.config/mimeapps.list"
  ["${config_root}/systemd/user"]="${HOME}/.config/systemd/user"
  ["${repo_root}/local/share/applications/thunar.desktop"]="${HOME}/.local/share/applications/thunar.desktop"
  ["${repo_root}/local/share/applications/imv.desktop"]="${HOME}/.local/share/applications/imv.desktop"
  ["${repo_root}/local/share/applications/mpv.desktop"]="${HOME}/.local/share/applications/mpv.desktop"
  ["${repo_root}/local/share/applications/archmeros-browser.desktop"]="${HOME}/.local/share/applications/archmeros-browser.desktop"
  ["${repo_root}/local/share/applications/org.wezfurlong.wezterm.desktop"]="${HOME}/.local/share/applications/org.wezfurlong.wezterm.desktop"
  ["${repo_root}/local/share/applications/archmeros-audio.desktop"]="${HOME}/.local/share/applications/archmeros-audio.desktop"
  ["${repo_root}/local/share/applications/archmeros-themes.desktop"]="${HOME}/.local/share/applications/archmeros-themes.desktop"
  ["${repo_root}/local/share/applications/nvim.desktop"]="${HOME}/.local/share/applications/nvim.desktop"
  ["${repo_root}/local/share/applications/todoist.desktop"]="${HOME}/.local/share/applications/todoist.desktop"
  ["${repo_root}/local/share/applications/evernote.desktop"]="${HOME}/.local/share/applications/evernote.desktop"
  ["${repo_root}/local/share/applications/chatgpt.desktop"]="${HOME}/.local/share/applications/chatgpt.desktop"
  ["${repo_root}/local/share/applications/youtube-music.desktop"]="${HOME}/.local/share/applications/youtube-music.desktop"
  ["${repo_root}/local/share/applications/com.termius.Termius.desktop"]="${HOME}/.local/share/applications/com.termius.Termius.desktop"
  ["${repo_root}/local/share/applications/archmeros-emoji.desktop"]="${HOME}/.local/share/applications/archmeros-emoji.desktop"
  ["${repo_root}/local/share/icons/ArchMerOS-Icons"]="${HOME}/.local/share/icons/ArchMerOS-Icons"
)

if [[ -f "${firefox_profiles_ini}" && -f "${config_root}/firefox/user.js" ]]; then
  firefox_profile_rel="$(awk -F= '
    /^\[Profile/ { in_profile=1; path=""; name="" }
    /^\[/ && $0 !~ /^\[Profile/ { in_profile=0 }
    in_profile && $1=="Name" { name=$2 }
    in_profile && $1=="Path" { path=$2 }
    in_profile && name=="default-release" && path!="" { print path; exit }
  ' "${firefox_profiles_ini}")"

  if [[ -n "${firefox_profile_rel:-}" ]]; then
    links["${config_root}/firefox/user.js"]="${firefox_root}/${firefox_profile_rel}/user.js"
  fi
fi

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
