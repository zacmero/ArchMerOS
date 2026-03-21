# ArchMerOS

Purpose: personal Arch Linux distribution/setup project focused on coding and creative work, with emphasis on aesthetics, workflow speed, modularity, adaptability, and performance.

Current state: repository directory exists but is effectively empty except for `.serena/`; no git repository initialized yet.

Key product direction from user:
- cyberpunk / 80s / heavy metal visual direction
- elegant, timeless presentation rather than noisy gimmicks
- Hyprland-based desktop environment
- custom bar and customized window/transparency/animation behavior
- terminal-centered workflow
- `mero_terminal` is the centerpiece but must remain distro-agnostic and separately governed

Architecture constraint:
- changes to `mero_terminal` require explicit user approval because they must be portable across Linux distributions and wired into the separate `mero_terminal` installation flow.