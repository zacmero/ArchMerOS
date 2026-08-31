# Thunar keyboard navigation

ArchMerOS carries a narrow Thunar 4.20.9 patch for deterministic keyboard
focus movement between the file view, sidebar, and location entry. It is
implemented inside Thunar and does not add Hyprland or system-wide keyboard
remaps.

## Motion contract

| Focus | Key | Result |
| --- | --- | --- |
| File view | `Left`, `Ctrl+H` | Focus the visible sidebar |
| Sidebar | `Right`, `Ctrl+L` | Focus the file view |
| File view | `Up`, `Down` | Traverse files and folders |
| File view, first row | Another `Up` | Focus and select the location entry |
| File view | `Ctrl+K` | Focus and select the location entry directly |
| Location entry | `Down`, `Escape`, `Ctrl+J` | Return focus to the file view |
| Sidebar | `Up`, `Down` | Move the highlight only |
| Sidebar | `Enter` | Open the highlighted folder |

Bare letters remain available for native filename type-ahead. The file-view
top boundary is intentionally two-step: the first `Up` reaches
the first row and a separate second `Up` focuses the location entry. `Ctrl+H`
only changes focus while the file view owns focus. Text typed in the location
entry and unrelated GTK shortcuts remain untouched.

## Implementation

The patch changes three upstream files:

- `thunar/thunar-window.c` owns zone detection, focus transfer, Vim motion
  translation, top-row detection, and the key-press-only boundary rule.
- `thunar/thunar-shortcuts-view.c` stops arrow release from opening the newly
  highlighted Places shortcut.
- `thunar/thunar-tree-view.c` stops arrow press from opening the newly
  highlighted tree folder.

Keyboard focus navigation must run only for `GDK_KEY_PRESS`. Processing the
same motion again on key release makes the release observe the newly selected
top row and incorrectly focuses the location entry immediately. The sidebar
changes affect keyboard traversal only; native mouse activation, row
activation, and explicit `Enter` remain intact.

## Build and install

The ArchMerOS factory package phase invokes `install.sh` in this directory after
installing repository packages. For a manual rebuild:

```bash
cd install/packages/thunar-keyboard-navigation
makepkg --cleanbuild --clean --syncdeps
sudo pacman -U ./thunar-4.20.9-1.2-x86_64.pkg.tar.zst
thunar --quit
```

Open a fresh Thunar window after `thunar --quit`; existing processes keep the
old executable mapped until exit.

## Verification

Test with a directory containing at least three items:

1. Move to the second item and press `Up`: the first item becomes selected and
   the location entry must remain unfocused.
2. Press `Up` again: the location entry receives focus and its path is selected.
3. Press `Down`, `Ctrl+J`, and `Escape` separately from the location entry;
   each must return focus to the file view.
4. Press `Left` from the file view, then `Down`: only the sidebar highlight may
   move; the current directory must not change.
5. Press `Enter`: the highlighted sidebar directory must open.
6. Press `Right`: focus must return to the file view.
7. Type filename prefixes beginning with `h`, `j`, `k`, and `l`; native
   type-ahead must select matching files rather than moving focus.
8. Repeat zone transitions with `Ctrl+H/J/K/L`.
9. Confirm package ownership after installation:

```bash
pacman -Q thunar
sudo pacman -Qkk thunar
```

The integrity check must report `456 total files, 0 altered files` for this
build. Run it outside restricted user namespaces, which can display false UID
and GID mismatches for root-owned files.

## Upgrade rule

The patch and package version are intentionally pinned to Thunar 4.20.9.
Before accepting an upstream Thunar upgrade:

1. Update `pkgver` and reset `pkgrel` to `1`.
2. Refresh the upstream source and patch checksums.
3. Confirm all three patch hunks still target the same upstream behavior.
4. Build and run the complete live verification sequence above.
5. Install only after the live test passes.

Do not install an unvalidated rebuild and do not copy the binary directly into
`/usr/bin`; Pacman must own the package.
