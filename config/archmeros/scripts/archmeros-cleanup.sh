#!/usr/bin/env bash

set -euo pipefail

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
  printf 'Command:\n  sudo paccache -r -k 2\n\n'
  if command -v paccache >/dev/null 2>&1; then
    sudo paccache -r -k 2
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
   sudo paccache -r -k 2

3) Show orphan packages
   pacman -Qdtq

4) Remove orphan packages
   sudo pacman -Rns <orphan package names>

5) Full cleanup
   sudo paccache -r -k 2
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
      3) show_orphans ;;
      4) remove_orphans ;;
      5) full_cleanup ;;
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
    printf 'Usage: %s [menu|status|cache|orphans|remove-orphans|all]\n' "$0" >&2
    exit 1
    ;;
esac
