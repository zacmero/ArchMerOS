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
- `mako` notifications use ArchMerOS timeout rules, and app notifications are dismissed automatically when their app regains focus
- `Super+E` syncs the trusted Windows Desktop intersection into `~/Desktop` and opens `thunar`
- `Super+A` opens the ArchMerOS floating `aichat` HUD, and `Super+Shift+A` opens the Fabric browser overlay
- `rofi` remains available as the launcher fallback if Walker fails
- new login-shell Bash sessions source an ArchMerOS shell hook from `~/.bash_profile`
- local GTK, cursor, and icon theme assets are deployed under `~/.local/share`
- the active Firefox `default-release` profile can be fed from a repo-owned `user.js`
- `mero_terminal` remains separate and untouched
- the repo-tracked `sysc-greet` design is now the official ArchMerOS greeter default and login-manager target

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

Tracked system overrides:

- [install/system/etc/modprobe.d/archmeros-bluetooth.conf](/home/zacmero/projects/ArchMerOS/install/system/etc/modprobe.d/archmeros-bluetooth.conf)
- [install/system/etc/udev/rules.d/99-archmeros-btusb-power.rules](/home/zacmero/projects/ArchMerOS/install/system/etc/udev/rules.d/99-archmeros-btusb-power.rules)
- [install/system/apply-bluetooth-system.sh](/home/zacmero/projects/ArchMerOS/install/system/apply-bluetooth-system.sh)
- [install/system/apply-keyboard-system.sh](/home/zacmero/projects/ArchMerOS/install/system/apply-keyboard-system.sh)
- [install/system/etc/udev/hwdb.d/90-archmeros-zx-k22.hwdb](/home/zacmero/projects/ArchMerOS/install/system/etc/udev/hwdb.d/90-archmeros-zx-k22.hwdb)
- [install/system/apply-nvidia-system.sh](/home/zacmero/projects/ArchMerOS/install/system/apply-nvidia-system.sh)
- [install/system/apply-system.sh](/home/zacmero/projects/ArchMerOS/install/system/apply-system.sh)
- [install/system/apply-bootloader-system.sh](/home/zacmero/projects/ArchMerOS/install/system/apply-bootloader-system.sh)
- [install/system/apply-bootloader-shared-esp-system.sh](/home/zacmero/projects/ArchMerOS/install/system/apply-bootloader-shared-esp-system.sh)
- [install/system/apply-greeter-system.sh](/home/zacmero/projects/ArchMerOS/install/system/apply-greeter-system.sh)
- [install/system/etc/greetd/config.toml](/home/zacmero/projects/ArchMerOS/install/system/etc/greetd/config.toml)
- [install/system/etc/modprobe.d/archmeros-nvidia.conf](/home/zacmero/projects/ArchMerOS/install/system/etc/modprobe.d/archmeros-nvidia.conf)
- [install/system/etc/dracut.conf.d/archmeros-nvidia.conf](/home/zacmero/projects/ArchMerOS/install/system/etc/dracut.conf.d/archmeros-nvidia.conf)
- [install/system/etc/polkit-1/rules.d/85-greeter.rules](/home/zacmero/projects/ArchMerOS/install/system/etc/polkit-1/rules.d/85-greeter.rules)
- [install/build-sysc-greet.sh](/home/zacmero/projects/ArchMerOS/install/build-sysc-greet.sh)
- [docs/login-greeter.md](/home/zacmero/projects/ArchMerOS/docs/login-greeter.md)
- [docs/bootloader.md](/home/zacmero/projects/ArchMerOS/docs/bootloader.md)
- [docs/waybar.md](/home/zacmero/projects/ArchMerOS/docs/waybar.md)
- [docs/nvidia-pascal.md](/home/zacmero/projects/ArchMerOS/docs/nvidia-pascal.md)
- [docs/ai-flow.md](/home/zacmero/projects/ArchMerOS/docs/ai-flow.md)

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

4. Apply the tracked system-level defaults once as root:

```bash
sudo bash install/system/apply-system.sh
```

This currently applies:

- audio system defaults
- bluetooth system defaults
- keyboard hwdb overrides
- ArchMerOS bootloader defaults
- ArchMerOS greetd/sysc-greet login defaults

Optional host profile for this GTX 1060 workstation:

```bash
yay -S --needed nvidia-580xx-dkms nvidia-580xx-utils nvidia-580xx-settings opencl-nvidia-580xx egl-wayland libva-nvidia-driver
sudo bash install/system/apply-nvidia-system.sh
```

That Pascal/NVIDIA path is documented in [docs/nvidia-pascal.md](/home/zacmero/projects/ArchMerOS/docs/nvidia-pascal.md).

If an older ArchMerOS install was booted in BIOS/CSM mode while Windows owns the EFI partition, the shared-ESP migration path is documented in [docs/bootloader.md](/home/zacmero/projects/ArchMerOS/docs/bootloader.md) and applied with:

```bash
sudo bash install/system/apply-bootloader-shared-esp-system.sh
```

Greeter theme status:

- the live ArchMerOS login-manager default is documented in [docs/login-greeter.md](/home/zacmero/projects/ArchMerOS/docs/login-greeter.md)
- current default design direction is `archmeros` theme + `ascii-rain` background + `pour` logo
- the tracked greetd apply path now installs quiet wrapper launchers so fresh ArchMerOS installs do not leak greeter/session startup logs onto the TTY

5. From inside a Hyprland terminal, refresh the shell components with the tracked helper:

```bash
~/.config/archmeros/scripts/archmeros-refresh-shell.sh
```

This helper auto-detects the active Hyprland socket, reloads Hyprland, restarts Waybar, and reapplies the wallpaper in the current graphical session.

6. Re-apply the tracked session appearance if new apps still assume a light desktop:

```bash
~/.config/archmeros/scripts/archmeros-session-appearance.sh
```

7. Restart GTK apps such as `thunar` after theme changes so they pick up the active GTK/icon/cursor settings.

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
- Session appearance init: [config/archmeros/scripts/archmeros-session-appearance.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-session-appearance.sh)
- Window pop helper: [config/archmeros/scripts/archmeros-window-pop.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-window-pop.sh)
- Window close helper: [config/archmeros/scripts/archmeros-close.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-close.sh)
- Keyboard indicator helper: [config/archmeros/scripts/archmeros-keyboard.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-keyboard.sh)
- Transparency preset switcher: [config/archmeros/scripts/archmeros-transparency.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-transparency.sh)
- Thunar launcher wrapper: [config/archmeros/scripts/archmeros-thunar.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-thunar.sh)
- Walker launcher wrapper: [config/archmeros/scripts/archmeros-walker.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-walker.sh)
- Telegram focus/launch wrapper: [config/archmeros/scripts/archmeros-telegram.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-telegram.sh)
- Window history cycle helper: [config/archmeros/scripts/archmeros-cycle-window.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-cycle-window.sh)
- AI HUD launcher: [config/archmeros/scripts/archmeros-ai-float.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-ai-float.sh)
- AI context capture: [config/archmeros/scripts/archmeros-ai-context.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-ai-context.sh)
- Fabric browser: [config/archmeros/scripts/archmeros-fabric-browser.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-fabric-browser.sh)
- Bash hook: [config/archmeros/shell/archmeros-bash.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/shell/archmeros-bash.sh)
- Walker service units: [config/systemd/user/archmeros-elephant.service](/home/zacmero/projects/ArchMerOS/config/systemd/user/archmeros-elephant.service), [config/systemd/user/archmeros-walker.service](/home/zacmero/projects/ArchMerOS/config/systemd/user/archmeros-walker.service)

Theme direction currently applied:

- GTK theme: `catppuccin-frappe-blue-standard+default`
- icon theme: `ArchMerOS-Icons`
- cursor theme: `Bibata-Modern-Amber`

Repo-owned icon theme:

- active theme path: [local/share/icons/ArchMerOS-Icons](/home/zacmero/projects/ArchMerOS/local/share/icons/ArchMerOS-Icons)
- builder: [install/build-icons.py](/home/zacmero/projects/ArchMerOS/install/build-icons.py)
- base source: vendored `Papirus-Dark`

## Launch Wrapper Pattern

For apps that should jump to an existing window instead of spawning duplicates, ArchMerOS can route desktop launches through repo-owned wrappers.

Current example:

- Telegram desktop override: [org.telegram.desktop.desktop](/home/zacmero/projects/ArchMerOS/local/share/applications/org.telegram.desktop.desktop)
- Telegram focus/launch logic: [archmeros-telegram.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-telegram.sh)

This pattern is intended as the reference for future app-specific focus-or-launch integrations.
- folder palette: Dracula comment

## AI HUD Pattern

ArchMerOS now uses the same wrapper-first approach for the local AI flow.

- `Super+A`: floating `aichat` HUD
- `Super+Shift+A`: floating Fabric browser

This path is implemented as ArchMerOS-only shell wrappers plus Hyprland window rules, so upstream `wezterm` behavior stays untouched. The full notes live in [docs/ai-flow.md](/home/zacmero/projects/ArchMerOS/docs/ai-flow.md).

Rebuild command:

```bash
python3 install/build-icons.py
./install/link.sh
~/.config/archmeros/scripts/archmeros-session-appearance.sh
```

Dark-mode policy:

- Hyprland does not provide a universal dark-mode toggle by itself
- GTK dark mode is set by the tracked GTK settings files
- GNOME/libadwaita-aware apps are pushed to dark mode by the tracked session appearance script, which sets:
  - `org.gnome.desktop.interface color-scheme = 'prefer-dark'`
  - `gtk-theme = 'catppuccin-frappe-blue-standard+default'`
  - `icon-theme = 'ArchMerOS-Icons'`
  - `cursor-theme = 'Bibata-Modern-Amber'`

Wallpaper backend:

- preferred: `swaybg`
- fallback: `hyprpaper`

Shell launch policy:

- the ArchMerOS Bash hook auto-detaches GUI apps launched from an interactive shell so the terminal can close cleanly when desired
- terminal editors are explicitly excluded from that detach path
- `nvim`, `vim`, `vi`, `hx`, and `helix` must stay attached to the current terminal and should never cause the shell to exit when launched normally

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
- or one specific monitor such as `DP-3`, `HDMI-A-1`, or `DP-2`

The same launcher now also opens the ArchMerOS screensaver section, so wallpaper and idle-screen styling live behind the same keybinding.

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

Waybar is currently on the stable single-config launch path:

- `waybar -c ~/.config/waybar/config.jsonc -s ~/.config/waybar/style.css`

The Bluetooth module is intentionally removed from the top connectivity group because the tray already exposes Bluetooth status. The old Bluetooth number was `num_connections`, meaning the count of connected Bluetooth devices.

Current top bar flow:

- workspaces first
- taskbar slot reserved immediately after workspaces
- terminal button and tray on the left section
- date/time centered
- connectivity, keyboard layout, and system stats on the right

Taskbar behavior:

- powered by Waybar `wlr/taskbar`
- currently commented out in [config.jsonc](/home/zacmero/projects/ArchMerOS/config/waybar/config.jsonc)
- kept in the config for future iteration instead of being deleted
- intended behavior when re-enabled:
  - show only windows from the current output
  - left click: minimize or raise
  - middle click: close
  - act as the workspace-local minimize system on the main and side monitors

## Current Keybindings

These are the bindings that should be treated as current ArchMerOS behavior unless changed deliberately.

- `Ctrl+Alt+T`: open WezTerm
- `Super+Return`: open WezTerm
- `Super+Space`: launcher
- `Super+E`: PARA hub / file access
- `Super+Print`: region screenshot
- `Super+Shift+Print`: full screenshot
- `Alt+1` to `Alt+5`: switch main workspaces
- `Alt+KP_1` to `Alt+KP_5`: switch main workspaces from the numpad with NumLock on
- `Alt+numpad 1-5` also has raw `code:` fallback binds in Hyprland for stubborn keypad mappings
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
- `Super+G`: open Telegram
- `Super+.`: open the emoji picker
- `Super+M`: open YouTube Music app
- `Super+N`: create a new PARA note in Neovim
- `Super+Shift+N`: open Todoist and Evernote on workspace `V`
- `Super+C`: pop focused window out, center it, float it, and pin it
- `Super+\``: pop focused window into a large near-full centered mode
- `Alt+\``: same large pop/maximize flow as `Super+\``
- `Super+Shift+\``: pop focused window into a medium centered mode
- `Alt+Shift+\``: same medium pop/maximize flow as `Super+Shift+\``
- `Super+O`: reopen the most recently closed folder window
- `Super+Shift+O`: reopen the most recently closed tracked window/app/file

The reopen stacks keep the last 20 folder closes and the last 20 general closes, and a Hyprland `socket2` listener records real window-close events so mouse-close and app-quit paths are tracked too.
- `Super+Shift+P`: open display settings helper
- `Super+Shift+B`: refresh Hyprland shell components
- `Super+Shift+C`: open ChatGPT as a centered medium utility app
- `Super+Alt+W`: open wallpaper picker
- `Super+Alt+A`: open appearance controller
- `Super+Alt+S`: open the audio effects UI
- `Super+Alt+T`: open the shell theme selector
- `Super+Q`: close current app window
- click the Waybar keyboard indicator: toggle keyboard layout
- `XF86AudioRaiseVolume`: raise volume
- `XF86AudioLowerVolume`: lower volume
- `XF86AudioMute`: toggle mute
- `XF86AudioPrev`: previous media track
- `XF86AudioPlay`: play/pause media
- `XF86AudioNext`: next media track
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
- Walker/Rofi entry: `ArchMerOS Audio Lab`

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

Detached GUI launches now inherit ArchMerOS window-promotion behavior:

- if a centered spotlight window is active, it is pushed back
- the newly opened GUI app is promoted onto the currently focused workspace/monitor
- this is handled by [config/archmeros/scripts/archmeros-launch-detached.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-launch-detached.sh) and [config/archmeros/scripts/archmeros-promote-pid.py](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-promote-pid.py)
- focus is reasserted briefly after launch so apps opened from a floating source window do not instantly lose focus back to the launcher

## Current Shell GUI Behavior

New login-shell Bash sessions source:

- [config/archmeros/shell/archmeros-bash.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/shell/archmeros-bash.sh)

Current behavior:

- when you launch a simple GUI app command from a WezTerm Bash shell, ArchMerOS detaches it with `setsid` and closes that shell
- this is meant to stop GUI apps from dying when the terminal window closes
- it only targets simple direct commands, not pipelines or compound shell syntax
- desktop entries with `Terminal=true` are skipped by the GUI-detach hook, so TUIs like `htop` are not treated as detached GUI apps
- explicit TUI command names like `htop`, `btop`, `top`, `yazi`, `lazygit`, and `tmux` are also excluded
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

## Web Apps

Firefox remains the main browser. ArchMerOS still uses isolated Chromium-style web apps for some tools, but YouTube Music now uses a dedicated Firefox app shell because Chromium was a bad ad-blocking host.

Tracked launcher:

- [config/archmeros/scripts/archmeros-webapp.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-webapp.sh)
- [config/archmeros/scripts/archmeros-youtube-music.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-youtube-music.sh)

Tracked app entries:

- [todoist.desktop](/home/zacmero/projects/ArchMerOS/local/share/applications/todoist.desktop)
- [evernote.desktop](/home/zacmero/projects/ArchMerOS/local/share/applications/evernote.desktop)
- [chatgpt.desktop](/home/zacmero/projects/ArchMerOS/local/share/applications/chatgpt.desktop)
- [youtube-music.desktop](/home/zacmero/projects/ArchMerOS/local/share/applications/youtube-music.desktop)

Current launch paths:

- Walker/Rofi entries: `Todoist`, `Evernote`, `ChatGPT`, `YouTube Music`
- `Super+M`: open `YouTube Music`
- `Super+Shift+C`: open `ChatGPT`
- `Super+N`: create a new PARA note in Neovim
- `Super+Shift+N`: open `Todoist` and `Evernote` together on workspace `V`

Chromium-backed web apps launch in isolated profiles under:

- `~/.local/share/archmeros/webapps/`

Current YouTube Music path:

- `Super+M` launches a dedicated Firefox profile directly on workspace `9`
- the launcher is [config/archmeros/scripts/archmeros-youtube-music.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-youtube-music.sh)
- the profile templates are repo-owned:
  - [config/firefox/profiles/youtube-music/user.js](/home/zacmero/projects/ArchMerOS/config/firefox/profiles/youtube-music/user.js)
  - [config/firefox/profiles/youtube-music/chrome/userChrome.css](/home/zacmero/projects/ArchMerOS/config/firefox/profiles/youtube-music/chrome/userChrome.css)
  - [config/firefox/profiles/youtube-music/chrome/userContent.css](/home/zacmero/projects/ArchMerOS/config/firefox/profiles/youtube-music/chrome/userContent.css)
- `firefox-ublock-origin` is installed for the Firefox path
- the Firefox shell hides browser chrome so YouTube Music behaves like a standalone player window
- the dedicated profile also carries a site-only brightness override for `music.youtube.com` so the narrow player view keeps the album art more visible instead of collapsing into a dark blur

Current ad-blocking note:

- Chromium 146 was a bad host for classic `uBlock Origin` on YouTube Music
- `hblock` still helps at the system level, but the practical fix was moving YouTube Music to Firefox instead of Chromium

## Native Apps

When a service already has a solid Linux desktop client, ArchMerOS prefers the native package over a browser wrapper.

Current native messaging app:

- `telegram-desktop`
- `Super+G`: open Telegram
- Telegram is bound directly to `/usr/bin/Telegram`, which is the real binary shipped by the Arch package on this machine

Emoji picker:

- active backend: `rofimoji` + `rofi` + `wtype`
- reason: the Flatpak emoji pickers looked better but their copy/paste and focus behavior under this Hyprland setup was unstable
- layout: compact dark emoji grid with transparent cyberpunk popup styling, using Rofi's icon render path instead of raw text glyph rendering
- insertion model: ArchMerOS records the currently focused Hyprland window, gets the emoji from `rofimoji --action print`, copies it to the clipboard, explicitly refocuses that window, then types with `wtype`
- launcher: [config/archmeros/scripts/archmeros-emoji.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-emoji.sh)
- config: [config/rofimoji.rc](/home/zacmero/projects/ArchMerOS/config/rofimoji.rc)
- theme: [config/rofi/launchers/emoji.rasi](/home/zacmero/projects/ArchMerOS/config/rofi/launchers/emoji.rasi)
- bind: `Super+.`
- `Enter` types the selected emoji into the focused app
- `Alt+C` copies the selected emoji instead of typing it
- `Alt+V` inserts via clipboard

## Workspace Layout

Current monitor layout:

- left: `DP-3`
- center: `HDMI-A-1`
- right: `DP-2`

Center monitor workspaces:

- `1` -> `I`
- `2` -> `II`
- `3` -> `III`
- `4` -> `IV`
- `5` -> `V`

To add another center workspace later:

- add `workspace = <n>, monitor:HDMI-A-1` in [hyprland.conf](/home/zacmero/projects/ArchMerOS/config/hypr/hyprland.conf)
- add the `Alt+<n>` and `$mod+<n>` binds in [hyprland.conf](/home/zacmero/projects/ArchMerOS/config/hypr/hyprland.conf)
- add the Roman numeral label and persistent workspace entry in the Waybar workspace configs
- reload Hyprland

## Notes And Editor

Repo-owned Neovim path:

- launcher: [archmeros-nvim.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-nvim.sh)
- desktop entry override: [nvim.desktop](/home/zacmero/projects/ArchMerOS/local/share/applications/nvim.desktop)
- MIME defaults: [mimeapps.list](/home/zacmero/projects/ArchMerOS/config/mimeapps.list)
- WezTerm launcher: [archmeros-wezterm.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-wezterm.sh)

Fast note flow:

- `Super+N` creates a new file in `~/Desktop`
- the file opens in Neovim inside WezTerm
- saving writes directly into the PARA folder
- zero-byte files are also mapped to Neovim through `application/x-zerosize` and `inode/x-empty`, so fresh notes do not fall through to Mousepad

Current editor focus behavior:

- text/code files opened from Thunar resolve to the repo-owned `nvim.desktop`
- `nvim.desktop` launches Neovim through WezTerm, and that WezTerm instance is started through the same detached-launch promotion path used by other floating app flows
- this keeps the new editor window as the real active front window instead of letting Thunar keep focus behind it
- the intended close behavior after opening a file from Thunar is: close the editor window first, not the Thunar source window

Default text sizing:

- ArchMerOS now pushes a larger baseline into new apps:
  - `font-name = 'Noto Sans 14'`
  - `monospace-font-name = 'CaskaydiaCove Nerd Font Mono 14'`
  - `text-scaling-factor = 1.10`
- tracked GTK defaults now also use `Noto Sans 14`
- Hyprland exports:
  - `QT_SCALE_FACTOR=1.10`
  - `GDK_DPI_SCALE=1.10`

Productivity launcher:

- `Super+Shift+N` opens Todoist and Evernote together on workspace `V`

## Bluetooth

Current Bluetooth USB workaround:

- tracked config: [install/system/etc/modprobe.d/archmeros-bluetooth.conf](/home/zacmero/projects/ArchMerOS/install/system/etc/modprobe.d/archmeros-bluetooth.conf)
- tracked udev rule: [install/system/etc/udev/rules.d/99-archmeros-btusb-power.rules](/home/zacmero/projects/ArchMerOS/install/system/etc/udev/rules.d/99-archmeros-btusb-power.rules)
- tracked installer: [install/system/apply-bluetooth-system.sh](/home/zacmero/projects/ArchMerOS/install/system/apply-bluetooth-system.sh)
- live system file: `/etc/modprobe.d/archmeros-bluetooth.conf`
- live udev rule: `/etc/udev/rules.d/99-archmeros-btusb-power.rules`
- active options:

```conf
options btusb enable_autosuspend=n reset=y
```

Why this exists:

- the CSR USB dongle started failing BLE keyboard pairing after the machine moved to `linux-lts 6.18.18-1` and `bluez 5.86-4` on March 17, 2026
- the controller was repeatedly falling into `PowerState: off-blocked`
- disabling `btusb` autosuspend and forcing reset on initialization is the current mitigation
- ArchMerOS also pins the CSR dongle to `power/control=on` and sets `AutoEnable=true` in BlueZ so the adapter does not idle itself away
- `blueman-applet` is also started from Hyprland so Bluetooth approval prompts have a desktop agent in-session

Current rollback state:

- downgraded from cache to `bluez 5.86-2`
- downgraded from cache to `linux-lts 6.12.73-1`
- downgraded from cache to `linux-firmware 20260110-1`
- a reboot is required before the downgraded kernel modules and firmware are actually active

What the actual problem was:

- it was not mainly a missing approval popup
- the CSR Bluetooth dongle was unstable on the newer stack and the controller was repeatedly dropping, re-enumerating, or failing BLE HID reads during keyboard pairing
- Hyprland also had no Bluetooth desktop agent running, which made approval prompts harder to surface when they did matter
- a stray `rtbth-dkms` package was also present and was removed during cleanup

What finally fixed it:

1. track and apply the `btusb` workaround:

```conf
options btusb enable_autosuspend=n reset=y
```

2. pin the CSR dongle USB power policy to `on` with the tracked udev rule
3. set BlueZ `AutoEnable=true`
4. downgrade to the cached pre-regression stack:
   - `bluez 5.86-2`
   - `bluez-libs 5.86-2`
   - `bluez-utils 5.86-2`
   - `linux-lts 6.12.73-1`
   - `linux-firmware 20260110-1`
5. reboot into the downgraded kernel
6. remove `rtbth-dkms`
7. start `blueman-applet` from Hyprland
8. pair from a live terminal `bluetoothctl` agent

Final successful pairing path:

```bash
bluetoothctl
agent on
default-agent
power on
scan on
pair <MAC>
trust <MAC>
connect <MAC>
```

The successful keyboard MAC during recovery was:

- `E3:13:39:DC:A4:86`

## Fullscreen Behavior

`Super+F` is now handled by:

- [config/archmeros/scripts/archmeros-fullscreen.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-fullscreen.sh)

Current rule:

- browser windows use Hyprland `fullscreenstate 2 0` so the monitor fullscreen does not force the browser client into presentation-mode-style fullscreen
- non-browser windows keep the normal Hyprland fullscreen toggle

Current web-app placement rules:

- `YouTube Music` -> workspace `9` on the right monitor
- `ChatGPT` -> medium-centered floating window
- `Todoist` -> workspace `5` / `V`
- `Evernote` -> workspace `5` / `V`

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
- [config/archmeros/scripts/archmeros-audio-debug.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-audio-debug.sh) for live PipeWire and ALSA buffer inspection while reproducing crackle/pop events

UR44 policy:

- [config/archmeros/scripts/archmeros-audio-policy.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-audio-policy.sh)
- [config/pipewire/pipewire.conf.d/10-archmeros-audio.conf](/home/zacmero/projects/ArchMerOS/config/pipewire/pipewire.conf.d/10-archmeros-audio.conf)
- [config/wireplumber/wireplumber.conf.d/10-archmeros-ur44-no-suspend.conf](/home/zacmero/projects/ArchMerOS/config/wireplumber/wireplumber.conf.d/10-archmeros-ur44-no-suspend.conf)
- [install/system/etc/modprobe.d/archmeros-audio.conf](/home/zacmero/projects/ArchMerOS/install/system/etc/modprobe.d/archmeros-audio.conf)
- [install/system/apply-audio-system.sh](/home/zacmero/projects/ArchMerOS/install/system/apply-audio-system.sh)
- [docs/ur44-stability.md](/home/zacmero/projects/ArchMerOS/docs/ur44-stability.md)
- Hyprland starts this on login to force the machine into the studio path:
- NVIDIA HDMI audio off
- Intel onboard audio off
- UR44 profile set to `pro-audio`
- default sink set to `alsa_output.usb-Yamaha_Corporation_Steinberg_UR44-01.pro-output-0`
- default source set to `alsa_input.usb-Yamaha_Corporation_Steinberg_UR44-01.pro-input-0`
- PipeWire quantum raised to `2048` with `1024..4096` bounds for better click/pop resilience under activity
- PipeWire default rate kept at `48000`, with `96000` allowed as an alternate rate
- WirePlumber keeps the UR44 nodes awake with `session.suspend-timeout-seconds = 0` so playback start/stop transitions do not wake the interface from idle
- the repo now carries the modern equivalent of the older `main.lua.d/50-alsa-config.lua` tuning: the UR44 nodes are forced to `api.alsa.period-size = 1024` and `api.alsa.headroom = 8192` through `wireplumber.conf.d`
- HDA kernel power saving explicitly disabled with `power_save=0` and `power_save_controller=N`

March 22, 2026 audio investigation:

- the UR44 is using the correct Linux driver: `snd_usb_audio`
- the subtle Firefox / YouTube Music pops were not traced to a missing Yamaha driver
- the strongest system-level problem found was the old UR44 `analog-surround-21` profile, which was exposing an unnecessary `LFE` path for browser playback
- ArchMerOS switched the interface to `pro-audio`, and the live Firefox stream then dropped back to `FL/FR` only
- the live system sample rate is `48000 Hz`, which is appropriate for browser/YouTube playback; pushing the whole desktop to `192000 Hz` would not help this use case and could reduce stability
- if the pops continue after this cleanup, the next A/B should be:
- Firefox YouTube Music vs local `mpv`
- EasyEffects enabled vs bypassed
- Firefox hardware acceleration is now disabled in the repo-owned profile configs for both the main browser and the dedicated YouTube Music profile so browser-side GPU scheduling can be ruled out
- this machine should treat the UR44 as the only active audio path unless you intentionally re-enable another card

Bluetooth note after the March 22, 2026 check:

- the CSR dongle power policy is already pinned to `on`
- autosuspend is already disabled
- intermittent keyboard disconnects no longer look like simple USB power saving
- if the issue returns, the more likely culprit is the CSR controller/session state, not adapter idle power

## Shell Themes

ArchMerOS shell themes are now bundle-driven and live in:

- [themes/bundles](/home/zacmero/projects/ArchMerOS/themes/bundles)

Current selector:

- [config/archmeros/scripts/archmeros-theme-select.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-theme-select.sh)
- [config/rofi/launchers/theme-selector.rasi](/home/zacmero/projects/ArchMerOS/config/rofi/launchers/theme-selector.rasi)

Current theme entries:

- [work-clean.json](/home/zacmero/projects/ArchMerOS/themes/bundles/work-clean.json)
- [night-cyber.json](/home/zacmero/projects/ArchMerOS/themes/bundles/night-cyber.json)

Theme selector entry points:

- `Super+Alt+T`
- `~/.config/archmeros/scripts/archmeros-theme-select.sh`
- Walker/Rofi entry: `ArchMerOS Themes`

To add a future shell theme, create a new bundle JSON in `themes/bundles/` with:

- an `id`
- a `label`
- a `description`
- an `appearance` block
- a `transparency` preset name

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
- `thunar` is forced to open a new window with `-w` so ArchMerOS can reliably size and place it
- `thunar` is explicitly resized after launch to the same proportions as the `Super+Shift+O` medium pop mode
- the Thunar wrapper now moves the new window onto the currently focused monitor/workspace before centering it
- after that it behaves like a normal floating window and can still be tiled normally
- Walker now uses a repo-owned local `thunar.desktop` override that launches through the same Thunar wrapper
- files opened from that popped PARA window now keep the same front-of-focus workflow:
  - images open through repo-owned `imv.desktop`
  - audio/video open through repo-owned `mpv.desktop`
  - PDFs and HTML documents open through repo-owned `archmeros-browser.desktop`
  - text/code files open through repo-owned `nvim.desktop`
- those desktop overrides all route through ArchMerOS launch promotion so the opened file appears as the new front card on the active workspace/monitor instead of hiding behind Thunar

Current known PARA roots:

- `~/Desktop/1_Projects`
- `~/Desktop/2. Areas`
- `~/Desktop/3. Resources`
- `~/Desktop/4. Archives`

Manual refresh command:

```bash
~/.config/archmeros/scripts/archmeros-desktop-sync.sh
```

## Current Screenshot Flow

Screenshot launcher:

- [config/archmeros/scripts/archmeros-screenshot.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-screenshot.sh)

Current behavior:

- `Super+Print`: interactively select a region with the mouse
- `Super+Shift+Print`: capture the full screen
- saved to `~/Pictures/Screenshots`
- copied to the Wayland clipboard automatically
- notification shows the saved filename

Direct commands:

```bash
~/.config/archmeros/scripts/archmeros-screenshot.sh region
~/.config/archmeros/scripts/archmeros-screenshot.sh full
```

## Current Wallpaper Picker

Wallpaper picker:

- [config/archmeros/scripts/archmeros-wallpaper-pick.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-wallpaper-pick.sh)
- [config/archmeros/scripts/archmeros-wallpaper-browser.py](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-wallpaper-browser.py)

Current behavior:

- `Super+Alt+W` opens a repo-owned wallpaper browser window
- the same window now includes an ArchMerOS screensaver section for live session screensaver styling
- the screensaver section can also disable the animated screensaver entirely while keeping monitor standby / DPMS idle-off active
- the same launcher now also exposes wallpaper rotation controls for random per-monitor cycling from `config/wallpapers`
- target now defaults to the currently focused monitor for manual crop-first behavior
- wallpaper preview updates automatically as you move through the list
- `Apply`:
  - on a single monitor target, activates the in-place crop overlay directly in the preview area
  - drag the crop rectangle to choose the visible area
  - use the mouse wheel, `+` / `-`, or the on-screen `Zoom In` / `Zoom Out` buttons to resize the crop area
  - arrow keys nudge the crop area
  - `Enter` applies the current crop immediately
  - on `All monitors`, applies the original wallpaper directly
- generated crops are stored under `config/wallpapers/generated`
- the crop flow now stays inside the main wallpaper browser instead of opening a second popup

Notes:

- this crop flow is intentionally repo-owned and lightweight
- backend remains `swaybg`/`hyprpaper` for application only; the crop/fitting step happens before apply
- single-monitor crop is now manual position + zoom
- multi-monitor crop remains automatic centered fit because one manual crop cannot satisfy multiple aspect ratios cleanly
- explicit zoom buttons are present because mouse-wheel delivery can vary between environments
- when the target is a single monitor, there is no separate crop popup anymore; `Apply` uses the in-place crop overlay directly
- the screensaver section writes a user override to `~/.config/archmeros/screensaver/screensaver.conf`
- live session screensaver triggering is handled by `hypridle`, while the animated screen itself is launched through `archmeros-screensaver.sh`
- session screensaver input exits straight back to the current desktop session; it does not drop into a login prompt
- wallpaper rotation uses `hyprpaper` for random per-monitor directory cycling
- the current wallpaper backend does not provide a subtle fade transition, so rotation uses hard cuts for now
- when the target is `All monitors`, the crop action is intentionally automatic; choose a single monitor target for the manual crop window

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
- split the pop-out sizing into large `Super+\`` and medium `Super+Shift+\``
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
- dropped the `Alt+W` close binding because it conflicted with `Right Alt` / `AltGr` behavior on the current Hyprland stack
- made `Right Alt` an explicit XKB level-3 switch so ABNT2 can use its native `AltGr+Q` and `AltGr+W` symbols
- added a Waybar keyboard indicator with click-to-toggle for the active XKB layout
- added an ArchMerOS Bash login hook for GUI auto-detach behavior in new WezTerm shells
- added screenshot shortcuts with repo-owned `grim`/`slurp` capture and clipboard copy
- added a local-output Waybar taskbar path after workspaces, then commented it out for now while keeping the code in place
- upgraded `Super+E` to force a fresh Thunar window and place it on the focused workspace/monitor reliably
- replaced the wallpaper picker with a repo-owned auto-preview browser window
- added manual single-monitor wallpaper crop selection and automatic all-monitor crop generation through Pillow
- upgraded detached terminal-launched GUI apps to promote onto the focused workspace/monitor instead of hiding behind spotlight windows
- added a reopen-history flow with 20-slot stacks for closed folder windows and general tracked windows, using `Super+O` and `Super+Shift+O`
- added a lightweight Hyprland `socket2` reopen listener so real close events are captured without relying only on the close keybinds
- added a session screensaver path driven by `hypridle` and the repo-owned `sysc-greet` screensaver launcher
- extended the wallpaper picker with a screensaver section so wallpaper and screensaver styling stay under the same ArchMerOS launcher flow

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
