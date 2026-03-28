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

## What The System Apply Script Does

[install/system/apply-nvidia-system.sh](/home/zacmero/projects/ArchMerOS/install/system/apply-nvidia-system.sh) installs:

- [install/system/etc/modprobe.d/archmeros-nvidia.conf](/home/zacmero/projects/ArchMerOS/install/system/etc/modprobe.d/archmeros-nvidia.conf)
- [install/system/etc/dracut.conf.d/archmeros-nvidia.conf](/home/zacmero/projects/ArchMerOS/install/system/etc/dracut.conf.d/archmeros-nvidia.conf)

Then it:

- appends the NVIDIA kernel parameters to `/etc/default/grub`
- regenerates all `dracut` initramfs images
- regenerates `/boot/grub/grub.cfg`

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
