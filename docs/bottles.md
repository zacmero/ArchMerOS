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

---

## 3. Storage & State Locations

* **Bottles & Prefixes Data**: `~/.var/app/com.usebottles.bottles/data/bottles/bottles/`
* **Runners & DXVK Cache**: `~/.var/app/com.usebottles.bottles/data/bottles/runners/`
* **Configuration & Preferences**: `~/.var/app/com.usebottles.bottles/config/`
* **ArchMerOS Configuration Templates**: `config/bottles/`

---

## 4. Verification & Diagnostics

ArchMerOS ships an all-in-one diagnostic and configuration tool:

```bash
# Check Bottles health, filesystem overrides, and prefix configuration
archmeros-bottles-debug.sh status

# Link an external game mount to a Windows drive letter
archmeros-bottles-debug.sh link-drive "<Bottle_Name>" d "/mnt/windows-ssd/Games"

# Launch Bottles GUI via ArchMerOS wrapper
archmeros-bottles.sh
```
