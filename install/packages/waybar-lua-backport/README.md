# Waybar Hyprland Lua backport

## Problem

Arch Linux Waybar 0.15.0 hardcodes legacy
`dispatch workspace <id>` requests inside each `hyprland/workspaces` button.
Hyprland's Lua config provider evaluates that request as invalid Lua, so the
workspace numbers render normally but mouse clicks do nothing. The configured
`"on-click": "activate"` value cannot override the hardcoded button handler.

Switching to `ext/workspaces` would make activation protocol-native, but it
would remove ArchMerOS behavior: persistent `1-5` buttons, filtering of service
workspaces `10/11`, and the current multi-output presentation. This backport
keeps `hyprland/workspaces` and every existing Waybar configuration unchanged.

## Backport

The package is the official Arch Waybar 0.15.0 build with local release
`2.1`. It preserves Arch's dependency list and feature flags, limits
compilation to two jobs, and applies only these upstream fixes:

- `e17c0d9f`: translate workspace dispatches for the Lua provider
- `cdb792af`: preserve `move-to-monitor` behavior
- `74cf45d5`: detect the Lua protocol with a read-only version query

The first patch's workspace-scroll hunk is excluded because Waybar 0.15.0 does
not contain that later scroll implementation. ArchMerOS also keeps workspace
scrolling disabled. The workspace-button and IPC backend fixes are unchanged.

## Build And Install

```bash
cd /home/zacmero/projects/ArchMerOS/install/packages/waybar-lua-backport
rtk makepkg -si
rtk ~/.config/archmeros/scripts/archmeros-waybar.sh restart
```

`check()` removes `HYPRLAND_INSTANCE_SIGNATURE` from the test environment so
Waybar's IPC tests cannot connect to or manipulate the live compositor. The
expected test result is three passing suites: `waybar`, `hyprland`, and
`utils`.

## Verify

```bash
rtk pacman -Q waybar
rtk rg 'detected Lua-based dispatch protocol' /tmp/archmeros-waybar-*.log
```

The installed version should be `waybar 0.15.0-2.1`. The Lua-protocol log line
appears after the first workspace-button click.

## Upgrade And Rollback

Remove this backport after the repository Waybar package includes all three
upstream commits. After any Waybar upgrade, retest a workspace click before
removing this directory.

The original Arch package remains in the pacman cache and can restore the
previous binary without touching user Waybar configuration:

```bash
rtk sudo pacman -U /var/cache/pacman/pkg/waybar-0.15.0-2-x86_64.pkg.tar.zst
rtk ~/.config/archmeros/scripts/archmeros-waybar.sh restart
```
