# ArchMerOS

ArchMerOS is a personal Arch-based workstation build for coding and creative work.

The goal is not to make a generic distro. The goal is to build a fast, elegant, security-conscious system with a strong visual identity and a terminal-centered workflow. The visual direction is cyberpunk, 80s, and heavy metal, but executed with restraint: deep blues, pinks, purples, transparency, contrast, and motion used carefully enough to stay timeless and comfortable for long sessions.

This project starts from an existing EndeavourOS machine and incrementally replaces its defaults until the system becomes ArchMerOS in practice.

This `README.md` is the living operator guide for the machine state. As ArchMerOS evolves, the real deployment steps, current session commands, and active keybindings should be documented here instead of being left only in chat history.

## Principles

- Terminal-centered workflow first
- Strong aesthetics without bloat
- Modularity over monoliths
- Security and stability over novelty
- Arch-specific composition, not cross-distro sprawl
- Explicit boundaries between ArchMerOS and portable upstream tools

## Scope

ArchMerOS owns the operating-system composition layer:

- Hyprland session behavior
- bars, launchers, notifications, theming, wallpapers, fonts, cursors
- package manifests and bootstrap/install scripts
- app configuration and workflow integration
- host and profile customization for this machine and future ArchMerOS installs

ArchMerOS does not own portable upstream tools.

The main example is `mero_terminal`. It is a separate, distro-agnostic project and remains the centerpiece of the workflow, but any change to its source, defaults, or installation behavior must be approved explicitly and handled in its own repository.

## Current Direction

- Base environment: Arch Linux workflow on top of current EndeavourOS install
- Window manager: Hyprland
- Focus: speed, aesthetics, modularity, adaptability, performance, security
- Tooling policy: prefer established software over fragile or highly experimental components
- File manager choice: intentionally undecided for now

## Current Machine State

Current known state on this workstation:

- XFCE remains installed as fallback
- Hyprland is installed and usable
- live user configs are symlinked from this repo into `~/.config`
- Walker is the general launcher
- Walker providers are installed through Elephant and started as user services from Hyprland
- `Super+E` syncs the trusted Windows Desktop intersection into `~/Desktop` and opens `thunar`
- `rofi` remains available as the launcher fallback if Walker fails
- new login-shell Bash sessions source an ArchMerOS shell hook from `~/.bash_profile`
- local GTK, cursor, and icon theme assets are deployed under `~/.local/share`
- the active Firefox `default-release` profile can be fed from a repo-owned `user.js`
- `mero_terminal` remains separate and untouched

Current three-monitor intent:

- left monitor: terminal / agent anchor
- center monitor: main coding workspaces
- right monitor: media / utility / reference windows

## Repository Role

This repository should become a reproducible ArchMerOS setup layer.

That means:

- version-controlled configs
- version-controlled package selections
- version-controlled install/bootstrap scripts
- symlink-based deployment into live config locations
- documented architectural decisions
- clean integration points for external tools such as `mero_terminal`

It should not become a dumping ground for unrelated upstream source trees.

## Live Deployment Model

ArchMerOS deploys by symlink, not by copying config trees.

Rule:

- every live config file used by ArchMerOS must be version controlled inside this repository
- every live config location must point back here via symlink
- if a config is active but not tracked here, it is incomplete and must be brought into the repo

Tracked repo config:

- [config/hypr](/home/zacmero/projects/ArchMerOS/config/hypr)
- [config/waybar](/home/zacmero/projects/ArchMerOS/config/waybar)
- [config/rofi](/home/zacmero/projects/ArchMerOS/config/rofi)
- [config/walker](/home/zacmero/projects/ArchMerOS/config/walker)
- [config/mako](/home/zacmero/projects/ArchMerOS/config/mako)
- [config/archmeros](/home/zacmero/projects/ArchMerOS/config/archmeros)
- [config/easyeffects](/home/zacmero/projects/ArchMerOS/config/easyeffects)
- [config/gtk-3.0](/home/zacmero/projects/ArchMerOS/config/gtk-3.0)
- [config/gtk-4.0](/home/zacmero/projects/ArchMerOS/config/gtk-4.0)
- [config/systemd/user](/home/zacmero/projects/ArchMerOS/config/systemd/user)
- [config/firefox](/home/zacmero/projects/ArchMerOS/config/firefox)

Live targets:

- `~/.config/hypr`
- `~/.config/waybar`
- `~/.config/rofi`
- `~/.config/walker`
- `~/.config/mako`
- `~/.config/archmeros`
- `~/.config/gtk-3.0`
- `~/.config/gtk-4.0`
- `~/.config/systemd/user`

## Current Setup Steps

These are the current machine bring-up steps as of the present ArchMerOS state.

1. Link tracked configs into the live session:

```bash
./install/link.sh
```

2. Install user-local theme assets without depending on root package installs:

```bash
./install/local-theme-assets.sh
```

This populates:

- `~/.local/share/themes`
- `~/.local/share/icons`

3. Log into the Hyprland session from the display manager.

4. From inside a Hyprland terminal, refresh the shell components with the tracked helper:

```bash
~/.config/archmeros/scripts/archmeros-refresh-shell.sh
```

This helper auto-detects the active Hyprland socket, reloads Hyprland, restarts Waybar, and reapplies the wallpaper in the current graphical session.

5. Restart GTK apps such as `thunar` after theme changes so they pick up the active GTK/icon/cursor settings.

## Current Visual Stack

Active shell pieces currently tracked in this repo:

- Hyprland: [config/hypr/hyprland.conf](/home/zacmero/projects/ArchMerOS/config/hypr/hyprland.conf)
- Waybar: [config/waybar/config.jsonc](/home/zacmero/projects/ArchMerOS/config/waybar/config.jsonc)
- Waybar style: [config/waybar/style.css](/home/zacmero/projects/ArchMerOS/config/waybar/style.css)
- Walker theme: [config/walker/themes/archmeros/style.css](/home/zacmero/projects/ArchMerOS/config/walker/themes/archmeros/style.css)
- Rofi launcher: [config/rofi/launchers/drun.rasi](/home/zacmero/projects/ArchMerOS/config/rofi/launchers/drun.rasi)
- Wallpapers: [config/wallpapers](/home/zacmero/projects/ArchMerOS/config/wallpapers)
- Wallpaper loader: [config/archmeros/scripts/archmeros-wallpaper.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-wallpaper.sh)
- Wallpaper picker: [config/archmeros/scripts/archmeros-wallpaper-pick.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-wallpaper-pick.sh)
- Window pop helper: [config/archmeros/scripts/archmeros-window-pop.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-window-pop.sh)
- Window close helper: [config/archmeros/scripts/archmeros-close.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-close.sh)
- Keyboard indicator helper: [config/archmeros/scripts/archmeros-keyboard.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-keyboard.sh)
- Transparency preset switcher: [config/archmeros/scripts/archmeros-transparency.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-transparency.sh)
- Thunar launcher wrapper: [config/archmeros/scripts/archmeros-thunar.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-thunar.sh)
- Walker launcher wrapper: [config/archmeros/scripts/archmeros-walker.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-walker.sh)
- Window history cycle helper: [config/archmeros/scripts/archmeros-cycle-window.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-cycle-window.sh)
- Bash hook: [config/archmeros/shell/archmeros-bash.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/shell/archmeros-bash.sh)
- Walker service units: [config/systemd/user/archmeros-elephant.service](/home/zacmero/projects/ArchMerOS/config/systemd/user/archmeros-elephant.service), [config/systemd/user/archmeros-walker.service](/home/zacmero/projects/ArchMerOS/config/systemd/user/archmeros-walker.service)

Theme direction currently applied:

- GTK theme: `catppuccin-frappe-blue-standard+default`
- icon theme: `Papirus-Dark`
- cursor theme: `Bibata-Modern-Amber`

Wallpaper backend:

- preferred: `swaybg`
- fallback: `hyprpaper`

## Current Transparency Presets

Hyprland transparency and blur are now sourced from:

- [config/hypr/transparency.conf](/home/zacmero/projects/ArchMerOS/config/hypr/transparency.conf)

Tracked presets:

- [transparency-work-clean.conf](/home/zacmero/projects/ArchMerOS/config/hypr/presets/transparency-work-clean.conf)
- [transparency-night-cyber.conf](/home/zacmero/projects/ArchMerOS/config/hypr/presets/transparency-night-cyber.conf)

Current recommendation:

- `work-clean`: light transparency, restrained blur, better for coding
- `night-cyber`: stronger transparency across terminal, code, Thunar, and Walker, with blur carrying readability instead of darkening the whole surface

To switch later:

```bash
~/.config/archmeros/scripts/archmeros-transparency.sh
```

or directly:

```bash
~/.config/archmeros/scripts/archmeros-transparency.sh apply work-clean
~/.config/archmeros/scripts/archmeros-transparency.sh apply night-cyber
```

## Current Wallpaper Resolution

ArchMerOS now keeps its default wallpapers inside this repository:

- [config/wallpapers](/home/zacmero/projects/ArchMerOS/config/wallpapers)

Current wallpaper selection behavior:

1. ArchMerOS stores persistent per-monitor wallpaper state in `~/.local/state/archmeros/wallpapers.json`
2. if there is no saved wallpaper state yet, it seeds monitor defaults from [config/archmeros/defaults/wallpapers.json](/home/zacmero/projects/ArchMerOS/config/archmeros/defaults/wallpapers.json)
3. if there is still no monitor mapping, it falls back to the first wallpaper in the repo-local `config/wallpapers`

This avoids depending on the Windows-backed project drive at runtime.

To change wallpaper manually:

```bash
~/.config/archmeros/scripts/archmeros-wallpaper-pick.sh
```

or use the keybinding:

- `Super+Alt+W`

The wallpaper picker now asks for a target first:

- `All monitors`
- or one specific monitor such as `DP-2`, `HDMI-A-4`, or `VGA-1`

## Current Appearance Control

ArchMerOS now has a repo-owned appearance controller:

```bash
~/.config/archmeros/scripts/archmeros-appearance.sh
```

or use:

- `Super+Alt+A`

Appearance actions currently available:

- `Default colors`: restore the default ArchMerOS palette
- `Auto colors from current wallpapers`: regenerate the shell colors from the active wallpapers
- `Apply saved preset`: switch to a saved preset from [themes/presets](/home/zacmero/projects/ArchMerOS/themes/presets)
- `Save current auto colors as preset`: create a new preset file in [themes/presets](/home/zacmero/projects/ArchMerOS/themes/presets)
- `Pick wallpapers per monitor`: open the wallpaper target selector
- `Reapply current appearance`: rebuild the active appearance files and refresh the shell

Current generated appearance targets:

- [config/hypr/theme.conf](/home/zacmero/projects/ArchMerOS/config/hypr/theme.conf)
- [config/waybar/colors.css](/home/zacmero/projects/ArchMerOS/config/waybar/colors.css)
- [config/rofi/colors.rasi](/home/zacmero/projects/ArchMerOS/config/rofi/colors.rasi)
- [config/walker/themes/archmeros/style.css](/home/zacmero/projects/ArchMerOS/config/walker/themes/archmeros/style.css)
- [config/mako/config](/home/zacmero/projects/ArchMerOS/config/mako/config)

Appearance state is stored in:

- `~/.local/state/archmeros/appearance.json`
- [themes/generated/current.json](/home/zacmero/projects/ArchMerOS/themes/generated/current.json)

Current auto palette rule:

- center monitor wallpaper drives the primary accent
- left monitor wallpaper drives the secondary accent
- right monitor wallpaper drives the tertiary accent
- dark surfaces are tinted from the active wallpaper set so auto mode is visually obvious instead of nearly identical to the default palette

## Current Waybar Behavior

Waybar is currently back on the stable baseline launch path:

- `waybar -c ~/.config/waybar/config.jsonc -s ~/.config/waybar/style.css`

The Bluetooth module is intentionally removed from the top connectivity group because the tray already exposes Bluetooth status. The old Bluetooth number was `num_connections`, meaning the count of connected Bluetooth devices.

## Current Keybindings

These are the bindings that should be treated as current ArchMerOS behavior unless changed deliberately.

- `Ctrl+Alt+T`: open terminal
- `Super+Return`: open terminal
- `Super+Space`: launcher
- `Super+E`: PARA hub / file access
- `Alt+F1` to `Alt+F4`: switch main workspaces
- `Ctrl+Alt+Left` / `Ctrl+Alt+Right`: cycle workspaces
- `Super+H/J/K/L`: move focus
- `Super+Left/Right/Up/Down`: move focus
- `Alt+Tab`: cycle to next window on the active workspace
- `Alt+Shift+Tab`: cycle to previous window
- `Alt+Tab`: toggle between the current window and the previously focused window, while handing the centered spotlight state across when applicable
- `Super+Tab`: cycle across all windows on the current workspace/screen, while handing the centered spotlight state across when applicable
- `Super+Shift+Left/Right/Up/Down`: swap windows
- `Shift + Left Mouse`: drag a window
- `Shift + Right Mouse`: resize a window
- `Super+V`: toggle floating
- `Super+P`: pseudotile
- `Super+F`: fullscreen
- `Super+C`: pop focused window out, center it, float it, and pin it
- `Super+O`: pop focused window into a large near-full centered mode
- `Super+Shift+O`: pop focused window into a medium centered mode
- `Super+Shift+P`: open display settings helper
- `Super+Shift+B`: refresh Hyprland shell components
- `Super+Alt+W`: open wallpaper picker
- `Super+Alt+A`: open appearance controller
- `Super+Alt+S`: open the audio effects UI
- `Left Alt+W`: close current app window while keeping `Right Alt` free for ABNT2 characters
- click the Waybar keyboard indicator: toggle keyboard layout
- `XF86AudioRaiseVolume`: raise volume
- `XF86AudioLowerVolume`: lower volume
- `XF86AudioMute`: toggle mute
- `Super+]`: raise volume
- `Super+[`: lower volume
- `Super+\`: toggle mute
- `Ctrl+Alt+Space`: rotate keyboard layout
- `Alt+Shift`: rotate keyboard layout through XKB

## Current Volume Control

Waybar volume behavior:

- click the volume module: open `pavucontrol`
- right-click the volume module: toggle mute
- scroll on the volume module: raise or lower volume by the configured step

Direct commands:

- `wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+`
- `wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-`
- `wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle`

Audio UI command:

- `~/.config/archmeros/scripts/archmeros-audio.sh`

## Current App Launch Note

The general launcher path is now:

- `Super+Space` -> [config/archmeros/scripts/archmeros-launcher.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-launcher.sh)
- `Super+Shift+Space` -> `rofi` backup launcher
- launcher wrapper -> [config/archmeros/scripts/archmeros-walker.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-walker.sh)
- wrapper starts the tracked user services:
  - [config/systemd/user/archmeros-elephant.service](/home/zacmero/projects/ArchMerOS/config/systemd/user/archmeros-elephant.service)
  - [config/systemd/user/archmeros-walker.service](/home/zacmero/projects/ArchMerOS/config/systemd/user/archmeros-walker.service)
- Walker opens as a normal centered floating window instead of the oversized frame-like layer shell surface
- Walker sizing is controlled by Hyprland window rules for class `dev.benz.walker`

If you need to launch a GUI app from a terminal without tying it to that terminal session, use:

```bash
~/.config/archmeros/scripts/archmeros-detach.sh mousepad
```

Replace `mousepad` with any GUI command you want to detach.

## Current Shell GUI Behavior

New login-shell Bash sessions source:

- [config/archmeros/shell/archmeros-bash.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/shell/archmeros-bash.sh)

Current behavior:

- when you launch a simple GUI app command from a WezTerm Bash shell, ArchMerOS detaches it with `setsid` and closes that shell
- this is meant to stop GUI apps from dying when the terminal window closes
- it only targets simple direct commands, not pipelines or compound shell syntax
- to disable it for one shell session, run:

```bash
export ARCHMEROS_GUI_DETACH_DISABLED=1
```

## Current Keyboard Layout Policy

Hyprland is currently configured for:

- `us`
- `br(abnt2)`

This gives a rotating English / ABNT2 setup while keeping the rest of the session on the same config.

Current XKB option policy:

- `grp:alt_shift_toggle`
- `lvl3:ralt_switch`

This keeps `Right Alt` acting as `AltGr` for the ABNT2 layout, including the native `br(abnt2)` level-3 symbols on `Q` and `W` such as `/` and `?`.

## Firefox Overrides

Repo-owned Firefox overrides live in:

- [config/firefox/user.js](/home/zacmero/projects/ArchMerOS/config/firefox/user.js)

Current managed prefs:

- `full-screen-api.enabled = true`
- `full-screen-api.ignore-widgets = false`

The linker attaches this file to the active `default-release` profile when present.

## Audio Stack

ArchMerOS uses PipeWire, so the correct real-time system-wide EQ path is EasyEffects plus plugin packs, not a custom toy DSP app.

Tracked audio package list:

- [install/packages/audio.txt](/home/zacmero/projects/ArchMerOS/install/packages/audio.txt)

Tracked audio launcher:

- [config/archmeros/scripts/archmeros-audio.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-audio.sh)

Tracked audio config root:

- [config/easyeffects](/home/zacmero/projects/ArchMerOS/config/easyeffects)

Current intent:

- `easyeffects` for system-wide playback processing
- `lsp-plugins` and `calf` for broader EQ and studio-oriented filters
- `qpwgraph` for routing inspection when needed

## Current PARA Rule

The Windows Desktop is the shared intersection between Windows and ArchMerOS.

Current PARA entrypoints:

- [config/archmeros/scripts/archmeros-para.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-para.sh)
- [config/archmeros/scripts/archmeros-desktop-sync.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-desktop-sync.sh)

Current behavior:

- the trusted Windows volume is intended to automount by UUID
- the stable shared desktop path is `/mnt/windows-desktop`
- `Super+E` syncs `/mnt/windows-desktop` into `~/Desktop`, then opens `thunar`
- this keeps current and future Windows Desktop files and folders visible on Linux
- sync filters out Windows-only shortcut clutter:
  - `*.lnk`
  - `desktop.ini`
  - `Trash`
  - `softwares`
- local Linux files already present in `~/Desktop` are left alone
- Walker is kept for app/command launching, not for PARA drag-and-drop, until a better picker exists
- `thunar` is explicitly resized after launch to the same proportions as the `Super+Shift+O` medium pop mode
- the Thunar wrapper now polls for the real client before resizing so the medium geometry survives reused Thunar processes too
- after that it behaves like a normal floating window and can still be tiled normally
- Walker now uses a repo-owned local `thunar.desktop` override that launches through the same Thunar wrapper

Current known PARA roots:

- `~/Desktop/1_Projects`
- `~/Desktop/2. Areas`
- `~/Desktop/3. Resources`
- `~/Desktop/4. Archives`

Manual refresh command:

```bash
~/.config/archmeros/scripts/archmeros-desktop-sync.sh
```

## Build Log

This section should be updated as the system changes.

Completed so far:

- established repo structure and architecture docs
- installed Hyprland while preserving XFCE fallback
- moved to symlink-based config deployment
- installed Walker for app launch
- installed Elephant provider packages for Walker
- created tracked Waybar, Rofi, Mako, Walker, and Hyprland configs
- added a PARA hub script
- added a wallpaper loader script
- copied the Windows ArchMerOS wallpaper set into `config/wallpapers`
- changed wallpaper resolution to prefer the local repo copy
- added a wallpaper picker command and keybinding
- added persistent per-monitor wallpaper state and monitor-targeted wallpaper picking
- corrected mouse drag/resize binds to use `bindm`
- added a trusted Windows Desktop sync path for `Super+E` based on `/mnt/windows-desktop`
- added a trusted UUID automount for the Windows Desktop volume at `/mnt/windows-ssd`
- added a repo-owned Firefox `user.js` override to restore browser fullscreen support
- switched the live wallpaper backend to `swaybg` for reliability
- added a centered pop-out / pin helper for focused windows
- split the pop-out sizing into large `Super+O` and medium `Super+Shift+O`
- imported Omarchy-style focus, cycle, and mouse window controls
- deployed local GTK, cursor, and icon assets into the user profile
- added a repo-owned appearance controller with default, auto, and preset modes
- added wallpaper-derived shell color generation for Hyprland, Waybar, Rofi, Walker, and Mako
- removed the redundant Bluetooth module from the top connectivity group
- wired the Waybar volume module to open `pavucontrol` on click
- added media-key and `Super+[`, `Super+]`, `Super+\` volume bindings through `wpctl`
- restored the stable Waybar launch path after the experimental multi-bar manager misbehaved
- moved Walker onto tracked Elephant/Walker user services with a `rofi` fallback
- simplified `Super+E` to open `thunar` on the Desktop symlink roots
- switched `Super+Space` back to Walker directly and added `Super+Shift+Space` as the Rofi backup
- added a centered floating Walker window rule instead of the oversized framed launch surface
- corrected the Walker class match to `dev.benz.walker` so the small centered window rule actually applies
- adjusted Thunar to open in the medium centered proportions used by `Super+Shift+O` via an explicit post-launch resize
- added a repo-owned local Thunar desktop-entry override so Walker launches use the same medium-centered wrapper
- removed automatic pinning from the window pop modes so keyboard focus stays more predictable
- restored focus-follows-mouse and split fast switching into `Alt+Tab` for recent-window toggle and `Super+Tab` for full workspace cycling
- replaced plain focus cycling with an ArchMerOS cycle helper so spotlighted floating windows actually switch visually
- restored close-window on `Left Alt+W` only, leaving `Right Alt` free for ABNT2 typing
- made `Right Alt` an explicit XKB level-3 switch so ABNT2 can use its native `AltGr+Q` and `AltGr+W` symbols
- added a Waybar keyboard indicator with click-to-toggle for the active XKB layout
- added an ArchMerOS Bash login hook for GUI auto-detach behavior in new WezTerm shells

## Planned Structure

```text
ArchMerOS/
  README.md
  docs/
    architecture.md
    deployment-model.md
    decisions/
  install/
    bootstrap.sh
    link.sh
    packages/
    profiles/
  config/
    hypr/
    waybar/
    rofi/
    walker/
    archmeros/
    gtk/
    qt/
    wallpapers/
    fonts/
  themes/
    palette/
    assets/
  integration/
    mero-terminal/
```

This layout is intentionally simple at the start. New repos should only be split out when reuse is real and the maintenance boundary is clear.

## Non-Goals For Now

- Building a general-purpose public Linux distribution
- Replacing every tool with custom software
- Over-engineering the repo split before the system exists
- Installing unstable components just because they look interesting

## Working Rule For `mero_terminal`

If ArchMerOS is only configuring how `mero_terminal` is consumed, that belongs here.

If the change alters `mero_terminal` itself, stop and review it explicitly before touching the `mero_terminal` repository.

## Next Steps

- continue tightening the visual shell toward the target references
- verify the theme and icon stack inside real GTK apps
- refine monitor-specific workspace behavior
- improve wallpaper selection and rotation from project assets
- document each new operational change directly in this README
