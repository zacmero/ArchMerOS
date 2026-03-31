# AI Flow

ArchMerOS now has an ArchMerOS-only AI overlay flow built on top of WezTerm.

The goal is to add a fast local AI HUD for this machine without mutating normal WezTerm behavior or assuming every machine uses ArchMerOS.

## Keybindings

- `Super+A`: open the floating `aichat` HUD
- `Super+Shift+A`: open the floating Fabric browser
- `Super+Ctrl+A`: open the saved-session browser for `aichat`

## Boundary

This feature is intentionally implemented as ArchMerOS wrappers, not upstream terminal changes.

Tracked files:

- [archmeros-ai-float.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-ai-float.sh)
- [archmeros-ai-context.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-ai-context.sh)
- [archmeros-fabric-browser.sh](/home/zacmero/projects/ArchMerOS/config/archmeros/scripts/archmeros-fabric-browser.sh)
- [hyprland.conf](/home/zacmero/projects/ArchMerOS/config/hypr/hyprland.conf)

Plain `wezterm` usage remains unchanged.

## Aichat HUD

The `aichat` overlay launches in its own floating WezTerm class:

- `archmeros-aichat-float`

Hyprland keeps it:

- floating
- centered
- large enough to act like an overlay scratchpad instead of a tiled split

### Context Injection

Context injection is conservative on purpose.

When `Super+A` is pressed:

1. ArchMerOS checks whether the currently focused Hyprland window is a WezTerm window.
2. The wrapper maps the active Hyprland window PID back to the frontmost WezTerm client and pane.
3. If that pane is running `nvim`, ArchMerOS connects to the live Neovim socket and captures a bounded slice of the current buffer around the visible window and cursor.
4. If that pane is not running `nvim`, the wrapper falls back to the last `120` visible lines of the pane scrollback.
5. That capture is written to a temporary file.
6. `aichat` preloads the capture into a saved HUD session and then reopens that session interactively.

If the current focused window is not WezTerm, the HUD opens a clean `aichat` session with no injected context.

This keeps the flow safe:

- no global WezTerm config mutation
- no assumption about a single terminal instance
- Neovim context is bounded instead of dumping whole `2000+` line files into the HUD

The HUD session name is generated from the active source when possible, for example:

- `hud-path-utils-203455`
- `hud-wezterm-203522`

The right side prompt meter inside `aichat` is token usage for the active session:

- `ctx 1177 (0.11%)` means roughly `1177` tokens currently stored in the session, which is `0.11%` of the configured model context window

## ArchMerOS-Local Aichat Override

ArchMerOS can override the HUD model without mutating the user’s global `aichat` config.

Local file:

- [aichat.env](/home/zacmero/projects/ArchMerOS/config/archmeros/ai/aichat.env)

Supported variable:

- `ARCHMEROS_AICHAT_MODEL`

If left empty, the HUD defers to the normal `aichat` config.

## Fabric Browser

The Fabric path is a browser first, not a forced execution layer.

The floating Fabric browser:

- runs in its own WezTerm class: `archmeros-fabric-browser`
- uses `fzf` as a TUI explorer
- previews pattern files on the right
- shows the suggested `fabric --pattern ...` command for the selected pattern

Pattern search order:

1. `~/.config/archmeros/fabric/patterns`
2. `~/.config/fabric/patterns`
3. `~/.local/share/fabric/patterns`

Repo-owned patterns should live in:

- [config/archmeros/fabric/patterns](/home/zacmero/projects/ArchMerOS/config/archmeros/fabric/patterns)

That keeps ArchMerOS custom prompts versioned without polluting upstream Fabric assets.

## Packages

Current package intent:

- `aichat`: tracked in the base package set
- `fabric-ai-bin`: tracked in the optional AUR package set

If Fabric is not installed yet, the browser still opens as a pattern explorer and install hint.

## Session Browser

The session browser is a lightweight TUI wrapper around `~/.config/aichat/sessions`.

Open it with:

- `Super+Ctrl+A`

Current actions:

- `Enter`: load the selected session
- `Ctrl+R`: rename the selected session file
- `Ctrl+N`: start a new named session

The HUD itself also exposes the most useful built-in `aichat` commands in the header:

- `.help`
- `.info session`
- `.edit session`
- `.save session`
