#!/usr/bin/env bash

set -euo pipefail

# 1. Active media playback (playerctl)
if command -v playerctl >/dev/null 2>&1; then
  if playerctl --all-players status 2>/dev/null | grep -qx 'Playing'; then
    exit 0
  fi
fi

# 2. Bottles Flatpak running
if command -v flatpak >/dev/null 2>&1; then
  if flatpak ps 2>/dev/null | grep -q 'com\.usebottles\.bottles'; then
    exit 0
  fi
fi

# 3. Bottles process / CLI wrapper running
if pgrep -f 'com\.usebottles\.bottles' >/dev/null 2>&1; then
  exit 0
fi

# 4. Wine server, Wine game processes, or Proton active
if pgrep -x wineserver >/dev/null 2>&1; then
  exit 0
fi

if pgrep -f '(wine64-preloader|wine-preloader|steam_proton|gamescope)' >/dev/null 2>&1; then
  exit 0
fi

exit 1
