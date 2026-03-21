# ArchMerOS Architecture

## Purpose

ArchMerOS is the composition layer for a personal Arch-based workstation focused on coding and creative work.

It is not the home for every tool used on the machine. Its job is to define how the system is assembled, themed, secured, and operated.

## System Context

Current host state:

- base machine currently runs EndeavourOS
- target state is an ArchMerOS system with no meaningful EndeavourOS identity left in daily use
- migration should happen incrementally, without destabilizing the workstation

This implies that ArchMerOS must support transition as well as final-state reproducibility.

## Architectural Priorities

The priorities for this repository are:

1. Fast startup into a usable coding environment
2. Strong visual identity with disciplined implementation
3. Security-conscious choices
4. Performance and low overhead
5. Clear modular boundaries
6. Reproducibility across future Arch-based installs

## Separation Of Concerns

### 1. ArchMerOS Repository

This repository owns machine composition and Arch-specific integration:

- package selection
- install/bootstrap orchestration
- system and user config deployment
- Hyprland environment behavior
- visual theming across applications
- workflow glue across tools
- host profiles and hardware-specific branches where needed

Examples:

- Hyprland config
- Waybar or alternative bar config
- notification daemon config
- launcher config
- theme palettes and shared assets
- desktop app config
- security defaults for the workstation
- migration scripts to remove or replace EndeavourOS defaults

### 2. `mero_terminal`

`mero_terminal` is separate by design.

It is a distro-agnostic terminal environment/tool and should keep its own lifecycle, repository, install logic, and portability guarantees.

ArchMerOS may:

- install it
- configure integration around it
- provide optional ArchMerOS-specific theme hooks or overrides
- document how it fits into the overall workstation flow

ArchMerOS must not silently absorb:

- `mero_terminal` source code
- distro-agnostic installer logic
- assumptions that would reduce its portability

Rule:

- configuration of `mero_terminal` consumption belongs here
- modifications to `mero_terminal` itself require explicit approval and belong in the `mero_terminal` repository

### 3. Future Shared Modules

Some pieces may deserve extraction later, but not now.

Candidates:

- shared theme token library
- reusable shell utilities
- portable config packs
- design asset repositories

Extraction should happen only if one of these becomes genuinely shared across projects. Premature repo splitting will slow down progress and obscure ownership.

## Configuration Layers

ArchMerOS should be organized in layers.

### Layer A: Base Provisioning

Defines the minimum machine state:

- core packages
- essential services
- shell/tooling prerequisites
- fonts, icon themes, cursor themes
- security packages and defaults

This layer should be conservative and dependable.

### Layer B: Session Composition

Defines the graphical environment:

- Hyprland
- bar
- notification daemon
- launcher
- lock screen
- wallpaper handling
- portal and clipboard support

This is where the main aesthetic and workflow identity becomes visible.

### Layer C: Application Integration

Defines how individual tools fit the system:

- terminal integration
- editor config integration
- browser theming alignment
- file manager integration
- media and creative tooling

This layer should stay modular so individual tools can be swapped with low friction.

### Layer D: Host Profiles

Defines optional differences by machine or use case:

- laptop
- desktop
- NVIDIA-specific adjustments
- low-power profile
- creative workstation profile

Profiles should be additive overrides, not forks of the whole configuration tree.

## Security Posture

This machine is intended to be a pristine coding workstation. Security is a first-class concern.

Guidelines:

- prefer established components over unstable experiments
- minimize always-on background services
- keep the package surface area intentional
- avoid unnecessary privilege escalation in scripts
- document any service enabled at boot
- separate trusted local configuration from fetched external assets
- prefer explicit configuration over opaque helper tooling

Security here does not mean visual austerity. It means disciplined software choices and transparent system behavior.

## Performance Posture

The aesthetic target includes transparency and animation, but performance remains a hard constraint.

Guidelines:

- lean animations only
- visual effects should degrade cleanly on weaker hardware
- avoid stacks of redundant daemons
- prefer native Wayland-friendly tooling where practical
- make optional effects easy to disable by profile

The system should feel sharp, not busy.

## Migration Strategy From EndeavourOS

The current machine starts as EndeavourOS, but ArchMerOS should progressively replace its identity.

Practical migration categories:

- remove Endeavour-branded theming and defaults
- replace default desktop/session behavior with ArchMerOS choices
- audit installed packages and remove unneeded distribution conveniences
- reassert package lists through ArchMerOS manifests
- document any transitional compatibility choices

The migration must be controlled. Removing traces of EndeavourOS should not come at the cost of breaking the workstation.

## Initial Tooling Choices

Near-term bias:

- Hyprland as the compositor/window manager
- established supporting tools around it
- no commitment yet on graphical file manager
- `mero_terminal` remains the core terminal experience

Unknowns such as the file manager should be treated as replaceable integrations, not central architecture.

## Repository Boundaries

Recommended initial tree:

```text
ArchMerOS/
  README.md
  docs/
    architecture.md
    deployment-model.md
    decisions/
  install/
    bootstrap.sh
    link.sh
    packages/
    profiles/
  config/
    hypr/
    waybar/
    rofi/
    walker/
    archmeros/
    gtk/
    qt/
    wallpapers/
    fonts/
  themes/
    palette/
    assets/
  integration/
    mero-terminal/
```

Boundary rules:

- `install/` owns reproducibility
- `config/` owns concrete tool configuration
- `themes/` owns shared aesthetic primitives
- `integration/` owns seams with external tools
- `docs/decisions/` should capture important architectural choices as they are made
- deployment into live config paths is symlink-based, not copy-based

## Decision Heuristic

When adding a new component, ask:

1. Is it Arch-specific or distro-agnostic?
2. Is it part of system composition or an upstream product?
3. Does it improve speed, clarity, aesthetics, or security in a measurable way?
4. Can it be disabled or replaced without breaking the whole setup?

If the answer implies portability or independent reuse, it probably should not live directly inside this repository.

## Immediate Next Architectural Work

- define the aesthetic system from current references and `mero_terminal`
- scaffold the repository structure
- choose the first stable Hyprland companion stack
- define package manifests and security baseline
- map transition steps from EndeavourOS defaults to ArchMerOS defaults
