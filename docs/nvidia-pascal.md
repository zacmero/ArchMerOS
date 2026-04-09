# NVIDIA Pascal Profile

This workstation uses a GTX 1060 6GB (`GP104`, Pascal family). On the current Arch/Endeavour package set, that card no longer belongs on the mainline `nvidia` package. The tracked ArchMerOS path is the legacy `580xx` branch from the AUR.

## Package Sets

Official repo packages:

- [install/profiles/nvidia-pascal.txt](/home/zacmero/projects/ArchMerOS/install/profiles/nvidia-pascal.txt)

AUR packages:

- [install/profiles/nvidia-pascal-aur.txt](/home/zacmero/projects/ArchMerOS/install/profiles/nvidia-pascal-aur.txt)

## Apply Flow

1. Install the packages:

```bash
yay -S --needed nvidia-580xx-dkms nvidia-580xx-utils nvidia-580xx-settings opencl-nvidia-580xx egl-wayland libva-nvidia-driver
```

2. Apply the tracked boot/initramfs configuration:

```bash
sudo bash install/system/apply-nvidia-system.sh
```

3. Reboot.

If you use the main ArchMerOS system apply path instead of the standalone NVIDIA script, `install/system/apply-system.sh` now auto-runs the NVIDIA profile when it detects an NVIDIA GPU on the machine.

## What The System Apply Script Does

[install/system/apply-nvidia-system.sh](/home/zacmero/projects/ArchMerOS/install/system/apply-nvidia-system.sh) installs:

- [install/system/etc/modprobe.d/archmeros-nvidia.conf](/home/zacmero/projects/ArchMerOS/install/system/etc/modprobe.d/archmeros-nvidia.conf)
- [install/system/etc/dracut.conf.d/archmeros-nvidia.conf](/home/zacmero/projects/ArchMerOS/install/system/etc/dracut.conf.d/archmeros-nvidia.conf)
- [install/system/etc/kernel/install.conf](/home/zacmero/projects/ArchMerOS/install/system/etc/kernel/install.conf)

Then it:

- appends the NVIDIA kernel parameters to `/etc/default/grub`
- forces `kernel-install` into GRUB-safe `layout=other`
- rebuilds classic `/boot/initramfs-*.img` images explicitly for each installed kernel
- regenerates `/boot/grub/grub.cfg`

The full `install/system/apply-system.sh` entrypoint now also detects NVIDIA hardware and applies this profile automatically on matching machines, so new ArchMerOS installs do not need a separate manual NVIDIA step when the GPU is present.

## Update Safety

The ArchMerOS NVIDIA dracut profile uses `add_drivers`, not `force_drivers`.

Reason:

- `force_drivers` is more fragile during mixed-kernel updates if one installed kernel does not currently have matching NVIDIA DKMS modules
- `add_drivers` still includes the NVIDIA modules when available, but does not hard-require them for every image
- `uefi="no"` is set because ArchMerOS currently boots through GRUB and does not rely on dracut-built UKI images in the ESP
- `/etc/kernel/install.conf` sets `layout=other`, so systemd `kernel-install` does not try to write Boot Loader Specification entries into `/boot/efi/<machine-id>/...`
- the apply script no longer relies on `dracut --regenerate-all`, which is the path that can fall back to the wrong default boot root on mixed Endeavour/GRUB installs

The tracked GRUB profile also installs two plain fallback entries:

- `Arch Plain Recovery` hotkey `p`
- `Arch LTS Plain Recovery` hotkey `b`

Those are the first recovery path if a future graphics/NVIDIA update breaks the normal graphical boot path.

## Verification After Reboot

```bash
lspci -nnk | sed -n '/NVIDIA/,/Kernel modules/p'
nvidia-smi
```

Expected result:

- `Kernel driver in use: nvidia`
- `nvidia-smi` returns real GPU information instead of `command not found`

## ArchMerOS Session Notes

The Hyprland session and greeter config now export:

- `LIBVA_DRIVER_NAME=nvidia`
- `__GLX_VENDOR_LIBRARY_NAME=nvidia`
- `NVD_BACKEND=direct`

Those are tracked in:

- [config/hypr/hyprland.conf](/home/zacmero/projects/ArchMerOS/config/hypr/hyprland.conf)
- [config/greetd/sysc-greet/hyprland-greeter-config.conf](/home/zacmero/projects/ArchMerOS/config/greetd/sysc-greet/hyprland-greeter-config.conf)

## Connector Mapping After NVIDIA Switch

On this machine, the NVIDIA driver changes the center HDMI connector name from `HDMI-A-4` to `HDMI-A-1`.

The current tracked ArchMerOS monitor layout is:

- left: `DP-3`
- center: `HDMI-A-1`
- right: `DP-2`

That mapping is applied in both the normal Hyprland session and the greetd greeter so the live session and login screen stay consistent.
