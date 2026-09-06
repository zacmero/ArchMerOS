#!/usr/bin/env bash

set -euo pipefail

BOTTLES_DIR="${HOME}/.var/app/com.usebottles.bottles/data/bottles/bottles"
FLATPAK_ID="com.usebottles.bottles"
GST_FIX="nvh264dec:NONE,vulkanh264dec:NONE,vulkanh264device1dec:NONE"

usage() {
  cat <<HELP
ArchMerOS Bottles Gaming & Compatibility Tool

Usage:
  $(basename "$0") [command] [options]

Commands:
  status                     Display Bottles health, overrides, prefixes, and running games (default)
  apply-gst-fix <bottle>     Inject GStreamer software decoder fallback into a bottle's bottle.yml
  link-drive <bottle> <letter> <path>
                             Symlink a mount point (e.g. /mnt/windows-ssd) to dosdevices/X: in the bottle
  fix-videos <movie_dir>     Remux cutscene MP4s to H.264 Baseline (removes QuickTime tmcd tracks)
  help                       Show this help message

HELP
}

cmd_status() {
  printf '=== ArchMerOS Bottles Environment Status ===\n\n'

  # 1. Flatpak & Package Check
  if command -v flatpak >/dev/null 2>&1 && flatpak info "$FLATPAK_ID" >/dev/null 2>&1; then
    local version
    version="$(flatpak info "$FLATPAK_ID" | awk '/Version:/{print $2}')"
    local runtime
    runtime="$(flatpak info "$FLATPAK_ID" | awk '/Runtime:/{print $2}')"
    printf '[✓] Flatpak Package:  Installed (%s, runtime %s)\n' "${version:-unknown}" "${runtime:-unknown}"
  else
    printf '[✗] Flatpak Package:  Not found or not installed\n'
    return 1
  fi

  # 2. Filesystem Overrides
  printf '[*] Flatpak Overrides:\n'
  if flatpak override --user --show "$FLATPAK_ID" 2>/dev/null | grep -q 'filesystems='; then
    flatpak override --user --show "$FLATPAK_ID" | grep 'filesystems=' | sed 's/^/    /'
  else
    printf '    (No user filesystem overrides set)\n'
  fi

  # 3. Active Processes & Idle Inhibit
  printf '\n[*] Process & Screensaver Inhibit Status:\n'
  if flatpak ps 2>/dev/null | grep -q "$FLATPAK_ID"; then
    printf '    [RUNNING] Bottles Flatpak instance is active\n'
  else
    printf '    [IDLE]    Bottles Flatpak is not currently running\n'
  fi

  if pgrep -x wineserver >/dev/null 2>&1; then
    local wine_pids
    wine_pids="$(pgrep -x wineserver | tr '\n' ' ')"
    printf '    [RUNNING] wineserver active (PID: %s)\n' "$wine_pids"
  fi

  if ~/.config/archmeros/scripts/archmeros-idle-media-active.sh >/dev/null 2>&1; then
    printf '    [✓] Screensaver Inhibit: ACTIVE (screensaver and DPMS standby are blocked)\n'
  else
    printf '    [-] Screensaver Inhibit: INACTIVE (normal idle timeouts apply)\n'
  fi

  # 4. Bottles Prefix Inspection
  printf '\n[*] Managed Bottles Prefixes:\n'
  if [[ ! -d "$BOTTLES_DIR" ]]; then
    printf '    No bottles directory found at %s\n' "$BOTTLES_DIR"
    return 0
  fi

  local count=0
  for bdir in "$BOTTLES_DIR"/*; do
    [[ -d "$bdir" ]] || continue
    local bname
    bname="$(basename "$bdir")"
    local yml="$bdir/bottle.yml"
    count=$((count + 1))

    printf '  • Bottle: %s\n' "$bname"
    if [[ -f "$yml" ]]; then
      local runner dxvk vkd3d gst_rank
      runner="$(awk -F': ' '/^Runner:/{print $2}' "$yml" | tr -d "'" | tr -d '"')"
      dxvk="$(awk -F': ' '/^DXVK:/{print $2}' "$yml" | tr -d "'" | tr -d '"')"
      vkd3d="$(awk -F': ' '/^VKD3D:/{print $2}' "$yml" | tr -d "'" | tr -d '"')"
      gst_rank="$(grep 'GST_PLUGIN_FEATURE_RANK:' "$yml" 2>/dev/null || true)"

      printf '      Runner:  %s\n' "${runner:-default}"
      printf '      DXVK:    %s | VKD3D: %s\n' "${dxvk:-none}" "${vkd3d:-none}"

      if [[ -n "$gst_rank" && "$gst_rank" == *"nvh264dec:NONE"* ]]; then
        printf '      GStreamer Fallback: [ENABLED] (NVDEC/Vulkan demoted -> software fallback active)\n'
      else
        printf '      GStreamer Fallback: [NOT CONFIGURED] (May encounter black screen on cutscenes)\n'
        printf '                          Run: %s apply-gst-fix "%s"\n' "$(basename "$0")" "$bname"
      fi
    else
      printf '      (Missing bottle.yml configuration)\n'
    fi

    # Drive mappings (filtering out virtual com ports)
    if [[ -d "$bdir/dosdevices" ]]; then
      local drives=""
      for d in "$bdir"/dosdevices/*; do
        [[ -L "$d" ]] || continue
        local dname
        dname="$(basename "$d")"
        if [[ "$dname" =~ ^[a-zA-Z]:$ ]]; then
          drives+="$dname -> $(readlink "$d"); "
        fi
      done
      if [[ -n "$drives" ]]; then
        printf '      Drives:  %s\n' "$drives"
      fi
    fi
  done

  if (( count == 0 )); then
    printf '    (No bottles found in %s)\n' "$BOTTLES_DIR"
  fi
  printf '\n'
}

cmd_apply_gst_fix() {
  local target_bottle="${1:-}"
  if [[ -z "$target_bottle" ]]; then
    printf 'Error: Specify a bottle name. Available:\n' >&2
    ls -1 "$BOTTLES_DIR" 2>/dev/null || true
    exit 1
  fi

  local yml="$BOTTLES_DIR/$target_bottle/bottle.yml"
  if [[ ! -f "$yml" ]]; then
    printf 'Error: bottle.yml not found at %s\n' "$yml" >&2
    exit 1
  fi

  if grep -q "GST_PLUGIN_FEATURE_RANK: $GST_FIX" "$yml"; then
    printf '[✓] GStreamer software decoder fallback is already enabled in %s\n' "$target_bottle"
    return 0
  fi

  python3 - <<PY
import yaml
import sys

path = "$yml"
with open(path, "r", encoding="utf-8") as f:
    data = yaml.safe_load(f) or {}

env = data.setdefault("Environment_Variables", {})
env["GST_PLUGIN_FEATURE_RANK"] = "$GST_FIX"

inherited = data.setdefault("Inherited_Environment_Variables", [])
if "GST_PLUGIN_FEATURE_RANK" not in inherited:
    inherited.append("GST_PLUGIN_FEATURE_RANK")

with open(path, "w", encoding="utf-8") as f:
    yaml.dump(data, f, default_flow_style=False, sort_keys=False)

print(f"[✓] Successfully injected GST_PLUGIN_FEATURE_RANK into {path}")
PY
}

cmd_link_drive() {
  local target_bottle="${1:-}"
  local letter="${2:-}"
  local mount_path="${3:-}"

  if [[ -z "$target_bottle" || -z "$letter" || -z "$mount_path" ]]; then
    printf 'Usage: %s link-drive <bottle> <drive_letter> <target_path>\n' "$(basename "$0")" >&2
    printf 'Example: %s link-drive Spyro d /mnt/windows-ssd\n' "$(basename "$0")" >&2
    exit 1
  fi

  local dos_dir="$BOTTLES_DIR/$target_bottle/dosdevices"
  if [[ ! -d "$dos_dir" ]]; then
    printf 'Error: dosdevices directory not found at %s\n' "$dos_dir" >&2
    exit 1
  fi

  letter="$(echo "$letter" | tr '[:upper:]' '[:lower:]' | tr -d ':')"
  local link_target="$dos_dir/${letter}:"

  ln -sfn "$mount_path" "$link_target"
  printf '[✓] Linked %s -> %s\n' "$link_target" "$mount_path"

  # Also ensure Flatpak user override has access to this mount
  flatpak override --user --filesystem="$mount_path" "$FLATPAK_ID" 2>/dev/null || true
  printf '[✓] Verified Flatpak filesystem override for %s\n' "$mount_path"
}

cmd_fix_videos() {
  local movie_dir="${1:-}"
  if [[ -z "$movie_dir" || ! -d "$movie_dir" ]]; then
    printf 'Error: Specify a valid directory containing video files.\n' >&2
    exit 1
  fi

  if ! command -v ffmpeg >/dev/null 2>&1; then
    printf 'Error: ffmpeg is required to remux cutscenes.\n' >&2
    exit 1
  fi

  printf 'Scanning for MP4 cutscenes in: %s\n' "$movie_dir"
  local files=()
  while IFS= read -r -d '' f; do
    files+=("$f")
  done < <(find "$movie_dir" -type f -name "*.mp4" -print0)

  if (( ${#files[@]} == 0 )); then
    printf 'No .mp4 files found in %s\n' "$movie_dir"
    return 0
  fi

  printf 'Found %d MP4 files. Remuxing to H.264 Baseline Profile (AAC stereo, stripped QuickTime timecode)...\n\n' "${#files[@]}"

  for f in "${files[@]}"; do
    local bname
    bname="$(basename "$f")"
    local dir
    dir="$(dirname "$f")"
    local tmp="$dir/.tmp_$bname"

    printf '  -> Processing %s...' "$bname"
    if ffmpeg -y -loglevel error -i "$f" \
      -c:v libx264 -profile:v baseline -level 3.1 -pix_fmt yuv420p \
      -c:a aac -b:a 192k -ar 48000 -ac 2 \
      -write_tmcd 0 \
      "$tmp"; then
      mv "$tmp" "$f"
      printf ' [DONE]\n'
    else
      rm -f "$tmp"
      printf ' [FAILED]\n'
    fi
  done
  printf '\n[✓] Video normalization completed successfully.\n'
}

case "${1:-status}" in
  status)
    cmd_status
    ;;
  apply-gst-fix)
    shift
    cmd_apply_gst_fix "$@"
    ;;
  link-drive)
    shift
    cmd_link_drive "$@"
    ;;
  fix-videos)
    shift
    cmd_fix_videos "$@"
    ;;
  help|--help|-h)
    usage
    ;;
  *)
    printf 'Unknown command: %s\n\n' "$1" >&2
    usage
    exit 1
    ;;
esac
