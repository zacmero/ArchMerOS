# ArchMerOS Recovery Guide

This guide is the safety net for future bootloader work.

The main point:

- same-disk backups are good for rollback
- a live USB is what lets you boot something else if GRUB itself stops working

## What You Need

- `1` USB stick
- `8 GB` minimum
- `16 GB+` recommended
- modern `x86_64` Linux ISO files for UEFI boot

This machine is a normal `x86_64` PC running a UEFI-style Linux install. Do not use ARM images.

## Recommended Rescue ISO Files

As of `2026-03-23`, the safest choices are:

- `archlinux-2026.01.01-x86_64.iso`
- `EndeavourOS_Titan-2026.03.06.iso`

Why these:

- Arch ISO is the clean upstream rescue environment
- EndeavourOS ISO is often easier if you want a friendlier live session close to this system's origin

You only need one of them. Keeping both is better.

## Official Sources

- Arch Linux download page: https://archlinux.org/download/
- Arch Linux release page: https://archlinux.org/releng/releases/2026.01.01/
- EndeavourOS download page: https://endeavouros.com/
- Ventoy docs: https://www.ventoy.net/en/doc_start.html
- Ventoy download page: https://www.ventoy.net/en/download.html

## Why The USB Matters

The bootloader backups can live on the same SSD just fine. In fact, the ArchMerOS GRUB apply script stores them on the installed system.

Example backup location:

- `/boot/grub/archmeros-backups/<timestamp>/`

That protects you if Linux still boots, or if you can reach the installed disk from a live session.

What it does not protect you from:

- GRUB fails before you can boot the installed system

In that case the backup files are still there, but you need another environment to boot from so you can restore them. That is what the USB is for.

## Easiest USB Method: Ventoy

Ventoy is the easiest beginner path because you install Ventoy once, then just copy ISO files onto the USB like normal files.

Important:

- installing Ventoy erases the USB stick
- anything already on that USB will be lost

## Create The Rescue USB On Linux

### 1. Download Ventoy

Download the current Linux package from:

- https://www.ventoy.net/en/download.html

It will be a file like:

- `ventoy-x.x.xx-linux.tar.gz`

### 2. Extract It

Example:

```bash
cd ~/Downloads
tar -xzf ventoy-*-linux.tar.gz
cd ventoy-*-linux
```

### 3. Identify The USB Device

Plug the USB stick in, then run:

```bash
lsblk
```

Find the whole USB device, for example:

- `/dev/sdb`
- not `/dev/sdb1`

Be careful here. Picking the wrong disk will erase the wrong disk.

### 4. Install Ventoy To The USB

Example:

```bash
sudo ./Ventoy2Disk.sh -i /dev/sdX
```

Replace `/dev/sdX` with the actual USB device.

Example only:

```bash
sudo ./Ventoy2Disk.sh -i /dev/sdb
```

### 5. Copy The ISO Files

After Ventoy finishes, unplug and replug the USB if needed. Then copy the ISO files onto the main Ventoy partition.

You can simply drag them there in the file manager, or use `cp`.

Files to copy:

- `archlinux-2026.01.01-x86_64.iso`
- `EndeavourOS_Titan-2026.03.06.iso`

You do not need to extract the ISOs.

## Verify The ISO Files

This is worth doing at least once.

### Arch

Check the SHA256 against the official release page:

```bash
sha256sum archlinux-2026.01.01-x86_64.iso
```

Official release page:

- https://archlinux.org/releng/releases/2026.01.01/

### EndeavourOS

The EndeavourOS homepage provides the `sha512` file and GPG signature for the current ISO.

Checksum example:

```bash
sha512sum -c EndeavourOS_Titan-2026.03.06.iso.sha512
```

Signature example:

```bash
gpg --recv CDF595A1
gpg --verify EndeavourOS_Titan-2026.03.06.iso.sig
```

Official download page:

- https://endeavouros.com/

## Test The USB Before Any GRUB Change

Do this once before touching the bootloader.

1. Reboot the machine.
2. Open the firmware boot menu.
3. Select the USB stick.
4. Confirm Ventoy appears.
5. Confirm at least one ISO boots into a live environment.
6. Shut down and boot back into the installed system.

If the USB boots successfully, then you have a real recovery path.

## Current Disk Notes For This Machine

Observed during setup work:

- likely Linux root: `/dev/sdc1`
- likely Linux swap: `/dev/sdc2`
- likely EFI partition: `/dev/sda1`

Do not trust those blindly during recovery. Always verify with:

```bash
lsblk -f
```

Labels, mountpoints, and drive order can differ depending on what is plugged in.

## If GRUB Breaks

The usual recovery idea is:

1. boot from the USB
2. mount the installed Linux root partition
3. access the saved GRUB backups on that disk
4. restore the old files
5. regenerate GRUB config
6. reboot

## Basic Recovery Flow

### 1. Boot The Live USB

Use either:

- Arch ISO
- EndeavourOS ISO

### 2. Find The Installed Linux Partitions

Run:

```bash
lsblk -f
```

Look for:

- your Linux root partition
- your EFI system partition

### 3. Mount The Installed System

Example only:

```bash
sudo mount /dev/sdc1 /mnt
```

If the EFI partition exists and you need it later, mount it too after checking the correct mountpoint layout:

```bash
sudo mkdir -p /mnt/boot/efi
sudo mount /dev/sda1 /mnt/boot/efi
```

Note:

- some systems use `/boot`
- some use `/efi`
- check the installed system layout first

### 4. Inspect The ArchMerOS GRUB Backups

The GRUB apply script stores backups like this:

```bash
ls -la /mnt/boot/grub/archmeros-backups
```

Then inspect the latest timestamp folder:

```bash
ls -la /mnt/boot/grub/archmeros-backups/<timestamp>
```

Expected files:

- `grub`
- `40_custom`
- `grub.cfg`

These correspond to:

- `/etc/default/grub`
- `/etc/grub.d/40_custom`
- `/boot/grub/grub.cfg`

### 5. Restore The Old Files

Example:

```bash
sudo cp /mnt/boot/grub/archmeros-backups/<timestamp>/grub /mnt/etc/default/grub
sudo cp /mnt/boot/grub/archmeros-backups/<timestamp>/40_custom /mnt/etc/grub.d/40_custom
sudo cp /mnt/boot/grub/archmeros-backups/<timestamp>/grub.cfg /mnt/boot/grub/grub.cfg
```

### 6. Rebuild GRUB From Inside The Installed System

Chroot in:

```bash
sudo arch-chroot /mnt
```

Then rebuild:

```bash
grub-mkconfig -o /boot/grub/grub.cfg
exit
```

If `arch-chroot` is not present on the chosen live ISO, use the distro's equivalent or boot the Arch ISO.

### 7. Reboot

```bash
sudo reboot
```

Remove the USB when the firmware screen appears if needed.

## When `grub-reboot` Helps

`grub-reboot` is useful for one-time testing only if GRUB itself still loads correctly.

It is not a separate rescue system.

If GRUB is readable and working, one-time boot testing is excellent.
If GRUB is badly broken, `grub-reboot` cannot save you because the broken thing is GRUB itself.

## Lowest-Risk ArchMerOS Bootloader Rollout

For the first live ArchMerOS bootloader pass:

1. Prepare and test the rescue USB first.
2. Keep stock generated GRUB entries available.
3. Apply only branding/theme changes first.
4. Reboot once and confirm GRUB is still readable.
5. Only after that, consider hiding menus or preferring custom entries.

That is the correct first-time path.
