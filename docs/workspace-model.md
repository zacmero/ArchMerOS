# Workspace Model

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
- workspace 6: overflow for extra long-lived code/projects
- workspace 7: experimental or temporary tool groups

These should be switched with:

- `Super+F1` through `Super+F4`

This preserves the user’s existing preference for function-key workspace access.

### Persistent Monitor Roles

- left monitor remains anchored to terminal-oriented work
- center monitor cycles the main project workspaces
- right monitor remains anchored to utility/media support
- new workspaces beyond V light up immediately across every Waybar instance; spaces `6` and `7` are no longer hard-locked, while `8/9` stay hidden for the left/right special monitors

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
