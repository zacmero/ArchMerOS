# ArchMerOS Update Workflow

## Goal

Keep security updates moving without pushing the CPU into a long, sustained 100C rebuild session.

## Fast Path

Use this for normal repo updates:

```bash
sudo pacman -Syu
```

This is the lowest-risk path when you only need repo packages and the kernel/security fixes.

## Throttled AUR / Rebuild Path

Use this when `yay` needs to rebuild heavy packages such as NVIDIA modules, GCC-related tooling, or other AUR packages:

```bash
systemd-run --user --scope \
  -p CPUQuota=60% \
  -p IOWeight=50 \
  nice -n 10 ionice -c2 -n7 \
  yay -Syu
```

What this does:

- `CPUQuota=60%` caps the process tree so it cannot pin all cores for long periods.
- `IOWeight=50` lowers I/O pressure during package downloads and rebuilds.
- `nice -n 10` reduces CPU scheduling priority.
- `ionice -c2 -n7` reduces disk I/O priority.

If you want it even gentler, lower the quota:

```bash
systemd-run --user --scope -p CPUQuota=40% -p IOWeight=30 nice -n 15 ionice -c2 -n7 yay -Syu
```

## Why the CPU Spikes

The heavy part is usually not the repository download. It is the post-transaction work:

- DKMS rebuilding NVIDIA modules
- `dracut` regenerating initramfs images
- AUR package compilation
- GCC-related rebuilds and delta work

Those steps can legitimately keep a desktop CPU at 100% for a long time if they run unrestricted.

## Safety Order

1. Update repo packages first.
2. Reboot if the kernel or NVIDIA stack changed.
3. Run AUR rebuilds later, throttled.

That keeps the security fix landings separate from the expensive rebuild work.

## Cleanup After Interrupted Updates

If an update is interrupted, clean the residue in this order:

```bash
sudo paccache -r -k 1
sudo find /var/cache/pacman/pkg -maxdepth 1 -type d -name 'download-*' -exec rm -rf {} +
pacman -Qdtq
```

Then review and remove orphans only if you recognize them.

## Current ArchMerOS Defaults

ArchMerOS already carries a build throttle for shell sessions:

- `MAKEFLAGS=-j2`
- `CMAKE_BUILD_PARALLEL_LEVEL=2`

That helps with builds, but it does not replace throttling the `yay` update command itself.

## Practical Rule

If you only need the security fix, do not let AUR rebuilds ride along unless you actually want them.
