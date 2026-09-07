# Bottles Gaming & Windows Compatibility in ArchMerOS

ArchMerOS integrates **Bottles** (`com.usebottles.bottles`) as a first-class default application for running patched Windows games, standalone executable tools, and legacy software with isolated Wine/Proton prefixes, DXVK, and VKD3D graphics translation layers.

---

## 1. Architecture & Ownership

ArchMerOS manages Bottles through the Flatpak runtime layer to decouple Wine dependencies, 32-bit graphics libraries, and runner toolchains from the host rolling-release system.

### Factory-Owned Files

| Concern | Repository Source | Installation / Runtime Behavior |
| :--- | :--- | :--- |
| **Package Manifest** | `install/packages/flatpak.txt` | Tracked in `flatpak.txt` and installed via `install/packages/install.sh` |
| **Launcher Script** | `config/archmeros/scripts/archmeros-bottles.sh` | Symlinked to `~/.config/archmeros/scripts/archmeros-bottles.sh`, tracks history via `archmeros-reopen-history.py` |
| **Diagnostic Tool** | `config/bottles/scripts/archmeros-bottles-debug.sh` | Symlinked to `~/.config/archmeros/scripts/archmeros-bottles-debug.sh`, inspects status, applies GST fixes, and links drives |
| **Bottle Template** | `config/bottles/bottle-gaming-template.yml` | Base reference configuration with GStreamer software fallback and DXVK/VKD3D enabled |
| **Desktop Entry** | `local/share/applications/com.usebottles.bottles.desktop` | Symlinked to `~/.local/share/applications/` with fallback `bottles.desktop` |
| **Icons** | `vendor/papirus-icon-theme` / `ArchMerOS-Icons` | Standard SVG icon integration inheriting from Papirus-Dark / system theme |
| **Hyprland Rules** | `config/hypr/hyprland.lua` & `hyprland.conf` | Centered floating presentation (`72% 76%`) with `idle_inhibit = "always"` |
| **Idle Gatekeeper** | `config/archmeros/scripts/archmeros-idle-media-active.sh` | Actively blocks screensaver and DPMS standby while Bottles or Wine games run |
| **Sentinel Daemon** | `config/systemd/user/archmeros-sentinel.service` | Real-time achievement monitoring daemon, started on demand by the Bottles wrapper |
| **Sentinel Config** | `config/sentinel/config.json` | Symlinked to `~/.config/sentinel/config.json`, tracks monitored Wine bottle prefixes |
| **Sentinel Desktop** | `local/share/applications/sentinel.desktop` | Application launcher for Sentinel achievement dashboard |

---

## 2. Gaming Workflow & Patched Game Management

Bottles provides sandbox-safe, per-game isolated prefixes ("Bottles") without polluting the user's home directory. Detailed configuration steps and troubleshooting guides are available in [config/bottles/README.md](/home/zacmero/projects/ArchMerOS/config/bottles/README.md).

### Recommended Gaming Configuration:

1. **Creating a Bottle for Patched Games**:
   * Click **Create new Bottle**.
   * Select **Gaming** environment (automatically enables **DXVK**, **VKD3D**, and Esync/Fsync).
   * Runner recommendation: **protosoda-11.0-2** (default for gaming) or **soda** / **GE-Proton**.

2. **Fixing Cutscene & Video Stalling (Media Foundation / GStreamer)**:
   * Flatpak GStreamer hardware decoders (`nvh264dec`, `vulkanh264dec`) fail to negotiate device memory sharing across Wine's PE boundary, causing black screens or 1-pixel scanlines during game cutscenes.
   * Fix: Inject software decoding rank overrides into the bottle:
     ```bash
     archmeros-bottles-debug.sh apply-gst-fix "<Bottle_Name>"
     ```
   * This sets `GST_PLUGIN_FEATURE_RANK=nvh264dec:NONE,vulkanh264dec:NONE,vulkanh264device1dec:NONE`, allowing CPU decoding (`avdec_h264`) directly into system memory.

3. **Repack Video Container Normalization**:
   * For games with corrupted QuickTime timecode tracks (`tmcd`) or non-baseline video profiles, remux with:
     ```bash
     archmeros-bottles-debug.sh fix-videos "/path/to/game/Movies"
     ```

4. **Screensaver & DPMS Inhibit**:
   * Wayland compositors do not recognize gamepad inputs as seat activity. ArchMerOS uses dual-layer inhibition:
     - Hyprland window rules automatically inhibit idle for `com.usebottles.bottles` and any `.exe`/Wine game window.
     - `archmeros-idle-media-active.sh` checks for active Bottles Flatpaks, `wineserver`, and game processes, aborting `archmeros-screensaver.sh` and `archmeros-dpms-off.sh`.

5. **Installing Dependencies & Runtimes**:
   * Under the bottle's **Dependencies** tab, install common prerequisites:
     * `d3dcompiler_43` & `d3dcompiler_47`
     * `d3dx9`
     * `vcredist2015-2022` / `vcredist2019`
     * `mono` & `gecko`

6. **Running Patched Games & EXEs**:
   * **Run Executable**: Use the **Run Executable** button to select the game's patched `.exe` or installer.
   * **Add Shortcut**: Once installed, add the main game executable to the bottle's shortcut list for single-click launching.

7. **Offline Achievement Tracking & On-Screen Toasts (Sentinel)**:
   * ArchMerOS integrates **Sentinel** to automatically detect achievements unlocked by Wine/Proton games using Steam emulators (Goldberg, GSE, Codex, Rune).
   - Automated setup for any game:
     ```bash
     archmeros-bottles-debug.sh setup-achievements "<path_to_game_or_bottle_name>" <steam_appid>
     ```
   - This automatically fetches the achievement schema, generates `steam_settings/achievements.json`, configures `achievements_bypass=0`, and registers the Bottle with Sentinel. Missing definitions abort setup without writing game settings. Bypass must stay disabled for real achievement persistence and live watcher events.
   - When an achievement triggers, Sentinel immediately pops a desktop notification with badge icon and plays a sound (`steam-deck.wav`). Unlocked progress is browsable via the Sentinel dashboard.

---

## 3. Storage & State Locations

* **Bottles & Prefixes Data**: `~/.var/app/com.usebottles.bottles/data/bottles/bottles/`
* **Runners & DXVK Cache**: `~/.var/app/com.usebottles.bottles/data/bottles/runners/`
* **Configuration & Preferences**: `~/.var/app/com.usebottles.bottles/config/`
* **ArchMerOS Configuration Templates**: `config/bottles/`
* **Sentinel Achievement Definitions & Cache**: `~/.local/share/sentinel/games/`

---

## 4. Verification & Diagnostics

ArchMerOS ships an all-in-one diagnostic and configuration tool:

```bash
# Check Bottles health, filesystem overrides, and prefix configuration
archmeros-bottles-debug.sh status

# Link an external game mount to a Windows drive letter
archmeros-bottles-debug.sh link-drive "<Bottle_Name>" d "/mnt/windows-ssd/Games"

# Sync all Bottles prefixes into Sentinel achievement watcher
archmeros-bottles-debug.sh sync-sentinel

# Automatically provision Goldberg achievement definitions with persistence enabled
archmeros-bottles-debug.sh setup-achievements "<path_or_bottle>" <steam_appid>

# Launch Bottles GUI via ArchMerOS wrapper
archmeros-bottles.sh
```

## Installation and Automatic Startup

`install/packages/install.sh` installs Bottles from Flathub and Sentinel from
the upstream `RemakeCode/sentinel` v1.0.8 Arch package through
`install/packages/sentinel/install.sh`. The installer verifies a pinned SHA-256
before `pacman -U`; update the version and digest together after validation.
Use `bash install/packages/sentinel/install.sh --verify-only` to verify the
download without installing it. Upstream installs to `/usr/local/bin/sentinel`;
the user service also supports the existing `~/.local/bin/sentinel` installation.

Open Bottles through its ArchMerOS launcher and launch the game normally. The
launcher synchronizes bottle prefixes and starts Sentinel automatically. No
manual achievement setup is needed each time for an already configured game.
Sentinel is not enabled at login (`startOnLogin=false`, no Hyprland exec-once,
no enabled systemd target link). It remains running after Bottles opens until
logout, so closing the Bottles window does not interrupt a running game's
notifications.

Walker game shortcuts are covered too: Elephant's tracked launch prefix runs
`archmeros-walker-launch.sh` before the existing `uwsm-app --` launch path.
It recognizes Flatpak commands targeting `com.usebottles.bottles` and native
`bottles` / `bottles-cli` commands, synchronizes prefixes, and starts Sentinel
before launching. This includes existing and future Bottles game shortcuts;
individual desktop files do not need rewriting. Other applications retain
their command arguments and the normal UWSM launch path. Installation links
`config/elephant/elephant.toml` into the user configuration.

A raw Wine/Flatpak command executed outside Walker or the ArchMerOS Bottles
launcher bypasses these hooks; start Bottles first in that case. Starting the
watcher does not add achievement support to games with incompatible sources.

## Spyro Repair and Verification (2026-09-06)

Spyro (Steam AppID `996580`) now produces live achievement notifications,
confirmed by gameplay. Two conditions were required:

- Sentinel emulator entries need explicit relative `path` values. Without
  these, its watcher can start with `paths=[]` and observe no achievements.
- GSE must use `achievements_bypass=0`. Bypass can report success to the game
  without persisting the unlock, leaving Sentinel with no file event to read.

All four existing `steam_settings/configs.main.ini` files (game root, Falcon
Win64, Steamworks Win64, and bottle root) were backed up beside the originals
as `configs.main.ini.before-achievement-repair` and corrected. The provisioner
now disables bypass and aborts before writing settings if definitions cannot
be obtained. The Steamworks settings contained 105 definitions, including
`ACHIEVEMENT_5`. Sentinel's live log confirmed watches on Spyro's Goldberg/GSE
save directories. Saves and earned-achievement records were not edited.

Restart a game normally after changing its emulator settings; they are read
at process startup. A previously discarded unlock may need its condition
triggered again. Do not fake achievement JSON writes as a gameplay test.

## Achievement Notification Placement

Sentinel's systemd service prepends `~/.config/sentinel/bin` to its PATH.
Its small `notify-send` adapter adds category `archmeros-achievement` while
preserving the upstream game name, urgency, body and returned notification ID.
Mako routes this category to the center monitor (`HDMI-A-1`) on the overlay
layer for 15 seconds, independent of keyboard focus. Other notifications keep
their existing routing and timeout. Update this output name if monitors change.
The focus-dismiss helper exempts critical notifications, including trophies.

This avoids patching Sentinel itself. A tagged display test was verified on
Hyprland layer 3 on HDMI-A-1. Both "Using Your Head" and "Warm up the Crowd"
were present in Mako history before this change; missing visibility was not a
missing achievement record. No game restart is required after this adjustment.

## There Is No Light

The existing `ThereIsNoLight` bottle is registered with Sentinel. The installed
copy is the GOG edition in `drive_c/GOG Games/There Is No Light`. Its bundled
Steam API DLL identifies as Valve's original library, and no compatible
`achievements.json` save state was found. Registration alone cannot produce
unlocks: Sentinel v1.0.8 watches emulator JSON state, not arbitrary game saves
or GOG Galaxy achievements. This game's saves and DLLs were left intact.

Tracking this edition needs an actual compatible achievement event source;
adding a Steam AppID or schema alone is insufficient. The Spyro success does
not establish compatibility for other games.
