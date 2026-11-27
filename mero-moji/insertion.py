import json
import subprocess
import time
from pathlib import Path


DISPATCH = Path(__file__).resolve().parent.parent / (
    "config/archmeros/scripts/archmeros-hyprctl-dispatch.sh"
)


def active_window():
    result = subprocess.run(["hyprctl", "activewindow", "-j"], capture_output=True,
                            text=True, check=True, timeout=1)
    return json.loads(result.stdout)


def wait_for_focus(address, timeout):
    deadline = time.monotonic() + timeout
    while True:
        if active_window().get("address") == address:
            return True
        if time.monotonic() >= deadline:
            return False
        time.sleep(0.025)


def uses_chromium_input(pid):
    if not pid:
        return False
    process = Path("/proc") / str(pid)
    try:
        executable = (process / "exe").readlink()
        children = (process / "task" / str(pid) / "children").read_text().split()
    except OSError:
        return False
    for child in children:
        candidate = process.parent / child
        try:
            if (candidate / "exe").readlink() != executable:
                continue
            args = (candidate / "cmdline").read_bytes().replace(b"\0", b" ").split()
        except OSError:
            continue
        if b"--type=zygote" in args or b"--type=gpu-process" in args:
            return True
    return False


def typing_command(glyph, target):
    if target.get("xwayland"):
        # XWayland clients use the X server's keymap. Send Unicode keysyms via XTEST.
        keys = [f"U{ord(character):04X}" for character in glyph]
        return ["xdotool", "key", "--clearmodifiers", "--delay", "60", *keys]

    keys = [glyph]
    if uses_chromium_input(target.get("pid")):
        # Chromium's native Wayland key events truncate supplementary characters.
        # Its hex composer commits the complete Unicode code point.
        keys = []
        for character in glyph:
            keys.extend(["-M", "ctrl", "-M", "shift", "-k", "u", "-m", "shift", "-m", "ctrl",
                         f"{ord(character):x}", "-M", "shift", "-k", "Return", "-m", "shift"])
    # Keep the virtual keymap available long enough for clients to process it.
    return ["wtype", "-s", "35", "-d", "12", *keys, "-s", "35"]


def insert(glyph, target):
    address = target.get("address") if target else None
    if not address:
        raise RuntimeError("No target window. Alt+C copies the emoji.")
    if not wait_for_focus(address, 0.15):
        subprocess.run([DISPATCH, "focuswindow", f"address:{address}"],
                       capture_output=True, check=True, timeout=2)
        if not wait_for_focus(address, 0.5):
            raise RuntimeError("The original window is unavailable. Alt+C copies the emoji.")
    subprocess.run(typing_command(glyph, target), capture_output=True, check=True, timeout=2)
