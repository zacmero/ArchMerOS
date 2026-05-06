#!/usr/bin/env bash

set -euo pipefail

target_uuid="${ARCHMEROS_SNAPSHOT_TARGET_UUID:-A65602225601F439}"
current_user="${USER:-$(id -un)}"
target_mount="${ARCHMEROS_SNAPSHOT_MOUNTPOINT:-/run/media/${current_user}/${target_uuid}}"
repo_dir="${ARCHMEROS_SNAPSHOT_REPO_DIR:-${target_mount}/ArchMerOS-restic}"
password_file="${ARCHMEROS_SNAPSHOT_PASSWORD_FILE:-${HOME}/.config/archmeros/system-snapshot.pass}"
exclude_file="${HOME}/.config/archmeros/system-snapshot-excludes.txt"
keep_last="${ARCHMEROS_SNAPSHOT_KEEP_LAST:-1}"
include_paths=(/boot /etc /opt /root /usr /var)

human_bytes() {
  if command -v numfmt >/dev/null 2>&1; then
    numfmt --to=iec --suffix=B "$1"
  else
    printf '%sB\n' "$1"
  fi
}

fail() {
  printf 'archmeros-system-snapshot: %s\n' "$*" >&2
  exit 1
}

warn() {
  printf 'archmeros-system-snapshot: warning: %s\n' "$*" >&2
}

ensure_dependencies() {
  command -v restic >/dev/null 2>&1 || fail "restic not installed"
  command -v sudo >/dev/null 2>&1 || fail "sudo not available"
}

ensure_target_mounted() {
  mountpoint -q "$target_mount" || fail "snapshot disk not mounted: ${target_mount} (${target_uuid})"
}

target_mount_options() {
  findmnt -rn -T "$target_mount" -o OPTIONS 2>/dev/null || true
}

ensure_target_writable() {
  local options
  options="$(target_mount_options)"
  [[ -n "$options" ]] || fail "could not read mount options for ${target_mount}"

  local probe_dir probe_file
  probe_dir="${target_mount}/.archmeros-write-probe"
  probe_file="${probe_dir}/probe.$$"

  mkdir -p "$probe_dir" 2>/dev/null || fail "snapshot target is not writable: cannot create probe directory in ${target_mount}"
  if ! : >"$probe_file" 2>/dev/null; then
    fail "snapshot target is not writable: write probe failed in ${target_mount}"
  fi
  rm -f "$probe_file" 2>/dev/null || true
}

run_privileged() {
  if sudo -n true >/dev/null 2>&1; then
    sudo "$@"
    return
  fi

  if [[ -t 0 ]]; then
    sudo "$@"
    return
  fi

  "$@"
}

available_bytes() {
  df -B1 --output=avail "$target_mount" 2>/dev/null | awk 'NR==2 {print $1+0}'
}

estimated_source_bytes() {
  { run_privileged du -sx -B1 "${include_paths[@]}" 2>/dev/null || true; } | awk '{sum += $1} END {print sum + 0}'
}

ensure_password_file() {
  [[ -f "$password_file" ]] && return 0
  mkdir -p "$(dirname "$password_file")"
  umask 077
  head -c 32 /dev/urandom | base64 >"$password_file"
  chmod 600 "$password_file"
}

ensure_repo() {
  if [[ -f "${repo_dir}/config" ]]; then
    return 0
  fi
  sudo mkdir -p "$repo_dir"
  sudo restic -r "$repo_dir" --password-file "$password_file" init
}

show_status() {
  local options avail estimate
  ensure_target_mounted
  options="$(target_mount_options)"
  avail="$(available_bytes)"
  estimate="$(estimated_source_bytes)"

  printf 'target:    %s\n' "$target_mount"
  printf 'uuid:      %s\n' "$target_uuid"
  printf 'mount:     %s\n' "${options:-unknown}"
  printf 'free:      %s\n' "$(human_bytes "$avail")"
  printf 'estimate:  %s\n' "$(human_bytes "$estimate")"
  printf 'repo:      %s\n' "$repo_dir"

  if [[ -f "${repo_dir}/config" ]]; then
    printf 'repo-init: yes\n'
  else
    printf 'repo-init: no\n'
  fi

  local write_probe='ok'
  local probe_dir probe_file
  probe_dir="${target_mount}/.archmeros-write-probe"
  probe_file="${probe_dir}/probe.$$"
  if ! mkdir -p "$probe_dir" 2>/dev/null || ! : >"$probe_file" 2>/dev/null; then
    write_probe='failed'
  else
    rm -f "$probe_file" 2>/dev/null || true
  fi

  printf 'write-test: %s\n' "$write_probe"

  case ",${options}," in
  *,ro,*)
    warn "mount options still report read-only; write probe is the real gate"
    ;;
  esac

  if [[ "$write_probe" != "ok" ]]; then
    warn "snapshot target cannot currently accept writes"
  fi

  if ((avail < estimate)); then
    warn "free space is below the current estimated system snapshot size"
  fi

  return 0
}

create_snapshot() {
  local avail estimate
  ensure_dependencies
  ensure_target_mounted
  ensure_target_writable
  ensure_password_file

  avail="$(available_bytes)"
  estimate="$(estimated_source_bytes)"

  printf 'snapshot target:   %s\n' "$target_mount"
  printf 'available space:   %s\n' "$(human_bytes "$avail")"
  printf 'estimated payload: %s\n' "$(human_bytes "$estimate")"

  if ((avail < estimate)); then
    fail "not enough free space on snapshot target"
  fi

  ensure_repo

  sudo restic -r "$repo_dir" --password-file "$password_file" backup \
    "${include_paths[@]}" \
    --exclude-file "$exclude_file"

  sudo restic -r "$repo_dir" --password-file "$password_file" forget \
    --keep-last "$keep_last" \
    --prune

  printf 'snapshot complete\n'
  printf 'repo size: %s\n' "$(du -sh "$repo_dir" 2>/dev/null | awk '{print $1}')"
  sudo restic -r "$repo_dir" --password-file "$password_file" snapshots
  return 0
}

case "${1:-create}" in
status)
  show_status
  ;;
create)
  create_snapshot
  ;;
*)
  fail "usage: archmeros-system-snapshot.sh [status|create]"
  ;;
esac
