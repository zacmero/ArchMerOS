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

### Lua workspace clicks

Waybar 0.15.0 sends legacy `dispatch workspace <id>` IPC from its
`hyprland/workspaces` buttons. That request is invalid under Hyprland's Lua
config provider, even though the workspace module and its buttons render
correctly.

ArchMerOS installs the tracked `waybar 0.15.0-2.1` backport from
`install/packages/waybar-lua-backport`. It translates only the workspace IPC
dispatch and retains the existing module, styling, persistent `1-5` buttons,
hidden service workspaces `10/11`, all-output behavior, and per-monitor bars.

Do not replace this module with `ext/workspaces`; that would fix activation at
the cost of the persistent and filtering behavior above.

Verification:

```bash
rtk pacman -Q waybar
rtk rg 'detected Lua-based dispatch protocol' /tmp/archmeros-waybar-*.log
```

The protocol-detection line is written after the first workspace-button click.
Full build, testing, upgrade, and rollback instructions are in
`install/packages/waybar-lua-backport/README.md`.

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
