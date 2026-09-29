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

DP-1 has a 202px right-side Waybar dedicated to project and automation context, not machine telemetry. Its four-sided frame and shared ArchMerOS palette surround open space rather than a stack of cards.

- `λ`: left-click opens the normal ArchMerOS WezTerm launcher with Fastfetch, clearing an inherited `MERO_FASTFETCH_SHOWN` flag from Waybar; right-click opens the dedicated AI HUD beside the bar.
- `Super+A` retains its original centered HUD. The right-click uses a separate `archmeros-aichat-beacon` window class, with the same context capture and OpenRouter configuration, so its DP-1 placement cannot move the normal HUD.
- When CAVA is installed, it renders a 20-band, 10-row audio-reactive spectrum at 30 fps. Waybar consumes CAVA raw output, so the custom Waybar build does not need its optional CAVA module. CAVA is in `install/packages/audio.txt`; install it on an existing machine with `sudo pacman -S cava`. The module stays hidden while the binary is absent.
- The Waybar restart/stop script terminates only CAVA processes using Beacon's own config, preventing orphaned capture processes after toggles.
- After five seconds below the sound threshold, the same 20-by-10 grid runs a white four-frames-per-second pulse. Detected audio restores the reactive display immediately.
- Project context follows the focused terminal/editor when its working directory is a Git repository. It reports branch, dirty state, and local ahead/behind counts.
- The event feed scans Git reflogs in repositories directly or one level below `~/projects` for local commits and remote-tracking `update by push` entries, including those made by agents. It also caches authenticated GitHub push, PR, and release events for 90 seconds. It shows the three newest events with more detail on hover. Explicit-URL pushes may not update a local remote-tracking reflog; GitHub's activity API can cover those, but may omit private or delayed events. This is not a record of every Git command or uncommitted edit.
- The execution readout is limited to local, Oracle A1, and Herdr. Local means this desktop session is active. Oracle A1 is `prod-attack`'s Tailscale online flag, not an SSH or job-health check. Herdr lights when a local interactive `herdr` client process exists; it does not report agent counts from Waybar.
- The bottom `✦` reveals field note 04 on hover; `04` remains only the note identifier, not a visible counter.
- CPU/GPU temperatures, memory, load, and other conventional hardware telemetry are intentionally absent.

Relevant files:

- `config/waybar/beacon.jsonc`
- `config/waybar/beacon.css`
- `config/waybar/cava.conf`
- `config/archmeros/scripts/archmeros-cava-waybar.py`
- `config/archmeros/scripts/archmeros-dp1-activity.py`
- `config/archmeros/scripts/archmeros-git-events.py`
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
