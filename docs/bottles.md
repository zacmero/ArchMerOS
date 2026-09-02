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
| **Desktop Entry** | `local/share/applications/com.usebottles.bottles.desktop` | Symlinked to `~/.local/share/applications/` with fallback `bottles.desktop` |
| **Icons** | `vendor/papirus-icon-theme` / `ArchMerOS-Icons` | Standard SVG icon integration inheriting from Papirus-Dark / system theme |
| **Hyprland Rules** | `config/hypr/hyprland.conf` | Window rules for centered floating presentation (`72% 76%`) with matching opacity |

---

## 2. Gaming Workflow & Patched Game Management

Bottles provides sandbox-safe, per-game isolated prefixes ("Bottles") without polluting the user's home directory.

### Recommended Gaming Configuration:

1. **Creating a Bottle for Patched Games**:
   * Click **Create new Bottle**.
   * Select **Gaming** environment (automatically enables **DXVK**, **VKD3D**, and Esync/Fsync).
   * Runner recommendation: **soda** (default) or download **GE-Proton** / **Caffe** under *Preferences > Runners*.

2. **Installing Dependencies & Runtimes**:
   * Under the bottle's **Dependencies** tab, install common prerequisites for patched games:
     * `vcredist2015-2022` / `vcredist2019`
     * `d3dcompiler_47` / `d3dx9`
     * `dotnet48` (if the game launcher requires .NET)
     * `physx` (for older DirectX titles)

3. **Running Patched Games & EXEs**:
   * **Run Executable**: Use the **Run Executable** button to select the game's patched `.exe` or installer.
   * **Add Shortcut**: Once installed, add the main game executable to the bottle's shortcut list for single-click launching from Bottles or desktop shortcuts.

4. **Performance & Overlay Features**:
   * **MangoHud**: Built-in toggle in Bottle settings for FPS, frametime, and GPU/CPU stats.
   * **FSR (FidelityFX Super Resolution)**: Enable upscale in Bottle display settings for lower resolution scaling.
   * **Gamescope**: Available for resolution containment and micro-stutter reduction.

---

## 3. Storage & State Locations

* **Bottles & Prefixes Data**: `~/.var/app/com.usebottles.bottles/data/bottles/bottles/`
* **Runners & DXVK Cache**: `~/.var/app/com.usebottles.bottles/data/bottles/runners/`
* **Configuration & Preferences**: `~/.var/app/com.usebottles.bottles/config/`

---

## 4. Verification & Diagnostics

To verify the installation and launch Bottles:

```bash
# Check Flatpak installation
flatpak info com.usebottles.bottles

# Run via ArchMerOS launcher wrapper
~/.config/archmeros/scripts/archmeros-bottles.sh
```
