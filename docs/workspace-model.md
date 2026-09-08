# Workspace Model

## Display Settings Window

`Super+Shift+P` runs `archmeros-wdisplays.py`. It keeps the current GTK theme and
font scaling, but uses an app-only derivative theme without client-side shadow
margins. Those margins previously occupied about 100 pixels on each side and
clipped the controls inside the compositor's window bounds. Other GTK apps are
unaffected. The wrapper refreshes its derivative from the current theme on launch.

The `wdisplays-fit` rule floats and centers this utility. The resulting window
was checked visually on the 1366 x 768 monitor; its controls fit, and no monitor
configuration was changed during testing.

## Scratchpad (Lua Session)

- `Super+Ctrl+P` with an empty slot adopts the focused window and hides it.
- The same key summons the assigned window above other windows on the focused
  monitor, or hides it when already shown there. Summoning from another monitor
  transfers the overlay there. It is independent of numbered workspaces.
- The native special-workspace animation slides up from below and hides downward.
- The window stays floating and centered when summoned. Its current dimensions
  survive hide/show and reloads, including manual size changes. Oversized windows
  are clamped to the destination monitor's usable area, respecting scale,
  rotation, reserved bars, outer gaps, and borders. Existing size-cycle keys work.
- `Alt+Tab` or `Super+Tab` while the scratchpad is focused releases it into the current normal
  workspace as a card at its current size. Following presses use the normal card
  rotation. `Super+Shift+V` releases and tiles it instead. The size-cycle script
  skips monitor-move dispatches for special workspaces: even a move to the same
  monitor would otherwise eject the window into the normal workspace.
- Closing or releasing the window frees the single slot. No application is
  preselected or launched, and no session data or persistent window IDs are stored.
- New apps opened while the scratchpad is visible go to the regular workspace
  underneath; they do not become extra scratchpad windows.
- Wallpaper selection remains on `Super+P`, with its previous `Super+Alt+P`
  alias moved to `Super+Alt+Shift+P`.

Implementation: `config/hypr/scratchpad.lua` owns native compositor operations;
`archmeros-scratchpad.sh` provides the entry point shared by the keybinding and
existing card/tile scripts. The special workspace itself owns the slot, so there
is no file-state race or stale assignment after closing a window. Each toggle
runs as one compositor Lua evaluation. The legacy `.conf` bindings are unchanged.

Opt-in live regression (requires Kitty and empty workspaces 9 and 90):

```bash
rtk python3 tests/scratchpad-live.py
rtk python3 tests/scratchpad-sizing-live.py
```

The test creates disposable windows, checks hide/show, manual sizes, reload,
monitor transfer, isolation of new apps, card/tile release and slot reuse, then
closes its own windows and restores monitor workspaces and focus. Pixel sampling
on 2026-09-07 also verified the vertical entrance and downward exit.

## New Windows Above Floating Cards

The Lua `window.open` handler promotes a newly focused tiled window to a
centered 72% x 76% floating card when its workspace already contains a mapped,
non-hidden floating window. Keyboard focus alone cannot raise a tiled window
above the floating layer. The handler runs at window opening, without a delayed
resize worker, and leaves existing window sizes unchanged.

Already-floating windows keep their launcher sizing. Fully tiled workspaces
keep native tiling. Windows that open without focus are not promoted, avoiding
background workspace activation and preserving Telegram notification behavior.

Live regression on 2026-09-07: disposable Kitty windows reproduced the focused
but covered tiled-window case. After the fix, the new window was focused and
floating at 1382 x 820 on a 1920 x 1080 monitor; the existing 1600 x 950 card
retained its size. Empty and fully tiled workspace launches remained tiled.

## Migration Rule

XFCE stays installed at the beginning.

ArchMerOS should be introduced as a parallel Hyprland session until the full daily workflow is stable. The fallback session matters because this machine contains important work and the migration must stay reversible while the new environment matures.

## Core Goal

The current pain point is not just window count. It is loss of spatial continuity.

Today:

- left monitor is used mostly for terminal and AI agent activity
- center monitor is used for code
- right monitor is used for utility windows, music, or video
- XFCE workspace switching can hide windows that should remain visible

The ArchMerOS session should preserve role-based monitor behavior even while the active project changes.

## Three-Monitor Model

### Left Monitor

Primary role:

- terminal anchor
- AI agent sessions
- long-lived shell context

Desired behavior:

- terminal should stay visible while project workspaces change elsewhere
- this monitor should not be part of the project-churn chaos

### Center Monitor

Primary role:

- code editor
- browser docs
- project-specific switching

Desired behavior:

- this is the main workspace-switching monitor
- project context lives here

### Right Monitor

Primary role:

- reference tool
- music
- video
- support utilities

Desired behavior:

- media or utility windows can stay present while center-monitor workspaces change

## Hyprland Behavior To Use

Hyprland can solve the current problem because workspace state is monitor-aware.

That means:

- switching the center monitor workspace does not need to switch the left or right monitor
- a terminal can remain on the left monitor while the center changes projects
- a video or utility window can remain on the right monitor while the center changes projects

This is the correct model for this workstation.

## Initial Workspace Strategy

Start with a conservative layout instead of a large workspace matrix.

### Main Workspaces

- workspace 1: main coding project
- workspace 2: second active coding project or browser-heavy work
- workspace 3: notes, docs, AI support, temporary overflow
- workspace 4: personal admin, comms, or creative overflow
- workspace 5: tasks and project planning
- workspace 6: overflow for extra long-lived code/projects
- workspace 7: experimental or temporary tool groups
- workspace 8: additional long-lived project or research
- workspace 9: additional long-lived project or research

These should be switched with:

- `Alt+1` through `Alt+9` or `Super+1` through `Super+9`

Windows move directly to these workspaces with `Super+Shift+F1` through
`Super+Shift+F9`. A moved floating card returns to the tiled layout and stays
focused in the destination workspace.

### Persistent Monitor Roles

- left monitor remains anchored to terminal-oriented work
- center monitor cycles the main project workspaces
- right monitor remains anchored to utility/media support
- center workspaces `1-9` light up across every Waybar instance when created
- hidden service workspace `10` stays on the left monitor and `11` stays on the right monitor

This should be implemented with monitor-specific workspace assignment and selective movement bindings.

## Window Strategy

### Terminal

The terminal is not a disposable launcher window. It is operational infrastructure.

Rules:

- terminal windows should be easy to spawn
- terminal sessions should be easy to keep alive
- terminal windows should not disappear when center workspaces change

Likely direction:

- dedicated terminal workspace on the left monitor
- optional split layouts or tabbed tmux structure inside the terminal for multi-agent work

### Video And Music

Yes, the right-side video/tool window can stay visible while workspaces change.

That is not a special hack. It is a normal Hyprland use case if the window lives on a monitor whose active workspace is not being switched, or if it is assigned to a monitor-specific special workspace.

### PARA Hub

The desktop itself should not be treated as the main information surface.

Instead:

- `Super+Space` opens the main launcher
- `Super+E` opens a PARA/project hub
- the hub should open a graphical file manager window for drag-and-drop friendly work

Launcher split:

- `Walker` for general app and action launching
- `Rofi` for the focused PARA hub flow

## Initial File Manager Direction

The file manager should be:

- lightweight
- visually clean
- good for drag and drop
- easy to float in a centered workspace hub

Initial default candidate:

- `thunar`

Reason:

- lightweight
- mature
- predictable
- integrates well with drag-and-drop workflows

This is a starting choice, not a permanent commitment.

## Imported Shortcut Intent

Existing habits worth preserving at the beginning:

- `Ctrl+Alt+T` opens `wezterm`
- `Super+E` opens file access
- `Super+Space` opens `walker`
- `Super+P` opens display settings helper
- workspace switching remains fast and mnemonic

These should be preserved first and refined later.
