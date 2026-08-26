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

  ["${config_root}/thunar/uca.xml"]="${HOME}/.config/Thunar/uca.xml"
  ["${config_root}/mimeapps.list"]="${HOME}/.config/mimeapps.list"
  ["${config_root}/systemd/user"]="${HOME}/.config/systemd/user"
  ["${repo_root}/local/share/applications/thunar.desktop"]="${HOME}/.local/share/applications/thunar.desktop"
  ["${repo_root}/local/share/applications/imv.desktop"]="${HOME}/.local/share/applications/imv.desktop"
  ["${repo_root}/local/share/applications/mpv.desktop"]="${HOME}/.local/share/applications/mpv.desktop"
  ["${repo_root}/local/share/applications/archmeros-browser.desktop"]="${HOME}/.local/share/applications/archmeros-browser.desktop"
  ["${repo_root}/local/share/applications/org.wezfurlong.wezterm.desktop"]="${HOME}/.local/share/applications/org.wezfurlong.wezterm.desktop"
  ["${repo_root}/local/share/applications/archmeros-audio.desktop"]="${HOME}/.local/share/applications/archmeros-audio.desktop"
  ["${repo_root}/local/share/applications/archmeros-themes.desktop"]="${HOME}/.local/share/applications/archmeros-themes.desktop"
  ["${repo_root}/local/share/applications/archmeros-night-drive.desktop"]="${HOME}/.local/share/applications/archmeros-night-drive.desktop"
  ["${repo_root}/local/share/applications/nvim.desktop"]="${HOME}/.local/share/applications/nvim.desktop"
  ["${repo_root}/local/share/applications/todoist.desktop"]="${HOME}/.local/share/applications/todoist.desktop"
  ["${repo_root}/local/share/applications/com.todoist.Todoist.desktop"]="${HOME}/.local/share/applications/com.todoist.Todoist.desktop"
  ["${repo_root}/local/share/applications/archmeros-cleanup.desktop"]="${HOME}/.local/share/applications/archmeros-cleanup.desktop"
  ["${repo_root}/local/share/applications/archmeros-wallpaper.desktop"]="${HOME}/.local/share/applications/archmeros-wallpaper.desktop"
  ["${repo_root}/local/share/applications/obsidian.desktop"]="${HOME}/.local/share/applications/obsidian.desktop"
  ["${repo_root}/local/share/applications/chatgpt.desktop"]="${HOME}/.local/share/applications/chatgpt.desktop"
  ["${repo_root}/local/share/applications/gemini.desktop"]="${HOME}/.local/share/applications/gemini.desktop"
  ["${repo_root}/local/share/applications/youtube-music.desktop"]="${HOME}/.local/share/applications/youtube-music.desktop"
  ["${repo_root}/local/share/applications/plex-server.desktop"]="${HOME}/.local/share/applications/plex-server.desktop"
  ["${repo_root}/local/share/applications/com.termius.Termius.desktop"]="${HOME}/.local/share/applications/com.termius.Termius.desktop"
  ["${repo_root}/local/share/applications/archmeros-emoji.desktop"]="${HOME}/.local/share/applications/archmeros-emoji.desktop"
  ["${repo_root}/local/share/applications/qbittorrent.desktop"]="${HOME}/.local/share/applications/qbittorrent.desktop"
  ["${repo_root}/local/share/applications/org.qbittorrent.qBittorrent.desktop"]="${HOME}/.local/share/applications/org.qbittorrent.qBittorrent.desktop"
  ["${repo_root}/local/share/icons/ArchMerOS-Icons"]="${HOME}/.local/share/icons/ArchMerOS-Icons"
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

link_entry() {
  local source="$1"
  local target="$2"

  if [[ ! -e "$source" ]]; then
    printf 'skip: missing source %s\n' "$source"
    return 0
  fi

  mkdir -p "$(dirname "$target")"

  if [[ -L "$target" ]]; then
    current="$(readlink -f "$target")"
    desired="$(readlink -f "$source")"
    if [[ "$current" == "$desired" ]]; then
      printf 'ok: %s already linked\n' "$target"
      return 0
    fi
    backup_path "$target"
  elif [[ -e "$target" ]]; then
    backup_path "$target"
  fi

  ln -sfn "$source" "$target"
  printf 'linked: %s -> %s\n' "$target" "$source"
}

for source in "${!links[@]}"; do
  link_entry "$source" "${links[$source]}"
done

if [[ -d "${firefox_root}" && -f "${config_root}/firefox/user.js" ]]; then
  for prof in "${firefox_root}"/*; do
    if [[ -d "$prof" && ( -f "${prof}/prefs.js" || -f "${prof}/times.json" || -f "${prof}/compatibility.ini" ) ]]; then
      link_entry "${config_root}/firefox/user.js" "${prof}/user.js"
      link_entry "${config_root}/firefox/chrome/userChrome.css" "${prof}/chrome/userChrome.css"
    fi
  done
fi

if [[ "$made_backup" -eq 1 ]]; then
  printf 'backup: conflicting paths moved to %s\n' "$backup_root"
fi
