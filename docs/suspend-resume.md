# Suspend and Resume

## Workstation Policy

ArchMerOS uses `s2idle` for normal suspend on this workstation. The kernel
offers both `s2idle` and ACPI S3 (`deep`), but recorded S3 attempts on
2026-08-31 and 2026-09-03 ended in an unclean reboot immediately after
`PM: suspend entry (deep)`. No kernel resume event was recorded.

The tracked policy is:

- `install/system/etc/systemd/sleep.conf.d/90-archmeros-resume.conf`
- `install/system/apply-sleep-system.sh`

Apply it with:

```bash
sudo bash install/system/apply-sleep-system.sh
```

The installer makes a timestamped backup if it would replace an existing
ArchMerOS sleep policy. NVIDIA's suspend, resume, and hibernate services remain
enabled and unchanged.

## Verification

Before testing a real suspend, save active work. Then verify the effective
policy and available kernel backends:

```bash
systemd-analyze cat-config systemd/sleep.conf
cat /sys/power/mem_sleep
systemctl is-enabled nvidia-suspend.service nvidia-resume.service
```

The effective config must contain `MemorySleepMode=s2idle`. The sysfs output
shows the currently selected backend in brackets; systemd selects `s2idle`
when the next suspend begins.

After a controlled suspend/resume test, verify that the same boot continued:

```bash
journalctl -b -g 'suspend entry|suspend exit|System returned from sleep'
```

A healthy cycle contains both suspend entry and exit/resume records. A new boot
without a resume record means the platform still reset and requires testing the
installed LTS kernel before further power-management changes.

## Hibernation

Hibernation has resumed successfully on this workstation and remains available
as a fallback. It is not substituted automatically for suspend because its
capacity depends on the 8 GiB swap partition and current memory usage.
