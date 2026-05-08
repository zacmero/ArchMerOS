# Waybar

## Startup And Toggle

Waybar now starts through the ArchMerOS wrapper so it respects the hidden-monitor state and can recover cleanly after session refreshes.

- Start or restart: `~/.config/archmeros/scripts/archmeros-waybar.sh start`
- Toggle all Waybar bars: `Super+Shift+H`
- Show all hidden bars again: `~/.config/archmeros/scripts/archmeros-waybar.sh showall`
- Toggle only the focused monitor bar: `~/.config/archmeros/scripts/archmeros-waybar.sh toggle`
- Hidden-state file: `~/.local/state/archmeros/waybar-hidden.json`

## Workspace Cycling

Waybar itself shows workspace state; Hyprland owns the actual cycling commands.

- Cycle workspaces left/right: `Ctrl+Alt+Left` / `Ctrl+Alt+Right`
- Click a Waybar workspace button: jump directly to that workspace

## Calendar Popup

The center date/time block opens the ArchMerOS calendar popup on click instead of Waybar's built-in year tooltip.

- Script: `config/archmeros/scripts/archmeros-calendar-popup.py`
- Trigger: click either `clock#date` or `clock#time`
- Navigation:
  - `Left` / `Right`: previous or next month
  - `Today` button: jump back to current month
  - `Esc`: close the popup
- Current scope:
  - single-month view only
  - English weekday/month labels
  - centered floating Hyprland popup styled to match ArchMerOS

Relevant config:

- `config/waybar/config.jsonc`
- `config/waybar/center.jsonc`
- `config/archmeros/scripts/archmeros-waybar.sh`
- `config/hypr/hyprland.conf`
