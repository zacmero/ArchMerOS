#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
theme_pkg="${HOME}/.cache/yay/catppuccin-gtk-theme-frappe/catppuccin-gtk-theme-frappe-1.0.3-1-any.pkg.tar.zst"
cursor_pkg="${HOME}/.cache/yay/bibata-cursor-theme-bin/bibata-cursor-theme-bin-2.0.7-1-any.pkg.tar.zst"
papirus_clone="${repo_root}/vendor/papirus-icon-theme"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "${HOME}/.local/share/themes" "${HOME}/.local/share/icons"

if [[ -f "$theme_pkg" ]]; then
  bsdtar -xf "$theme_pkg" -C "$tmpdir"
  cp -a "$tmpdir/usr/share/themes/." "${HOME}/.local/share/themes/"
fi

rm -rf "$tmpdir"/*

if [[ -f "$cursor_pkg" ]]; then
  bsdtar -xf "$cursor_pkg" -C "$tmpdir"
  cp -a "$tmpdir/usr/share/icons/." "${HOME}/.local/share/icons/"
fi

if [[ -d "$papirus_clone/Papirus-Dark" ]]; then
  cp -a "$papirus_clone/Papirus" "${HOME}/.local/share/icons/" 2>/dev/null || true
  cp -a "$papirus_clone/Papirus-Dark" "${HOME}/.local/share/icons/"
  cp -a "$papirus_clone/Papirus-Light" "${HOME}/.local/share/icons/" 2>/dev/null || true
  cp -a "$papirus_clone/ePapirus" "${HOME}/.local/share/icons/" 2>/dev/null || true
  cp -a "$papirus_clone/ePapirus-Dark" "${HOME}/.local/share/icons/" 2>/dev/null || true
  cp -a "$papirus_clone/ePapirus-Light" "${HOME}/.local/share/icons/" 2>/dev/null || true
fi
