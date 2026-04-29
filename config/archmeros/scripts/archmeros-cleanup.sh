#!/usr/bin/env bash

set -euo pipefail

dev_package_list=(
  cuda
  dejagnu
  doxygen
  eos-reboot-recommended
  ffmpeg4.4
  gcc-ada
  gcc-d
  go
  minizip-ng
  python-pytest
  ttf-jetbrains-mono
  vulkan-headers
  xbitmaps
)

size_report() {
  printf 'Command:\n  pacman -Qi %s\n\n' "${dev_package_list[*]}"
  for pkg in "${dev_package_list[@]}"; do
    if ! info="$(pacman -Qi "$pkg" 2>/dev/null)"; then
      printf '%-24s %s\n' "$pkg" "not installed"
      continue
    fi
    installed_size="$(printf '%s\n' "$info" | awk -F': *' '/^Installed Size/{print $2; exit}')"
    install_reason="$(printf '%s\n' "$info" | awk -F': *' '/^Install Reason/{print $2; exit}')"
    description="$(printf '%s\n' "$info" | awk -F': *' '/^Description/{print $2; exit}')"
    printf '%-24s %-14s %s\n' "$pkg" "${installed_size:-unknown}" "${description:-}"
    printf '  reason: %s\n' "${install_reason:-unknown}"
  done
}

cache_status() {
  printf 'Package cache:\n'
  du -sh /var/cache/pacman/pkg 2>/dev/null || printf '  unavailable\n'
  printf '\nOrphan packages:\n'
  if ! orphans="$(pacman -Qdtq 2>/dev/null)"; then
    printf '  unavailable\n'
    return 0
  fi
  if [[ -n "${orphans:-}" ]]; then
    printf '%s\n' "$orphans" | sed 's/^/  /'
  else
    printf '  none\n'
  fi
}

trim_cache() {
  printf 'Command:\n  sudo paccache -r -k 1\n\n'
  if command -v paccache >/dev/null 2>&1; then
    sudo paccache -r -k 1
  else
    printf 'paccache not found.\n' >&2
    return 1
  fi
}

show_orphans() {
  printf 'Command:\n  pacman -Qdtq\n\n'
  pacman -Qdtq || true
}

remove_orphans() {
  mapfile -t orphans < <(pacman -Qdtq 2>/dev/null || true)
  if [[ "${#orphans[@]}" -eq 0 ]]; then
    printf 'No orphan packages found.\n'
    return 0
  fi

  printf 'Orphans to remove:\n'
  printf '  %s\n' "${orphans[@]}"
  printf '\nCommand:\n  sudo pacman -Rns %s\n\n' "${orphans[*]}"
  read -r -p 'Remove these orphan packages? [y/N] ' answer
  case "$answer" in
    y|Y|yes|YES)
      sudo pacman -Rns "${orphans[@]}"
      ;;
    *)
      printf 'Skipped.\n'
      ;;
  esac
}

full_cleanup() {
  trim_cache
  printf '\n'
  remove_orphans
}

print_menu() {
  cat <<'EOF'
ArchMerOS Cleanup

1) Cache status
   du -sh /var/cache/pacman/pkg
   pacman -Qdtq

2) Trim package cache
   sudo paccache -r -k 1

3) Review dev/tool packages
   pacman -Qi cuda dejagnu doxygen eos-reboot-recommended ffmpeg4.4 gcc-ada gcc-d go minizip-ng python-pytest ttf-jetbrains-mono vulkan-headers xbitmaps

4) Show orphan packages
   pacman -Qdtq

5) Remove orphan packages
   sudo pacman -Rns <orphan package names>

6) Full cleanup
   sudo paccache -r -k 1
   pacman -Qdtq
   sudo pacman -Rns <orphan package names>

q) Quit
EOF
}

interactive_menu() {
  printf '\033]0;ArchMerOS Cleanup\a'
  while true; do
    print_menu
    printf '\nSelect: '
    read -r choice
    case "$choice" in
      1) cache_status ;;
      2) trim_cache ;;
      3) size_report ;;
      4) show_orphans ;;
      5) remove_orphans ;;
      6) full_cleanup ;;
      q|Q) exit 0 ;;
      *) printf 'Unknown choice.\n' ;;
    esac
    printf '\nPress Enter to return to the menu...'
    read -r _
    printf '\n'
  done
}

mode="${1:-menu}"

case "$mode" in
  menu)
    if [[ -t 1 ]]; then
      interactive_menu
    elif command -v wezterm >/dev/null 2>&1; then
      exec wezterm start --always-new-process --class archmeros-cleanup -- "$0" menu
    else
      printf 'No terminal emulator found. Run %s menu in a terminal.\n' "$0" >&2
      exit 1
    fi
    ;;
  status)
    cache_status
    ;;
  cache)
    trim_cache
    ;;
  sizes)
    size_report
    ;;
  orphans)
    show_orphans
    ;;
  remove-orphans|orphans-remove)
    remove_orphans
    ;;
  all|cleanup)
    full_cleanup
    ;;
  *)
    printf 'Usage: %s [menu|status|cache|sizes|orphans|remove-orphans|all]\n' "$0" >&2
    exit 1
    ;;
esac
