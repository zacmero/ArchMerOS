# Directional Focus

Empty enabled screens are valid directional destinations. If the nearest
screen has no eligible window, dispatch monitor focus directly, allowing
keyboard-only application launch there. Standby (`dpmsStatus=false`) and
disabled outputs are excluded. Hidden workspaces are never activated.

When the last window closes, Hyprland returns an empty active-window object.
The router uses the focused enabled monitor as its source in that case, so
Super+arrows can leave an empty screen. No window geometry is needed for this
fallback. Live-tested from empty DP-3 to HDMI-A-1; geometry and workspaces were
unchanged. Unit tests cover both directions and hidden-workspace exclusion.

In the Lua session, Super+arrows and Super+H/J/K/L use
`archmeros-focus-window.py`. Native directional focus can skip a nearer
monitor containing tiled windows when the source and a farther destination
are floating. This was reproduced with Firefox on DP-2 between the main
terminal and a Bravia terminal.

The helper selects a destination before issuing exactly one focus command.
It selects a directional window on the current monitor first, then the nearest
enabled, powered-on monitor and its most recently focused eligible window, or
the monitor itself when empty. It never runs
native focus first and corrects it afterward, which caused a visible double jump.
It does not filter by application,
resize windows, change tiling, or switch hidden workspaces. Disabled and
standby outputs are excluded. The script deploys through the existing
`config/archmeros` installation link; there are no machine-specific paths.

Regression tests: `python -m unittest discover -s tests -p test_focus_window.py`.
Live verification: main terminal to DP-2 Firefox; geometry and tiling unchanged.
The legacy session retains its original native focus bindings.
