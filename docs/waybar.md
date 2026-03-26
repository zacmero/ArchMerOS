# Waybar

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
- `config/hypr/hyprland.conf`
