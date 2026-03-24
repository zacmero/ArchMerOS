#!/usr/bin/env bash

set -euo pipefail

if ! command -v gsettings >/dev/null 2>&1; then
  exit 0
fi

set_pref() {
  local schema="$1"
  local key="$2"
  local value="$3"

  gsettings set "$schema" "$key" "$value" >/dev/null 2>&1 || true
}

set_pref org.gnome.desktop.interface color-scheme "'prefer-dark'"
set_pref org.gnome.desktop.interface gtk-theme "'catppuccin-frappe-blue-standard+default'"
set_pref org.gnome.desktop.interface icon-theme "'ArchMerOS-Icons'"
set_pref org.gnome.desktop.interface cursor-theme "'Bibata-Modern-Classic'"
set_pref org.gnome.desktop.interface font-name "'Noto Sans 14'"
set_pref org.gnome.desktop.interface monospace-font-name "'CaskaydiaCove Nerd Font Mono 14'"
set_pref org.gnome.desktop.interface text-scaling-factor "1.10"
set_pref org.gnome.desktop.interface color-scheme "'prefer-dark'"
