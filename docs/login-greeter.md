# Login Greeter

`sysc-greet` is now vendored into the repository for safe local design work first:

- source: `vendor/sysc-greet`
- ArchMerOS data overlay: `config/greetd/sysc-greet/share`
- local fullscreen test launcher: `config/archmeros/scripts/archmeros-sysc-greet-test.sh`
- local builder: `install/build-sysc-greet.sh`

## Official Default

The current ArchMerOS greeter theme tracked in this repository is now the official ArchMerOS login default.

Default behavior baked into the vendored greeter:

- theme: `archmeros`
- login background: `ascii-rain`
- logo animation: `pour`
- terminal/login box: opaque terminal frame on top of the background
- screensaver logo animation: `beams`
- screensaver color behavior: one whole-logo color per beams cycle

The repo-owned theme state lives in:

- `vendor/sysc-greet/cmd/sysc-greet/main.go`
- `vendor/sysc-greet/cmd/sysc-greet/ascii.go`
- `vendor/sysc-greet/internal/animations/rain.go`
- `vendor/sysc-greet/internal/animations/palettes.go`
- `config/greetd/sysc-greet/share/themes/archmeros.toml`
- `config/greetd/sysc-greet/share/ascii_configs/hyprland.conf`
- `config/greetd/sysc-greet/share/ascii_configs/xfce.conf`
- `config/greetd/sysc-greet/share/ascii_configs/screensaver.conf`

## Safety Boundary

The repo now includes a real system apply path for switching from `lightdm` to `greetd`.

If a live greeter migration fails:

- use `Ctrl+Alt+F3` to reach a TTY
- disable `greetd`
- re-enable `lightdm`

Rollback commands:

```bash
sudo systemctl disable greetd
sudo systemctl enable lightdm
sudo systemctl restart lightdm
```

## Local Test Commands

Build only:

```bash
bash install/build-sysc-greet.sh
```

Fullscreen preview in kitty:

```bash
bash config/archmeros/scripts/archmeros-sysc-greet-test.sh
```

That command previews the official ArchMerOS default greeter state as tracked in this repository.

Inline preview in the current terminal:

```bash
bash config/archmeros/scripts/archmeros-sysc-greet-test.sh --inline
```

Debug preview:

```bash
bash config/archmeros/scripts/archmeros-sysc-greet-test.sh --debug
```

Screensaver preview:

```bash
bash config/archmeros/scripts/archmeros-sysc-greet-test.sh --screensaver
```

## ArchMerOS-Owned Assets

Current tracked greeter assets live here:

- `config/greetd/sysc-greet/share/themes/archmeros.toml`
- `config/greetd/sysc-greet/share/ascii_configs/hyprland.conf`
- `config/greetd/sysc-greet/share/ascii_configs/xfce.conf`
- `config/greetd/sysc-greet/share/ascii_configs/screensaver.conf`
- `config/greetd/sysc-greet/kitty-greeter.conf`
- `config/greetd/sysc-greet/hyprland-greeter-config.conf`
- `config/greetd/sysc-greet/archmeros-greeter-session.sh`
- `config/greetd/sysc-greet/archmeros-start-hyprmero.sh`
- `install/system/apply-greeter-system.sh`
- `install/system/etc/greetd/config.toml`
- `install/system/etc/polkit-1/rules.d/85-greeter.rules`

The current first-pass palette is:

- black base
- green terminal framing
- magenta accent
- white main text

## System Apply

To make the ArchMerOS greeter the real login default on a machine:

```bash
sudo bash install/system/apply-greeter-system.sh
```

That script currently:

1. installs `greetd` and `kitty`
2. builds the ArchMerOS-owned `sysc-greet` binary with a system data path
3. installs the tracked theme and ASCII assets under `/usr/local/share/archmeros/sysc-greet/share`
4. installs quiet wrapper launchers for the greeter session and `HyprMero`
5. installs `/etc/greetd/config.toml`
6. installs the tracked Hyprland and kitty greeter configs into `/etc/greetd/`
7. redirects greeter and `HyprMero` stdout/stderr into log files instead of leaving them on the TTY
8. launches the greeter with a direct `Hyprland -c ...` wrapper instead of `start-hyprland`, and pre-creates the greeter XDG cache/config/state dirs
9. creates or updates the `greeter` user with `video,render,input`
10. installs the greeter polkit rule
11. disables `lightdm`
12. enables `greetd`

## NVIDIA Stability Note

On the current ArchMerOS stack, the greetd Hyprland greeter is intentionally started through the repo wrapper:

- `config/greetd/sysc-greet/archmeros-greeter-session.sh`

That wrapper exports a real greeter `HOME` plus `XDG_CACHE_HOME`, `XDG_CONFIG_HOME`, `XDG_STATE_HOME`, and `XDG_DATA_HOME`, creates those directories, and then launches:

```bash
Hyprland -c /etc/greetd/hyprland-greeter-config.conf
```

This is deliberate. It avoids the more fragile `start-hyprland` path that was causing black-screen greeter failures after the NVIDIA driver migration.
