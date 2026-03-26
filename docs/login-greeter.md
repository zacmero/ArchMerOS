# Login Greeter

ArchMerOS is currently still running **LightDM** as the live display manager.

`sysc-greet` is now vendored into the repository for safe local design work first:

- source: `vendor/sysc-greet`
- ArchMerOS data overlay: `config/greetd/sysc-greet/share`
- local fullscreen test launcher: `config/archmeros/scripts/archmeros-sysc-greet-test.sh`
- local builder: `install/build-sysc-greet.sh`

## Official Default

The current ArchMerOS greeter theme tracked in this repository is now the official default for future ArchMerOS `greetd` rollout work.

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

Nothing in this document switches the machine to `greetd` yet.

The current workflow is:

1. Build the vendored greeter against the ArchMerOS-owned data directory.
2. Run it in `--test` mode inside the current desktop session.
3. Iterate on theme, ASCII, layout, and animations there.
4. Only after validation, add a real `greetd` migration step.

If a future live greeter migration fails:

- use `Ctrl+Alt+F3` to reach a TTY
- disable `greetd`
- re-enable `lightdm`

Expected rollback commands for the later migration stage:

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
- `config/greetd/sysc-greet/kitty-greeter.conf`
- `config/greetd/sysc-greet/hyprland-greeter-config.conf`

The current first-pass palette is:

- black base
- green terminal framing
- magenta accent
- white main text

## Next Stage

Once the local test version feels correct, the next system step is:

1. install `greetd`
2. create the `greeter` user
3. copy the tracked configs into `/etc/greetd/`
4. switch from `lightdm` to `greetd`
5. keep TTY rollback ready during the first live boot tests
