# Waybar

## Startup And Toggle

Waybar starts through the ArchMerOS wrapper so hidden-monitor state is respected and bars recover cleanly after session refreshes.

- Start or restart: `~/.config/archmeros/scripts/archmeros-waybar.sh start`
- Toggle all bars: `Super+Shift+H`
- Toggle individual bars: `Super+Shift+1` (DP-3), `2` (HDMI-A-1), `3` (DP-2), `4` (DP-1)
- Show hidden bars again: `~/.config/archmeros/scripts/archmeros-waybar.sh showall`
- Toggle only the focused monitor bar: `~/.config/archmeros/scripts/archmeros-waybar.sh toggle`
- Hidden-state file: `~/.local/state/archmeros/waybar-hidden.json`

## DP-1 Beacon

DP-1 has a 190px right-side Waybar dedicated to project and automation context, not machine telemetry. Its four-sided frame and shared ArchMerOS palette surround open space rather than a stack of cards.

- `λ`: left-click opens the normal ArchMerOS WezTerm launcher; right-click launches the dedicated AI HUD beside the bar.
- `Super+A` retains its original centered HUD. The right-click uses a separate `archmeros-aichat-beacon` window class, with the same context capture and OpenRouter configuration, so its DP-1 placement cannot move the normal HUD.
- When CAVA is installed, it renders an 18-band audio-reactive spectrum at 30 fps. Waybar consumes CAVA raw output, so the custom Waybar build does not need its optional CAVA module. CAVA is in `install/packages/audio.txt`; install it on an existing machine with `sudo pacman -S cava`. The module stays hidden while the binary is absent.
- Project context follows the focused terminal/editor when its working directory is a Git repository. It reports branch, dirty state, and local ahead/behind counts.
- GitHub Actions status is cached for 75 seconds; the recent-event line falls back to the latest local commit when no run is available.
- The execution readout is limited to local, Oracle A1 (`prod-attack` via Tailscale), and Herdr. It makes no SSH health probes. Herdr agent counts remain unavailable outside a Herdr-attached session.
- The bottom `✦` reveals field note 04 on hover; `04` remains only the note identifier, not a visible counter.
- CPU/GPU temperatures, memory, load, and other conventional hardware telemetry are intentionally absent.

Relevant files:

- `config/waybar/beacon.jsonc`
- `config/waybar/beacon.css`
- `config/waybar/cava.conf`
- `config/archmeros/scripts/archmeros-cava-waybar.py`
- `config/archmeros/scripts/archmeros-dp1-activity.py`
- `config/hypr/ai_hub.lua`
- `config/archmeros/scripts/archmeros-waybar.sh`

## Workspace Cycling

Waybar displays workspace state; Hyprland owns the actual cycling commands.

- Cycle workspaces left/right: `Ctrl+Alt+Left` / `Ctrl+Alt+Right`
- Click a Waybar workspace button to jump directly to that workspace.

The regular bars filter workspaces `10`, `11`, and `12`. Workspaces 10 and 11 are hidden service workspaces; workspace 12 belongs to DP-1 and is omitted from the other bars. The Beacon bar does not duplicate the workspace list.

### Lua Workspace Clicks

Waybar 0.15.0 sends legacy `dispatch workspace <id>` IPC from its
`hyprland/workspaces` buttons. That request is invalid under Hyprland's Lua
config provider, even though the module and buttons render correctly.

`install/packages/waybar-lua-backport` translates only the workspace IPC
dispatch. It keeps the existing module, persistent `1-5` buttons, ignored
workspaces `10-12`, all-output behavior, and per-monitor bars. Do not replace
it with `ext/workspaces`; that would change the multi-output presentation.

The protocol-detection line is written after the first workspace-button click.
Full build, testing, upgrade, and rollback instructions are in
`install/packages/waybar-lua-backport/README.md`.

## Calendar Popup

The center date/time block opens the ArchMerOS calendar popup on click instead
of Waybar's built-in year tooltip.

- Script: `config/archmeros/scripts/archmeros-calendar-popup.py`
- Trigger: click either `clock#date` or `clock#time`
- Navigate months with `Left` / `Right`
- Use the `Today` button to return to the current month
- Press `Esc` to close the popup
- Current scope is a single-month view with English weekday/month labels

The popup is centered, floating, and styled to match ArchMerOS. Relevant
configuration is in `config/waybar/config.jsonc`, `left.jsonc`,
`center.jsonc`, `right.jsonc`, and `config/hypr/hyprland.lua`.
