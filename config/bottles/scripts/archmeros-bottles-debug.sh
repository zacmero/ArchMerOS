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
  sync-sentinel              Synchronize all Bottles prefixes into Sentinel achievement configuration
  setup-achievements <bottle_or_dir> <appid>
                             Provision Goldberg emulator achievement schema & bypass config for Sentinel
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

  # 4. Sentinel Achievement Watcher Status
  printf '\n[*] Sentinel Achievement Watcher:\n'
  if systemctl --user is-active --quiet archmeros-sentinel.service 2>/dev/null; then
    printf '    [✓] archmeros-sentinel.service: RUNNING (background systemd service active)\n'
  elif pgrep -x sentinel >/dev/null 2>&1; then
    local spid
    spid="$(pgrep -x sentinel | tr '\n' ' ')"
    printf '    [✓] sentinel process:         RUNNING (PID: %s)\n' "$spid"
  else
    printf '    [-] archmeros-sentinel.service: INACTIVE (start via: systemctl --user start archmeros-sentinel.service)\n'
  fi
  if [[ -f "${HOME}/.config/sentinel/config.json" ]]; then
    local prefixes
    prefixes="$(python3 -c '
import json, os
try:
    with open(os.path.expanduser("~/.config/sentinel/config.json")) as f:
        d = json.load(f)
    paths = [p.get("path","") for p in d.get("prefixes",[])]
    names = [os.path.basename(p) for p in paths if p]
    if names:
        print(", ".join(names))
except Exception:
    pass
' 2>/dev/null || true)"
    if [[ -n "$prefixes" ]]; then
      printf '    [✓] Monitored Bottles:        %s\n' "$prefixes"
    fi
  fi

  # 5. Bottles Prefix Inspection
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

cmd_sync_sentinel() {
  printf '=== ArchMerOS Sentinel Prefix Synchronization ===\n\n'
  python3 - <<PY
import json, os, sys

bottles_dir = os.path.expanduser("$BOTTLES_DIR")
config_path = os.path.expanduser("~/.config/sentinel/config.json")

if not os.path.exists(config_path):
    os.makedirs(os.path.dirname(config_path), exist_ok=True)
    data = {
        "language": {"displayName": "English", "api": "english", "webapi": "en"},
        "emulators": [
            {"id": "goldberg-steamemu", "path": "AppData/Roaming/Goldberg SteamEmu Saves", "shouldNotify": True},
            {"id": "gse", "path": "AppData/Roaming/GSE Saves", "shouldNotify": True},
            {"id": "codex", "path": "Documents/Steam/CODEX", "shouldNotify": True},
            {"id": "rune", "path": "Documents/Steam/RUNE", "shouldNotify": True}
        ],
        "prefixes": [],
        "SteamAPIKey": "",
        "steamDataSource": "external",
        "steamApiKeyMasked": "",
        "notificationSound": "steam-deck.wav",
        "logLevel": "info",
        "startOnLogin": False
    }
else:
    try:
        with open(config_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        raise SystemExit(f"Cannot parse {config_path}; leaving configuration untouched: {e}")

# Ensure emulators have required relative paths for Sentinel watcher
expected_paths = {
    "goldberg-steamemu": "AppData/Roaming/Goldberg SteamEmu Saves",
    "gse": "AppData/Roaming/GSE Saves",
    "codex": "Documents/Steam/CODEX",
    "rune": "Documents/Steam/RUNE",
}
changed = data.get("startOnLogin") is not False
data["startOnLogin"] = False
for emu in data.setdefault("emulators", []):
    eid = emu.get("id")
    if eid in expected_paths and not emu.get("path"):
        emu["path"] = expected_paths[eid]
        changed = True

prefixes = data.setdefault("prefixes", [])
existing_paths = {p.get("path") for p in prefixes if isinstance(p, dict) and "path" in p}

if os.path.isdir(bottles_dir):
    for entry in sorted(os.listdir(bottles_dir)):
        full_path = os.path.join(bottles_dir, entry)
        if os.path.isdir(full_path) and full_path not in existing_paths:
            prefixes.append({"path": full_path})
            existing_paths.add(full_path)
            changed = True
            print(f"  + Registered bottle prefix: {entry}")

if changed or not os.path.exists(config_path):
    with open(config_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    print("[✓] Updated Sentinel configuration at ~/.config/sentinel/config.json")
else:
    names = [os.path.basename(p) for p in existing_paths if p]
    print(f"[✓] All {len(names)} existing Bottles prefixes are already registered ({', '.join(names)})")
PY

  if command -v systemctl >/dev/null 2>&1; then
    if systemctl --user is-active --quiet archmeros-sentinel.service 2>/dev/null; then
      systemctl --user reload-or-restart archmeros-sentinel.service 2>/dev/null || systemctl --user restart archmeros-sentinel.service 2>/dev/null || true
      printf '[✓] Reloaded archmeros-sentinel.service to monitor updated prefixes\n'
    else
      systemctl --user start archmeros-sentinel.service
      printf '[✓] Started archmeros-sentinel.service on demand\n'
    fi
  fi
}

cmd_setup_achievements() {
  local target="${1:-}"
  local appid="${2:-}"

  if [[ -z "$target" || -z "$appid" ]]; then
    printf 'Usage: %s setup-achievements <game_dir_or_bottle> <steam_appid>\n' "$(basename "$0")" >&2
    printf 'Examples:\n' >&2
    printf '  %s setup-achievements "/mnt/windows-ssd/Games/Spyro Reignited Trilogy" 996580\n' "$(basename "$0")" >&2
    printf '  %s setup-achievements Spyro 996580\n' "$(basename "$0")" >&2
    exit 1
  fi

  printf '=== Provisioning Goldberg & Sentinel Achievements ===\n\n'
  printf 'Target: %s\n' "$target"
  printf 'Steam AppID: %s\n\n' "$appid"

  python3 - "$target" "$appid" "$BOTTLES_DIR" <<'PY'
import json, os, sys, glob, urllib.request

target = sys.argv[1]
appid = sys.argv[2]
bottles_dir = os.path.expanduser(sys.argv[3])

target_dirs = set()

if os.path.isdir(target):
    for root, dirs, files in os.walk(target):
        for f in files:
            if f.lower() in ("steam_api64.dll", "steam_api.dll"):
                target_dirs.add(root)
    if not target_dirs:
        target_dirs.add(os.path.abspath(target))
else:
    bdir = os.path.join(bottles_dir, target)
    if os.path.isdir(bdir):
        for root, dirs, files in os.walk(bdir):
            for f in files:
                if f.lower() in ("steam_api64.dll", "steam_api.dll"):
                    target_dirs.add(root)
        if not target_dirs:
            target_dirs.add(bdir)
    else:
        print(f"Error: Target '{target}' is neither an existing directory nor a known bottle name.", file=sys.stderr)
        sys.exit(1)

achievements = []
source = ""

# 1. Check local Sentinel cache
local_cache = os.path.expanduser(f"~/.local/share/sentinel/games/english/{appid}.json")
if os.path.exists(local_cache):
    try:
        with open(local_cache, "r", encoding="utf-8") as f:
            cdata = json.load(f)
        items = cdata.get("Achievement", {}).get("List", [])
        for item in items:
            achievements.append({
                "name": item.get("Name", ""),
                "displayName": item.get("DisplayName", ""),
                "description": item.get("Description", ""),
                "hidden": str(item.get("Hidden", 0)),
                "icon": "",
                "icongray": ""
            })
        if achievements:
            source = f"local Sentinel cache ({local_cache})"
    except Exception:
        pass

# 2. Check SteamHunters API
if not achievements:
    try:
        url = f"https://steamhunters.com/api/apps/{appid}/achievements"
        req = urllib.request.Request(url, headers={"User-Agent": "ArchMerOS/1.0"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        for item in data:
            achievements.append({
                "name": item.get("apiName", ""),
                "displayName": item.get("name", ""),
                "description": item.get("description", ""),
                "hidden": "1" if item.get("hidden") else "0",
                "icon": "",
                "icongray": ""
            })
        if achievements:
            source = "SteamHunters API"
    except Exception:
        pass

if achievements:
    print(f"[✓] Retrieved {len(achievements)} achievement definitions via {source}")
else:
    raise SystemExit("Could not retrieve achievement definitions. No game settings were written; retry when the schema is available.")

ini_content = """[main::misc]
achievements_bypass=0
offline=1
"""

for d in sorted(target_dirs):
    settings_dir = os.path.join(d, "steam_settings")
    os.makedirs(settings_dir, exist_ok=True)

    with open(os.path.join(settings_dir, "steam_appid.txt"), "w", encoding="utf-8") as f:
        f.write(f"{appid}\n")

    with open(os.path.join(settings_dir, "configs.main.ini"), "w", encoding="utf-8") as f:
        f.write(ini_content)

    with open(os.path.join(settings_dir, "achievements.json"), "w", encoding="utf-8") as f:
        json.dump(achievements, f, indent=2)

    print(f"[✓] Created Goldberg settings in: {settings_dir}")
    print(f"    • steam_appid.txt -> {appid}")
    print(f"    • configs.main.ini -> achievements_bypass=0, offline=1")
    print(f"    • achievements.json -> {len(achievements)} definitions")

PY

  printf '\n'
  cmd_sync_sentinel

  # Restart warning check if wine/game processes are active
  if pgrep -x wineserver >/dev/null 2>&1; then
    printf '\n[!] IMPORTANT NOTICE:\n'
    printf '    wineserver is currently active. If the game is running, you MUST RESTART THE GAME\n'
    printf '    for the Steam API DLL to load the newly provisioned achievements.json map into memory!\n'
  fi
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
  sync-sentinel)
    cmd_sync_sentinel
    ;;
  setup-achievements)
    shift
    cmd_setup_achievements "$@"
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
