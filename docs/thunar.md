# Thunar ownership and installation

ArchMerOS treats its Thunar behavior as OS configuration. Stable policy is
tracked here; mutable per-user state remains outside Git.

## Factory-owned files

| Concern | Repository source | Installation behavior |
| --- | --- | --- |
| Keyboard focus motions | `install/packages/thunar-keyboard-navigation/` | Built and installed as a Pacman package by `install/packages/install.sh` |
| Custom actions | `config/thunar/uca.xml` | Symlinked to `~/.config/Thunar/uca.xml` |
| Rename accelerator | `config/thunar/accels.scm` | Copied only when `~/.config/Thunar/accels.scm` does not exist |
| Stable XFConf defaults | `config/thunar/xfconf-defaults.xml` | Copied only when the Thunar XFConf file does not exist |
| Directory default | `config/mimeapps.list` | Sets `inode/directory=thunar.desktop` |
| Launcher desktop entry | `local/share/applications/thunar.desktop` | Symlinked into `~/.local/share/applications` |
| Launch, sizing, reopen history | `config/archmeros/scripts/archmeros-thunar*.sh` | Symlinked through the ArchMerOS script tree |
| Window placement | `config/hypr/` | Applied by the selected HyprMero session |

The XFConf seed contains only stable preferences: details view, zoom levels,
shortcuts sidebar, double-click activation, and non-expandable folder rows.
Window size, maximized state, column widths, separator position, sorting, and
visibility state are runtime data. They must not be symlinked to the repository
or overwritten on an existing installation.

## Keyboard contract

- File view to sidebar: `Left` or `Ctrl+H`.
- Sidebar to file view: `Right` or `Ctrl+L`.
- File view to location entry: `Ctrl+K`, or a second `Up` after reaching the
  first row.
- Location entry to file view: `Down`, `Ctrl+J`, or `Escape`.
- Sidebar arrows move the highlight; `Enter` opens the highlighted folder.
- Bare letters retain native filename type-ahead.

The source patch processes custom transitions on key press only. Handling the
same transition on key release collapses the two-step top boundary and makes the
file row and location entry appear focused together.

## Installation lifecycle

`install/packages/install.sh` installs upstream repository packages first, then
runs the custom package helper. The helper clean-builds the pinned Thunar source
and installs every generated package with Pacman. `install/link.sh` then links
authoritative files and seeds non-authoritative defaults without replacing an
existing user's configuration.

The package is intentionally pinned to Thunar 4.20.9. Before accepting a Thunar
upgrade, update the PKGBUILD, rebase the patch, rebuild, run the complete motion
contract, and verify package ownership. Do not let a repository upgrade silently
replace the patched build, and do not copy binaries directly into `/usr/bin`.

## Verification

```bash
pacman -Q thunar
sudo pacman -Qkk thunar
xdg-mime query default inode/directory
```

Then open a fresh Thunar process and test every keyboard transition, native
filename type-ahead, mouse side-button history, custom actions, launch sizing,
and reopen history.

## File upload dialogs

Firefox and other sandbox-aware applications request file selection through
`xdg-desktop-portal`. In HyprMero, the FileChooser interface is supplied by
`xdg-desktop-portal-gtk`. That chooser is a GTK dialog, not a Thunar window.
Setting Thunar as the directory MIME handler makes folders open in Thunar, but
cannot make browser upload dialogs inherit Thunar previews, zoom, or navigation.
A different upload chooser requires selecting another compatible portal backend;
it is independent of the system file-manager default.
