# Bootloader

## Current Default

ArchMerOS currently defaults to the plain GRUB `gfxterm` selector rather than a full GRUB theme.

That means the real boot screen uses:

- custom menu labels from `/etc/grub.d/40_custom`
- a custom mono GRUB font
- custom menu colors
- no active `GRUB_THEME`

This path was chosen because it preserves the classic terminal-style selector reliably.

## Files

- bootloader apply script: `install/system/apply-bootloader-system.sh`
- system apply entrypoint: `install/system/apply-system.sh`
- preview helper: `install/system/grub-preview.sh`
- tracked theme assets: `config/grub/themes/archmeros-80s/theme.txt`

## Apply On A Live System

From the repository root:

```bash
sudo bash install/system/apply-system.sh
```

If you only want the bootloader step:

```bash
sudo bash install/system/apply-bootloader-system.sh
```

If you are migrating an older BIOS/CSM ArchMerOS install onto a shared Windows EFI partition:

```bash
sudo bash install/system/apply-bootloader-shared-esp-system.sh
```

The bootloader script:

- backs up `/etc/default/grub`
- backs up `/etc/grub.d/40_custom`
- backs up `/etc/grub.d/10_linux`
- backs up `/boot/grub/grub.cfg`
- regenerates GRUB fonts under `/boot/grub/themes/archmeros-80s`
- rewrites the ArchMerOS menu entries
- regenerates `/boot/grub/grub.cfg`

`install/system/apply-system.sh` now auto-selects this shared-ESP path when the machine looks like the Windows-owned/shared-ESP layout used on this workstation. The manual script remains available when you want to force the migration yourself.

The tracked menu also includes two direct fallback entries:

- `Arch Plain Recovery` with hotkey `p`
- `Arch LTS Plain Recovery` with hotkey `b`

Those boot to `multi-user.target` with `nomodeset` so they bypass more of the graphical/NVIDIA stack.

The shared-ESP migration script additionally:

- detects or accepts the shared EFI partition
- mounts it at `/boot/efi`
- backs up the current EFI contents
- adds `/boot/efi` to `/etc/fstab`
- installs `EFI/ArchMerOS/grubx64.efi` without touching `EFI/Microsoft`
- uses `--no-nvram` automatically if the current Linux session is still booted in BIOS/CSM mode

On GRUB-based ArchMerOS systems, boot image generation is also pinned away from Boot Loader Specification layout through:

- [install/system/etc/kernel/install.conf](/home/zacmero/projects/ArchMerOS/install/system/etc/kernel/install.conf)

That forces `kernel-install` to `layout=other`, so future kernel or dracut updates keep using the classic `/boot/vmlinuz-*` and `/boot/initramfs-*.img` path instead of trying to write entries under `/boot/efi/<machine-id>/...`.

Backups are written to:

```text
/boot/grub/archmeros-backups/YYYYMMDD-HHMMSS
```

## Default Plain Selector Settings

The current GRUB defaults written by the apply script are:

- `GRUB_TIMEOUT_STYLE=menu`
- `GRUB_TERMINAL_OUTPUT=gfxterm`
- `GRUB_FONT=/boot/grub/themes/archmeros-80s/DejaVuSansMono18.pf2`
- `GRUB_COLOR_NORMAL='light-cyan/black'`
- `GRUB_COLOR_HIGHLIGHT='black/light-magenta'`
- `GRUB_THEME` commented out

## Preview

`grub2-theme-preview` is only useful for the old theme path and is not fully trustworthy for the current plain selector mode.

The practical test for the current setup is an actual reboot.

If you still want to inspect the generated bootloader config:

```bash
sudo grep -n 'terminal_output\|loadfont\|menu_color_\|menuentry ' /boot/grub/grub.cfg
```

## Notes

- The plain selector can change font, entry labels, and colors.
- The plain selector cannot cleanly replace the top `GNU GRUB version ...` header with a custom `ARCHMEROS` title.
- If ArchMerOS later moves back to a full GRUB theme, the `GRUB_THEME` path can be re-enabled in the apply script.
- If Linux is currently booted in BIOS/CSM mode, EFI files can still be installed safely, but firmware boot order cannot be rewritten from that session. In that case, rerun the shared-ESP script from a UEFI-booted ArchMerOS session or add `\EFI\ArchMerOS\grubx64.efi` manually in firmware.
- The normal `install/system/apply-system.sh` entrypoint now detects this shared-ESP layout and applies it automatically on matching hardware, so new ArchMerOS installs do not need the extra manual step on this machine class.
