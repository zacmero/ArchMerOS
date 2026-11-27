# Mero Moji

Mero Moji is ArchMerOS's GTK emoji picker. Launch it with **Super+.** or
`mero-moji`. It sends keystrokes to the original Hyprland window using
`wtype` for Wayland and `xdotool` for XWayland. Native Wayland Chromium apps
receive emoji through Chromium's Unicode composer. **Alt+C** explicitly
copies a selection when the target app requires a manual paste.

The bundled catalog uses fully qualified sequences from Unicode Emoji 17.0
and English search keywords from CLDR 48. Its license is in
[UNICODE-LICENSE.txt](UNICODE-LICENSE.txt). Run `python mero-moji/update-catalog.py`
from the repository root to regenerate it.
