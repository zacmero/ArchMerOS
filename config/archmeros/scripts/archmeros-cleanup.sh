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

passive_item() {
  local label="$1"
  local size="$2"
  local what_it_is="$3"
  local cleanup_cmd="$4"
  printf '%-24s %-14s %s\n' "$label" "$size" "$what_it_is"
  printf '  cleanup: %s\n' "$cleanup_cmd"
}

dir_size() {
  local path="$1"
  if [[ -e "$path" ]]; then
    du -sh "$path" 2>/dev/null | awk '{print $1}' || true
  else
    printf 'missing'
  fi
}

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

passive_report() {
  local flatpak_store_size user_flatpak_size thumbnails_size cache_size coredump_size tmp_size var_tmp_size journal_size

  journal_size="$(journalctl --disk-usage 2>/dev/null | sed 's/^.*take up //; s/ in the file system.*$//' || true)"
  flatpak_store_size="$(dir_size /var/lib/flatpak)"
  user_flatpak_size="$(dir_size "${HOME}/.local/share/flatpak")"
  thumbnails_size="$(dir_size "${HOME}/.cache/thumbnails")"
  cache_size="$(dir_size "${HOME}/.cache")"
  coredump_size="$(dir_size /var/lib/systemd/coredump)"
  tmp_size="$(dir_size /tmp)"
  var_tmp_size="$(dir_size /var/tmp)"

  printf 'Command:\n'
  printf '  journalctl --disk-usage\n'
  printf '  du -sh /var/lib/flatpak ~/.local/share/flatpak ~/.cache/thumbnails ~/.cache /var/lib/systemd/coredump /tmp /var/tmp\n'
  printf '  flatpak uninstall --unused\n'
  printf '  sudo journalctl --vacuum-time=7d\n'
  printf '  sudo coredumpctl purge\n'
  printf '  rm -rf ~/.cache/thumbnails/*\n\n'

  passive_item "Journal logs" "${journal_size:-unknown}" "systemd logs from all services" "sudo journalctl --vacuum-time=7d"
  passive_item "Flatpak store" "$flatpak_store_size" "shared Flatpak runtimes/apps/cache" "flatpak uninstall --unused"
  passive_item "User Flatpak" "$user_flatpak_size" "per-user Flatpak data/cache" "flatpak uninstall --unused"
  passive_item "Thumbnails" "$thumbnails_size" "file preview thumbnails used by file managers" "rm -rf ~/.cache/thumbnails/*"
  passive_item "User cache" "$cache_size" "mixed app caches under ~/.cache" "manual review"
  passive_item "Coredumps" "$coredump_size" "crash dumps from failed processes" "sudo coredumpctl purge"
  passive_item "Temp files" "$tmp_size" "temporary runtime files in /tmp" "systemd-tmpfiles --clean"
  passive_item "/var/tmp" "$var_tmp_size" "longer-lived temporary files" "systemd-tmpfiles --clean"
}

cache_breakdown() {
  local cache_root="${HOME}/.cache"
  printf 'Command:\n  du -sh ~/.cache/* ~/.cache/.[!.]* ~/.cache/..?* 2>/dev/null | sort -h\n\n'
  if [[ ! -d "$cache_root" ]]; then
    printf '~/.cache missing\n'
    return 0
  fi

  printf 'Top ~/.cache folders:\n'
  find "$cache_root" -mindepth 1 -maxdepth 1 -exec du -sh {} + 2>/dev/null \
    | sort -h \
    | tail -n 20 \
    | awk '{printf "%-24s %s\n", $2, $1}'
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

cleanup_passive() {
  printf 'Safe passive cleanup commands:\n'
  printf '  sudo journalctl --vacuum-time=7d\n'
  printf '  flatpak uninstall --unused\n'
  printf '  rm -rf ~/.cache/thumbnails/*\n'
  printf '  sudo coredumpctl purge\n\n'

  read -r -p 'Vacuum journal logs now? [y/N] ' answer
  case "$answer" in
    y|Y|yes|YES)
      sudo journalctl --vacuum-time=7d
      ;;
  esac

  read -r -p 'Remove unused Flatpak runtimes now? [y/N] ' answer
  case "$answer" in
    y|Y|yes|YES)
      flatpak uninstall --unused
      ;;
  esac

  if [[ -d "${HOME}/.cache/thumbnails" ]]; then
    read -r -p 'Clear thumbnail cache now? [y/N] ' answer
    case "$answer" in
      y|Y|yes|YES)
        rm -rf "${HOME}/.cache/thumbnails"/*
        ;;
    esac
  fi

  if command -v coredumpctl >/dev/null 2>&1; then
    read -r -p 'Purge coredumps now? [y/N] ' answer
    case "$answer" in
      y|Y|yes|YES)
        sudo coredumpctl purge
        ;;
    esac
  fi

  read -r -p 'Clean temporary files in /tmp and /var/tmp now? [y/N] ' answer
  case "$answer" in
    y|Y|yes|YES)
      sudo systemd-tmpfiles --clean
      ;;
  esac
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

4) Review passive junk
   journalctl --disk-usage
   du -sh /var/lib/flatpak ~/.local/share/flatpak ~/.cache/thumbnails ~/.cache /var/lib/systemd/coredump /tmp /var/tmp
   flatpak uninstall --unused
   sudo journalctl --vacuum-time=7d
   sudo coredumpctl purge

5) Clean passive junk
   sudo journalctl --vacuum-time=7d
   flatpak uninstall --unused
   rm -rf ~/.cache/thumbnails/*
   sudo coredumpctl purge
   sudo systemd-tmpfiles --clean

6) Show orphan packages
   pacman -Qdtq

7) Show cache breakdown
   du -sh ~/.cache/* ~/.cache/.[!.]* ~/.cache/..?* 2>/dev/null | sort -h

8) Remove orphan packages
   sudo pacman -Rns <orphan package names>

9) Full cleanup
   sudo paccache -r -k 1
   sudo journalctl --vacuum-time=7d
   flatpak uninstall --unused
   rm -rf ~/.cache/thumbnails/*
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
      4) passive_report ;;
      5) cleanup_passive ;;
      6) show_orphans ;;
      7) cache_breakdown ;;
      8) remove_orphans ;;
      9) full_cleanup ;;
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
  passive)
    passive_report
    ;;
  passive-cleanup|cleanup-passive)
    cleanup_passive
    ;;
  cache-breakdown)
    cache_breakdown
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
    printf 'Usage: %s [menu|status|cache|sizes|passive|passive-cleanup|cache-breakdown|orphans|remove-orphans|all]\n' "$0" >&2
    exit 1
    ;;
esac
