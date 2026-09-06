# Bottles Gaming & Windows Compatibility in ArchMerOS

This directory provides configuration templates, diagnostic tools, and technical documentation for Windows application and game execution via **Bottles** (`com.usebottles.bottles`) on ArchMerOS.

---

## 1. System Architecture

ArchMerOS decouples Windows gaming and Wine prefixes from host system packages by utilizing the Flatpak runtime layer:

* **Host Isolation**: Prevents multilib 32-bit library pollution on rolling-release Arch Linux.
* **Prefix Isolation**: Each game or suite runs in an independent Wine prefix under `~/.var/app/com.usebottles.bottles/data/bottles/bottles/`.
* **Graphics Translation**: Native Vulkan translation pipelines using **DXVK** (DirectX 9/10/11) and **VKD3D-Proton** (DirectX 12).
* **Launch Wrapper**: `config/archmeros/scripts/archmeros-bottles.sh` sets required filesystem permissions and logs invocation history.

---

## 2. Cutscenes & Media Foundation Video Playback

### Root Cause of Video Freezes & Black Screens
Games built on Unreal Engine 4 and modern frameworks utilize **Windows Media Foundation (MF)** or DirectShow to stream in-game cutscenes and bumper videos. In Wine/Proton, these APIs map to `winegstreamer.dll` and the sandboxed Flatpak GStreamer framework (`org.gnome.Platform`).

Flatpak's GStreamer runtime includes hardware-accelerated video decoding plugins:
* `nvh264dec` (NVIDIA NVDEC)
* `vulkanh264dec` (Vulkan Video Extensions)

When Wine requests an H.264 video stream, GStreamer defaults to the highest-ranking decoder (`nvh264dec` or `vulkanh264dec`). However, hardware video decoders inside the Flatpak container output CUDA or GPU device memory buffers. The Wine PE-to-Unix translation layer cannot negotiate raw GPU buffer sharing for Media Foundation source readers, causing the decoder pipeline to stall indefinitely. 

**Symptoms**:
* Game launches and 3D gameplay functions normally.
* Entering any cutscene displays a permanent black screen or a single frozen pixel line.
* Audio may pause or play without video progression.

### The Solution: Software Decoder Fallback
Demoting the rank of hardware decoders forces GStreamer to select `avdec_h264` (CPU/libavcodec decoding). CPU-decoded frames are held in standard system memory, which Wine's Media Foundation implementation transfers directly into DirectX textures without stalls.

To apply this fix, set the following environment variable in the bottle:
```env
GST_PLUGIN_FEATURE_RANK=nvh264dec:NONE,vulkanh264dec:NONE,vulkanh264device1dec:NONE
```

#### Application Methods:
1. **Automated Tool**:
   ```bash
   ~/.config/archmeros/scripts/archmeros-bottles-debug.sh apply-gst-fix "<Bottle_Name>"
   ```
2. **Bottles GUI**:
   * Open the Bottle -> **Settings** -> **Environment Variables**.
   * Add Key: `GST_PLUGIN_FEATURE_RANK`
   * Add Value: `nvh264dec:NONE,vulkanh264dec:NONE,vulkanh264device1dec:NONE`
3. **YAML Configuration (`bottle.yml`)**:
   ```yaml
   Environment_Variables:
       GST_PLUGIN_FEATURE_RANK: nvh264dec:NONE,vulkanh264dec:NONE,vulkanh264device1dec:NONE
   Inherited_Environment_Variables:
   - GST_PLUGIN_FEATURE_RANK
   ```

---

## 3. Repack Video Container & Codec Normalization

Certain PC game repacks (FitGirl, DODI, scene releases) package video files containing QuickTime timecode tracks (`tmcd`) or non-standard pixel formats that crash `MFCreateSourceReaderFromURL` under Wine.

### Normalization Parameters
Re-encoding cutscenes to H.264 Baseline Profile with AAC stereo audio and stripping timecode metadata guarantees seamless playback:
* **Video Codec**: `libx264`
* **Profile / Level**: `baseline`, level `3.1`
* **Pixel Format**: `yuv420p`
* **Audio**: `aac`, stereo (`-ac 2`), 48kHz (`-ar 48000`)
* **Metadata**: `-write_tmcd 0` (strips QuickTime timecode track)

### Batch Remuxing Command:
```bash
~/.config/archmeros/scripts/archmeros-bottles-debug.sh fix-videos "/path/to/game/Movies"
```

Manual FFmpeg one-liner:
```bash
ffmpeg -y -i input.mp4 -c:v libx264 -profile:v baseline -level 3.1 -pix_fmt yuv420p -c:a aac -b:a 192k -ar 48000 -ac 2 -write_tmcd 0 output.mp4
```

---

## 4. Screensaver & DPMS Idle Inhibit

### The Controller Problem
Wayland compositors track idle state exclusively via Wayland seat activity (mouse and keyboard events). Gamepads, flight sticks, and console controllers connect via `evdev`/kernel joystick drivers, which do not generate Wayland seat activity. As a result, `hypridle` would trigger screensavers or power off monitors mid-game.

### Dual-Layer Inhibit Architecture

1. **Hyprland Window Rules (`config/hypr/hyprland.lua` and `hyprland.conf`)**:
   * Windows matching Bottles (`com.usebottles.bottles`) or Wine game executables (`.*\.exe`, `wine`, `steam_proton`, `gamescope`) are assigned `idle_inhibit = "always"`.
   * Hyprland broadcasts the Wayland idle inhibitor protocol to `hypridle`, pausing the idle timer while game windows are open.

2. **Session Script Gatekeeper (`config/archmeros/scripts/archmeros-idle-media-active.sh`)**:
   * Before launching the screensaver (`archmeros-screensaver.sh`) or cutting display power (`archmeros-dpms-off.sh`), ArchMerOS evaluates `archmeros-idle-media-active.sh`.
   * The script checks:
     - Active Flatpak Bottles instances (`flatpak ps | grep com.usebottles.bottles`)
     - Active Bottles wrapper processes (`pgrep -f com.usebottles.bottles`)
     - Active Wine server instances (`pgrep -x wineserver`)
     - Active Wine/Proton game processes (`pgrep -f '(wine64-preloader|wine-preloader|steam_proton|gamescope)'`)
     - Active media players via `playerctl`
   * If any condition is met, the script exits `0`, immediately aborting screensaver activation and DPMS shutdown.

---

## 5. Storage & Drive Letter Mappings

To access games stored on secondary drives (e.g. NTFS/ext4 drives mounted at `/mnt/windows-ssd`):

1. **Grant Flatpak Filesystem Permission**:
   ```bash
   flatpak override --user --filesystem=/mnt/windows-ssd com.usebottles.bottles
   ```
2. **Map Windows Drive Letter in Wine Prefix**:
   ```bash
   ~/.config/archmeros/scripts/archmeros-bottles-debug.sh link-drive <Bottle_Name> d /mnt/windows-ssd/Games
   ```
   Or manually:
   ```bash
   ln -sfn /mnt/windows-ssd/Games ~/.var/app/com.usebottles.bottles/data/bottles/bottles/<Bottle_Name>/dosdevices/d:
   ```

---

## 6. Recommended Runner & Bottle Settings

| Option | Recommended Value | Notes |
| :--- | :--- | :--- |
| **Environment** | `Gaming` | Automatically enables DXVK, VKD3D, and Fsync |
| **Runner** | `protosoda-11.0-2` | Valve Proton patches with Soda Flatpak runtime integration |
| **DXVK** | Enabled (`dxvk-3.1`) | DirectX 9/10/11 translation to Vulkan |
| **VKD3D** | Enabled (`vkd3d-proton-3.0.1`) | DirectX 12 translation to Vulkan |
| **Sync** | `fsync` | Low-overhead kernel eventfd synchronization |
| **Discrete GPU** | Enabled | Directs Vulkan ICD to high-performance GPU |
| **Dependencies** | `d3dcompiler_43`, `d3dcompiler_47`, `d3dx9`, `mono`, `gecko` | Essential DirectX HLSL compilers and runtime hooks |

Use `bottle-gaming-template.yml` in this directory as a reference configuration when provisioning new bottles.

---

## 7. Diagnostic Utility Cheat Sheet

The ArchMerOS Bottles diagnostic utility is located at `config/bottles/scripts/archmeros-bottles-debug.sh` (symlinked to `~/.config/archmeros/scripts/archmeros-bottles-debug.sh`).

```bash
# View complete environment, prefix status, and screensaver inhibit state
archmeros-bottles-debug.sh status

# Apply GStreamer NVDEC/Vulkan demotion to fix black screen cutscenes
archmeros-bottles-debug.sh apply-gst-fix "Spyro"

# Map an external drive to a Wine drive letter
archmeros-bottles-debug.sh link-drive "Spyro" d "/mnt/windows-ssd/Games"

# Batch-fix and remux cutscenes in a game directory
archmeros-bottles-debug.sh fix-videos "/mnt/windows-ssd/Games/Spyro Reignited Trilogy/Falcon/Content/Movies"
```
