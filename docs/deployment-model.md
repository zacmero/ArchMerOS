# Deployment Model

## Source Of Truth

This repository is the source of truth for ArchMerOS configuration.

Live desktop configuration should not be edited as detached files under `~/.config`. Instead, tracked files in this repository should be linked into the live config paths.

## Deployment Rule

Deployment is symlink-based.

Use symlinks, not copies.

Reason:

- one canonical version of each file
- easier review and version control
- no drift between repository state and live config
- safer iteration while ArchMerOS is still evolving

## Live Config Targets

Typical targets:

- `~/.config/hypr`
- `~/.config/waybar`
- `~/.config/walker`
- `~/.config/rofi`
- `~/.config/mako`
- `~/.config/archmeros`

The repository should own the contents. The live filesystem should mostly be a linked projection of the repository.

## Session Separation

Symlinking ArchMerOS configs into `~/.config` does not remove XFCE.

It only makes ArchMerOS-owned tools resolve their config from this repository. XFCE will continue to use its own config under:

- `~/.config/xfce4`

This means the system can safely host both sessions during migration.

## Installation Phases

### Phase 1

- create repository structure
- write docs
- build package manifests
- deploy config by symlink only when explicitly requested

### Phase 2

- install Hyprland stack
- link ArchMerOS configs into `~/.config`
- test Hyprland as a secondary session

### Phase 3

- migrate daily work to Hyprland
- audit and remove obsolete Endeavour/XFCE defaults only after stability is proven

## Safety Rule

Any deploy script must:

- show what it will link
- preserve or back up conflicting unmanaged paths
- avoid destructive replacement of unrelated files
- make rollback obvious
