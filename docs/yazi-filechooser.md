# Yazi file chooser

ArchMerOS replaces only the desktop portal's FileChooser interface with Yazi.
Hyprland still owns screenshots, screen sharing, global shortcuts, and input
capture. GTK remains second in the preference list as a safe fallback.

## Ownership

- `install/packages/base.txt` installs Yazi.
- `install/packages/optional-aur.txt` installs
  `xdg-desktop-portal-termfilechooser`.
- `config/xdg-desktop-portal/hyprland-portals.conf` selects
  `termfilechooser;gtk` for FileChooser only.
- `config/xdg-desktop-portal-termfilechooser/config` launches the upstream Yazi
  wrapper in a separate, blocking WezTerm process.
- Mero Terminal owns Yazi's application configuration, theme, and shell cwd
  wrapper. ArchMerOS owns only desktop integration.

## Apply

Install packages and link configuration, then restart the portal broker:

```bash
bash install/packages/install.sh
./install/link.sh
systemctl --user restart xdg-desktop-portal.service
```

Existing Firefox profiles, tabs, and sessions are not modified. A browser may
need to be restarted if it retains an old portal connection.

## Verify

```bash
systemctl --user status xdg-desktop-portal-termfilechooser.service
journalctl --user -u xdg-desktop-portal-termfilechooser.service -b
```

Open an upload control in Firefox. It must spawn Yazi in WezTerm, show the
selected file's preview, and return the chosen path to Firefox.

## Recovery

The configuration already falls back to GTK if termfilechooser is unavailable.
To force GTK temporarily, change the FileChooser preference to:

```ini
org.freedesktop.impl.portal.FileChooser=gtk
```

Then restart `xdg-desktop-portal.service`.
