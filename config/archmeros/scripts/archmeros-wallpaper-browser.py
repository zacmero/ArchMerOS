#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

import tkinter as tk
from tkinter import messagebox, ttk

from PIL import Image, ImageOps, ImageTk


SCRIPT_PATH = Path(__file__).resolve()
REPO_ROOT = SCRIPT_PATH.parents[3]
WALLPAPER_DIR = REPO_ROOT / "config" / "wallpapers"
GENERATED_DIR = WALLPAPER_DIR / "generated"
WALLPAPER_CONTROLLER = REPO_ROOT / "config" / "archmeros" / "scripts" / "archmeros-wallpaper.py"
WALLPAPER_CROPPER = REPO_ROOT / "config" / "archmeros" / "scripts" / "archmeros-wallpaper-crop.py"
SCREENSAVER_DEFAULT_CONFIG = REPO_ROOT / "config" / "greetd" / "sysc-greet" / "share" / "ascii_configs" / "screensaver.conf"
SCREENSAVER_OVERRIDE_DIR = Path.home() / ".config" / "archmeros" / "screensaver"
SCREENSAVER_OVERRIDE_CONFIG = SCREENSAVER_OVERRIDE_DIR / "screensaver.conf"
SCREENSAVER_LAUNCHER = REPO_ROOT / "config" / "archmeros" / "scripts" / "archmeros-screensaver.sh"
WALLPAPER_STATE_FILE = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state")) / "archmeros" / "wallpapers.json"
SCREENSAVER_KEY_ORDER = [
    "idle_timeout",
    "time_format",
    "date_format",
    "clock_style",
    "animate_on_start",
    "animation_type",
    "animation_speed",
]
SCREENSAVER_EFFECTS = {
    "beams": "Beams",
    "print": "Print",
    "colorcycle": "Color Cycle",
    "none": "Static",
}

PREVIEW_SIZE = (780, 440)
DEFAULT_ROTATION_INTERVAL_SECONDS = 300


def run(command: list[str]) -> str:
    return subprocess.check_output(command, text=True).strip()


def parse_screensaver_config(path: Path) -> tuple[dict[str, str], str]:
    try:
        text = path.read_text()
    except Exception:
        return {}, ""

    lines = text.splitlines()
    settings: dict[str, str] = {}
    ascii_start = len(lines)
    for index, line in enumerate(lines):
        stripped = line.strip()
        if line.startswith("ascii_1="):
            ascii_start = index
            break
        if not stripped or stripped.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        settings[key.strip()] = value.strip()

    ascii_block = "\n".join(lines[ascii_start:]).strip("\n")
    return settings, ascii_block


def load_screensaver_settings() -> dict[str, str]:
    default_settings, _ = parse_screensaver_config(SCREENSAVER_DEFAULT_CONFIG)
    override_settings, _ = parse_screensaver_config(SCREENSAVER_OVERRIDE_CONFIG)
    merged = default_settings.copy()
    merged.update(override_settings)
    return merged


def write_screensaver_settings(overrides: dict[str, str]) -> None:
    default_settings, ascii_block = parse_screensaver_config(SCREENSAVER_DEFAULT_CONFIG)
    merged = default_settings.copy()
    merged.update(overrides)
    SCREENSAVER_OVERRIDE_DIR.mkdir(parents=True, exist_ok=True)
    lines = [f"{key}={merged.get(key, '')}" for key in SCREENSAVER_KEY_ORDER]
    body = "\n".join(lines).rstrip() + "\n\n" + ascii_block.rstrip() + "\n"
    SCREENSAVER_OVERRIDE_CONFIG.write_text(body)


def launch_screensaver_preview() -> None:
    subprocess.Popen(
        [str(SCREENSAVER_LAUNCHER)],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )


def load_rotation_settings() -> dict[str, int | bool]:
    try:
        state = json.loads(WALLPAPER_STATE_FILE.read_text())
    except Exception:
        state = {}
    interval = int(state.get("rotation_interval", DEFAULT_ROTATION_INTERVAL_SECONDS) or DEFAULT_ROTATION_INTERVAL_SECONDS)
    return {
        "enabled": bool(state.get("rotation_enabled", False)),
        "interval": max(60, interval),
    }


def apply_rotation_settings(enabled: bool, interval_seconds: int) -> None:
    command = [
        "python3",
        str(WALLPAPER_CONTROLLER),
        "--rotation-interval",
        str(max(60, int(interval_seconds))),
        "--enable-rotation" if enabled else "--disable-rotation",
    ]
    subprocess.run(command, check=True)


def place_window_on_parent(window: tk.Toplevel, parent: tk.Misc, width: int, height: int, parent_title: str) -> None:
    client = hypr_client_for_title(parent_title)
    if client:
        at = client.get("at") or [0, 0]
        size = client.get("size") or [width, height]
        parent_x = int(at[0] or 0)
        parent_y = int(at[1] or 0)
        parent_width = int(size[0] or width)
        parent_height = int(size[1] or height)
    else:
        parent.update_idletasks()
        window.update_idletasks()
        parent_x = parent.winfo_rootx()
        parent_y = parent.winfo_rooty()
        parent_width = max(parent.winfo_width(), parent.winfo_reqwidth())
        parent_height = max(parent.winfo_height(), parent.winfo_reqheight())
    x = max(0, parent_x + (parent_width - width) // 2)
    y = max(0, parent_y + (parent_height - height) // 2)
    window.geometry(f"{width}x{height}+{x}+{y}")


def hypr_clients() -> list[dict]:
    try:
        return json.loads(run(["hyprctl", "-j", "clients"]))
    except Exception:
        return []


def hypr_client_for_title(parent_title: str) -> dict | None:
    pid = os.getpid()
    for client in hypr_clients():
        if int(client.get("pid", 0) or 0) != pid:
            continue
        if client.get("title") == parent_title:
            return client
    return None


def monitors() -> dict[str, tuple[int, int]]:
    try:
        data = json.loads(run(["hyprctl", "-j", "monitors"]))
    except Exception:
        data = []

    result: dict[str, tuple[int, int]] = {}
    for monitor in data:
        name = monitor.get("name")
        width = int(monitor.get("width", 0) or 0)
        height = int(monitor.get("height", 0) or 0)
        if name and width > 0 and height > 0:
            result[name] = (width, height)
    return result


def focused_monitor_name() -> str | None:
    try:
        data = json.loads(run(["hyprctl", "-j", "monitors"]))
    except Exception:
        return None

    for monitor in data:
        if monitor.get("focused"):
            return monitor.get("name")
    return None


def wallpapers() -> list[Path]:
    if not WALLPAPER_DIR.exists():
        return []
    return sorted(
        path
        for path in WALLPAPER_DIR.iterdir()
        if path.is_file() and path.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"}
    )


def apply_wallpaper(target: str, wallpaper: Path) -> None:
    if target == "All monitors":
        subprocess.run(["python3", str(WALLPAPER_CONTROLLER), "--all", str(wallpaper)], check=True)
    else:
        subprocess.run(["python3", str(WALLPAPER_CONTROLLER), "--monitor", target, str(wallpaper)], check=True)


def auto_crop_all(source: Path) -> None:
    output = run(["python3", str(WALLPAPER_CROPPER), "--all", str(source)])
    mapping = json.loads(output)
    items = list(mapping.items())
    for index, (monitor_name, monitor_path) in enumerate(items):
        command = ["python3", str(WALLPAPER_CONTROLLER), "--monitor", monitor_name, monitor_path]
        if index + 1 < len(items):
            command.append("--no-theme-sync")
        subprocess.run(command, check=True)


def fit_image(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    preview = image.copy()
    preview.thumbnail(size, Image.Resampling.LANCZOS)
    return preview


class CropWindow(tk.Toplevel):
    def __init__(self, parent: "WallpaperBrowser", source: Path, monitor_name: str, monitor_size: tuple[int, int]):
        super().__init__(parent)
        self.parent = parent
        self.source = source
        self.monitor_name = monitor_name
        self.monitor_width, self.monitor_height = monitor_size
        self.title(f"Crop Wallpaper · {monitor_name}")
        self.configure(bg="#171a24")
        self.resizable(False, False)
        self.transient(parent)
        self.grab_set()
        self.focus_force()

        self.original = Image.open(source).convert("RGBA")
        self.display = fit_image(self.original, (1100, 720))
        self.display_photo = ImageTk.PhotoImage(self.display)
        self.scale_x = self.original.width / self.display.width
        self.scale_y = self.original.height / self.display.height
        self.aspect = self.monitor_width / self.monitor_height

        self.canvas = tk.Canvas(
            self,
            width=self.display.width,
            height=self.display.height,
            bg="#11131a",
            bd=0,
            highlightthickness=0,
        )
        self.canvas.pack(padx=16, pady=(16, 10))
        self.canvas.create_image(0, 0, image=self.display_photo, anchor="nw")

        self.rect = self._initial_rect()
        self.rect_id = self.canvas.create_rectangle(*self.rect, outline="#7cb8ff", width=3)
        self.shade_ids = []
        self._draw_shade()
        self.drag_last: tuple[float, float] | None = None

        self.canvas.bind("<ButtonPress-1>", self._start_drag)
        self.canvas.bind("<B1-Motion>", self._drag)
        self.canvas.bind("<ButtonRelease-1>", self._stop_drag)
        self.canvas.bind("<MouseWheel>", self._zoom)
        self.canvas.bind("<Button-4>", lambda _e: self._zoom_step(1.08))
        self.canvas.bind("<Button-5>", lambda _e: self._zoom_step(0.92))
        self.bind("<plus>", lambda _e: self._zoom_step(1.08))
        self.bind("<equal>", lambda _e: self._zoom_step(1.08))
        self.bind("<minus>", lambda _e: self._zoom_step(0.92))
        self.bind("<KP_Add>", lambda _e: self._zoom_step(1.08))
        self.bind("<KP_Subtract>", lambda _e: self._zoom_step(0.92))
        self.bind("<Up>", lambda _e: self._move_rect(0, -18))
        self.bind("<Down>", lambda _e: self._move_rect(0, 18))
        self.bind("<Left>", lambda _e: self._move_rect(-18, 0))
        self.bind("<Right>", lambda _e: self._move_rect(18, 0))

        footer = tk.Frame(self, bg="#171a24")
        footer.pack(fill="x", padx=16, pady=(0, 16))

        help_label = tk.Label(
            footer,
            text="Drag to reposition crop. Use wheel, +/- or the zoom buttons. Arrow keys nudge the crop area. Apply writes a generated wallpaper into ArchMerOS.",
            fg="#c6d0f5",
            bg="#171a24",
            justify="left",
        )
        help_label.pack(anchor="w", pady=(0, 10))

        buttons = tk.Frame(footer, bg="#171a24")
        buttons.pack(fill="x")
        tk.Button(buttons, text="Zoom Out", command=lambda: self._zoom_step(0.92), bg="#252a37", fg="#c6d0f5", relief="flat").pack(side="left")
        tk.Button(buttons, text="Zoom In", command=lambda: self._zoom_step(1.08), bg="#252a37", fg="#c6d0f5", relief="flat").pack(side="left", padx=(8, 0))
        tk.Button(buttons, text="Cancel", command=self.destroy, bg="#252a37", fg="#c6d0f5", relief="flat").pack(side="right", padx=(8, 0))
        tk.Button(buttons, text="Apply Crop", command=self._apply, bg="#4c7adf", fg="#11131a", relief="flat").pack(side="right")

    def _initial_rect(self) -> tuple[float, float, float, float]:
        display_w = self.display.width
        display_h = self.display.height
        target_w = display_w * 0.72
        target_h = target_w / self.aspect
        if target_h > display_h * 0.82:
            target_h = display_h * 0.82
            target_w = target_h * self.aspect
        x1 = (display_w - target_w) / 2
        y1 = (display_h - target_h) / 2
        return (x1, y1, x1 + target_w, y1 + target_h)

    def _draw_shade(self) -> None:
        for shade in self.shade_ids:
            self.canvas.delete(shade)
        self.shade_ids.clear()
        x1, y1, x2, y2 = self.rect
        w = self.display.width
        h = self.display.height
        regions = [
          (0, 0, w, y1),
          (0, y2, w, h),
          (0, y1, x1, y2),
          (x2, y1, w, y2),
        ]
        for coords in regions:
            shade = self.canvas.create_rectangle(*coords, fill="#0b0d14", stipple="gray50", outline="")
            self.shade_ids.append(shade)
        self.canvas.tag_raise(self.rect_id)

    def _start_drag(self, event: tk.Event) -> None:
        x1, y1, x2, y2 = self.rect
        if x1 <= event.x <= x2 and y1 <= event.y <= y2:
            self.drag_last = (event.x, event.y)

    def _drag(self, event: tk.Event) -> None:
        if not self.drag_last:
            return
        last_x, last_y = self.drag_last
        dx = event.x - last_x
        dy = event.y - last_y
        self.drag_last = (event.x, event.y)
        self._move_rect(dx, dy)

    def _stop_drag(self, _event: tk.Event) -> None:
        self.drag_last = None

    def _move_rect(self, dx: float, dy: float) -> None:
        x1, y1, x2, y2 = self.rect
        width = x2 - x1
        height = y2 - y1
        x1 = min(max(0, x1 + dx), self.display.width - width)
        y1 = min(max(0, y1 + dy), self.display.height - height)
        self.rect = (x1, y1, x1 + width, y1 + height)
        self.canvas.coords(self.rect_id, *self.rect)
        self._draw_shade()

    def _zoom(self, event: tk.Event) -> None:
        factor = 1.08 if event.delta > 0 else 0.92
        self._zoom_step(factor)

    def _zoom_step(self, factor: float) -> None:
        x1, y1, x2, y2 = self.rect
        cx = (x1 + x2) / 2
        cy = (y1 + y2) / 2
        width = (x2 - x1) / factor
        height = width / self.aspect

        min_w = self.display.width * 0.16
        max_w = self.display.width
        width = max(min_w, min(max_w, width))
        height = width / self.aspect
        if height > self.display.height:
            height = self.display.height
            width = height * self.aspect

        x1 = max(0, cx - width / 2)
        y1 = max(0, cy - height / 2)
        x2 = x1 + width
        y2 = y1 + height

        if x2 > self.display.width:
            x2 = self.display.width
            x1 = x2 - width
        if y2 > self.display.height:
            y2 = self.display.height
            y1 = y2 - height

        self.rect = (x1, y1, x2, y2)
        self.canvas.coords(self.rect_id, *self.rect)
        self._draw_shade()

    def _apply(self) -> None:
        x1, y1, x2, y2 = self.rect
        crop_box = (
            int(round(x1 * self.scale_x)),
            int(round(y1 * self.scale_y)),
            int(round(x2 * self.scale_x)),
            int(round(y2 * self.scale_y)),
        )
        cropped = self.original.crop(crop_box).resize(
            (self.monitor_width, self.monitor_height),
            Image.Resampling.LANCZOS,
        )
        GENERATED_DIR.mkdir(parents=True, exist_ok=True)
        output = GENERATED_DIR / f"{self.monitor_name.replace('/', '-')}-manual-{self.source.stem}-{self.monitor_width}x{self.monitor_height}.png"
        cropped.save(output, format="PNG")
        apply_wallpaper(self.monitor_name, output)
        self.parent.destroy()


class ScreensaverStudio(tk.Toplevel):
    def __init__(self, parent: "WallpaperBrowser"):
        super().__init__(parent)
        self.parent = parent
        self.withdraw()
        self.title("ArchMerOS Screensaver Studio")
        self.configure(bg="#171a24")
        self.geometry("780x620")
        self.minsize(740, 600)
        self.transient(parent)
        self.focus_force()

        settings = load_screensaver_settings()
        self.enabled_var = tk.BooleanVar(value=settings.get("enabled", "true").lower() != "false")
        self.effect_var = tk.StringVar(value=settings.get("animation_type", "beams"))
        self.speed_var = tk.IntVar(value=int(settings.get("animation_speed", "2") or 2))
        self.animate_var = tk.BooleanVar(value=settings.get("animate_on_start", "true").lower() == "true")

        shell = tk.Frame(self, bg="#171a24")
        shell.pack(fill="both", expand=True, padx=18, pady=18)

        header = tk.Frame(shell, bg="#171a24")
        header.pack(fill="x", pady=(0, 14))
        tk.Label(header, text="SCREENSAVER", bg="#171a24", fg="#7cb8ff", font=("Cascadia Code", 20, "bold")).pack(anchor="w")
        tk.Label(
            header,
            text="This is the live session screensaver layer. It uses the same ArchMerOS logo system as the greeter, but triggers from desktop idle.",
            bg="#171a24",
            fg="#c6d0f5",
            justify="left",
            wraplength=680,
        ).pack(anchor="w", pady=(8, 0))

        effect_frame = tk.Frame(shell, bg="#171a24")
        effect_frame.pack(fill="x", pady=(0, 16))
        tk.Label(effect_frame, text="Animation", bg="#171a24", fg="#7cb8ff").pack(anchor="w", pady=(0, 8))

        chips = tk.Frame(effect_frame, bg="#171a24")
        chips.pack(fill="x")
        self.effect_buttons: dict[str, tk.Button] = {}
        for key, label in SCREENSAVER_EFFECTS.items():
            button = tk.Button(
                chips,
                text=label,
                command=lambda value=key: self._select_effect(value),
                bg="#252a37",
                fg="#c6d0f5",
                activebackground="#34284a",
                activeforeground="#ff7ad9",
                relief="flat",
                padx=14,
                pady=10,
            )
            button.pack(side="left", padx=(0, 8))
            self.effect_buttons[key] = button

        speed_frame = tk.Frame(shell, bg="#171a24")
        speed_frame.pack(fill="x", pady=(0, 16))
        tk.Label(speed_frame, text="Animation speed", bg="#171a24", fg="#7cb8ff").pack(anchor="w", pady=(0, 8))
        scale_row = tk.Frame(speed_frame, bg="#171a24")
        scale_row.pack(fill="x")
        self.speed_scale = tk.Scale(
            scale_row,
            from_=1,
            to=8,
            orient="horizontal",
            variable=self.speed_var,
            bg="#171a24",
            fg="#c6d0f5",
            highlightthickness=0,
            troughcolor="#252a37",
            activebackground="#ff7ad9",
        )
        self.speed_scale.pack(side="left", fill="x", expand=True)
        self.speed_label = tk.Label(scale_row, text="", bg="#171a24", fg="#9adf76", width=10)
        self.speed_label.pack(side="left", padx=(12, 0))

        flags = tk.Frame(shell, bg="#171a24")
        flags.pack(fill="x", pady=(0, 18))
        self.animate_check = tk.Checkbutton(
            flags,
            text="Animate on start",
            variable=self.animate_var,
            bg="#171a24",
            fg="#c6d0f5",
            selectcolor="#252a37",
            activebackground="#171a24",
            activeforeground="#c6d0f5",
        )
        self.animate_check.pack(anchor="w")
        self.enabled_check = tk.Checkbutton(
            flags,
            text="Disable screensaver, keep monitor standby only",
            variable=self.enabled_var,
            onvalue=False,
            offvalue=True,
            bg="#171a24",
            fg="#c6d0f5",
            selectcolor="#252a37",
            activebackground="#171a24",
            activeforeground="#c6d0f5",
        )
        self.enabled_check.pack(anchor="w", pady=(8, 0))
        tk.Label(
            flags,
            text="Idle trigger is currently 5 minutes through hypridle. DPMS powers the screens off after one more minute.",
            bg="#171a24",
            fg="#8e96c8",
            justify="left",
            wraplength=680,
        ).pack(anchor="w", pady=(8, 0))

        preview_shell = tk.Frame(shell, bg="#11131a", highlightthickness=1, highlightbackground="#384664")
        preview_shell.pack(fill="x", pady=(0, 18))
        tk.Label(preview_shell, text="Live path", bg="#11131a", fg="#7cb8ff", font=("Cascadia Code", 11, "bold")).pack(anchor="w", padx=12, pady=(12, 6))
        tk.Label(
            preview_shell,
            text="Apply writes a user override at ~/.config/archmeros/screensaver/screensaver.conf. Preview launches the same session screensaver command hypridle uses.",
            bg="#11131a",
            fg="#c6d0f5",
            justify="left",
            wraplength=660,
        ).pack(anchor="w", padx=12, pady=(0, 12))

        buttons = tk.Frame(shell, bg="#171a24")
        buttons.pack(fill="x")
        tk.Button(buttons, text="Close", command=self.destroy, bg="#252a37", fg="#c6d0f5", relief="flat").pack(side="right")
        tk.Button(buttons, text="Apply", command=self._apply, bg="#4c7adf", fg="#11131a", relief="flat").pack(side="right", padx=(0, 8))
        tk.Button(buttons, text="Preview", command=self._preview, bg="#34284a", fg="#ff7ad9", relief="flat").pack(side="left")

        self.speed_var.trace_add("write", lambda *_args: self._refresh_state())
        self._refresh_state()
        place_window_on_parent(self, parent, 780, 620, "ArchMerOS Wallpaper Picker")
        self.deiconify()
        self.lift()

    def _select_effect(self, effect: str) -> None:
        self.effect_var.set(effect)
        self._refresh_state()

    def _refresh_state(self) -> None:
        effect = self.effect_var.get()
        for key, button in self.effect_buttons.items():
            active = key == effect
            button.configure(
                bg="#34284a" if active else "#252a37",
                fg="#ff7ad9" if active else "#c6d0f5",
            )
        self.speed_label.configure(text=f"{self.speed_var.get()}x")

    def _settings_payload(self) -> dict[str, str]:
        return {
            "enabled": "true" if self.enabled_var.get() else "false",
            "animate_on_start": "true" if self.animate_var.get() else "false",
            "animation_type": self.effect_var.get(),
            "animation_speed": str(self.speed_var.get()),
        }

    def _apply(self) -> None:
        write_screensaver_settings(self._settings_payload())
        messagebox.showinfo("ArchMerOS Screensaver", "Screensaver settings applied.")

    def _preview(self) -> None:
        write_screensaver_settings(self._settings_payload())
        launch_screensaver_preview()


class RotationStudio(tk.Toplevel):
    def __init__(self, parent: "WallpaperBrowser"):
        super().__init__(parent)
        self.parent = parent
        self.withdraw()
        self.title("ArchMerOS Wallpaper Rotation")
        self.configure(bg="#171a24")
        self.geometry("760x500")
        self.minsize(720, 480)
        self.transient(parent)
        self.focus_force()

        settings = load_rotation_settings()
        self.enabled_var = tk.BooleanVar(value=bool(settings["enabled"]))
        self.interval_var = tk.IntVar(value=max(1, int(settings["interval"]) // 60))

        shell = tk.Frame(self, bg="#171a24")
        shell.pack(fill="both", expand=True, padx=18, pady=18)

        header = tk.Frame(shell, bg="#171a24")
        header.pack(fill="x", pady=(0, 16))
        tk.Label(header, text="WALLPAPER ROTATION", bg="#171a24", fg="#7cb8ff", font=("Cascadia Code", 19, "bold")).pack(anchor="w")
        tk.Label(
            header,
            text="This mode rotates random images from the repo wallpaper folder across the three monitors. Each monitor gets its own random order.",
            bg="#171a24",
            fg="#c6d0f5",
            justify="left",
            wraplength=680,
        ).pack(anchor="w", pady=(8, 0))

        options = tk.Frame(shell, bg="#171a24")
        options.pack(fill="x", pady=(0, 18))
        tk.Checkbutton(
            options,
            text="Enable random wallpaper rotation",
            variable=self.enabled_var,
            bg="#171a24",
            fg="#c6d0f5",
            selectcolor="#252a37",
            activebackground="#171a24",
            activeforeground="#c6d0f5",
        ).pack(anchor="w")

        tk.Label(options, text="Interval", bg="#171a24", fg="#7cb8ff").pack(anchor="w", pady=(18, 8))
        interval_row = tk.Frame(options, bg="#171a24")
        interval_row.pack(fill="x")
        tk.Scale(
            interval_row,
            from_=1,
            to=30,
            orient="horizontal",
            variable=self.interval_var,
            bg="#171a24",
            fg="#c6d0f5",
            highlightthickness=0,
            troughcolor="#252a37",
            activebackground="#7cb8ff",
        ).pack(side="left", fill="x", expand=True)
        self.interval_label = tk.Label(interval_row, text="", bg="#171a24", fg="#9adf76", width=12)
        self.interval_label.pack(side="left", padx=(12, 0))

        info = tk.Frame(shell, bg="#11131a", highlightthickness=1, highlightbackground="#384664")
        info.pack(fill="x", pady=(0, 18))
        tk.Label(info, text="Backend note", bg="#11131a", fg="#7cb8ff", font=("Cascadia Code", 11, "bold")).pack(anchor="w", padx=12, pady=(12, 6))
        tk.Label(
            info,
            text="ArchMerOS can do random per-monitor rotation cleanly with hyprpaper. The current wallpaper backend does not provide a subtle fade transition, so rotation uses hard cuts for now.",
            bg="#11131a",
            fg="#c6d0f5",
            justify="left",
            wraplength=660,
        ).pack(anchor="w", padx=12, pady=(0, 12))

        buttons = tk.Frame(shell, bg="#171a24")
        buttons.pack(fill="x")
        tk.Button(buttons, text="Close", command=self.destroy, bg="#252a37", fg="#c6d0f5", relief="flat").pack(side="right")
        tk.Button(buttons, text="Apply", command=self._apply, bg="#4c7adf", fg="#11131a", relief="flat").pack(side="right", padx=(0, 8))

        self.interval_var.trace_add("write", lambda *_args: self._refresh_state())
        self._refresh_state()
        place_window_on_parent(self, parent, 760, 500, "ArchMerOS Wallpaper Picker")
        self.deiconify()
        self.lift()

    def _refresh_state(self) -> None:
        self.interval_label.configure(text=f"{self.interval_var.get()} min")

    def _apply(self) -> None:
        apply_rotation_settings(self.enabled_var.get(), self.interval_var.get() * 60)
        messagebox.showinfo("ArchMerOS Rotation", "Wallpaper rotation settings applied.")


class WallpaperBrowser(tk.Tk):
    def __init__(self) -> None:
        super().__init__(className="archmeros-wallpaper")
        self.title("ArchMerOS Wallpaper Picker")
        self.configure(bg="#171a24")
        self.geometry("1180x640")
        self.minsize(1080, 620)

        self.monitor_map = monitors()
        self.wallpapers = wallpapers()
        self.preview_photo: ImageTk.PhotoImage | None = None
        self.current_path: Path | None = self.wallpapers[0] if self.wallpapers else None
        self.original_image: Image.Image | None = None
        self.display_image: Image.Image | None = None
        self.crop_enabled = False
        self.crop_rect: tuple[float, float, float, float] | None = None
        self.crop_rect_id: int | None = None
        self.crop_shade_ids: list[int] = []
        self.drag_last: tuple[float, float] | None = None
        self.image_offset_x = 0
        self.image_offset_y = 0
        self.scale_x = 1.0
        self.scale_y = 1.0
        self.target_aspect = 16 / 9

        self.option_add("*TCombobox*Listbox*Background", "#252a37")
        self.option_add("*TCombobox*Listbox*Foreground", "#c6d0f5")

        style = ttk.Style(self)
        try:
            style.theme_use("clam")
        except tk.TclError:
            pass
        style.configure("TCombobox", fieldbackground="#252a37", background="#252a37", foreground="#c6d0f5")

        top = tk.Frame(self, bg="#171a24")
        top.pack(fill="both", expand=True, padx=16, pady=16)

        left = tk.Frame(top, bg="#171a24")
        left.pack(side="left", fill="y")

        tk.Label(left, text="Target", bg="#171a24", fg="#7cb8ff").pack(anchor="w", pady=(0, 6))
        self.target = ttk.Combobox(left, state="readonly", width=22, values=["All monitors", *self.monitor_map.keys()])
        default_target = focused_monitor_name()
        if default_target and default_target in self.monitor_map:
            self.target.set(default_target)
        else:
            self.target.current(0)
        self.target.pack(anchor="w", pady=(0, 12))
        self.target.bind("<<ComboboxSelected>>", self._on_target)

        tk.Button(
            left,
            text="Screensaver Studio",
            command=self._open_screensaver_studio,
            bg="#34284a",
            fg="#ff7ad9",
            relief="flat",
            padx=12,
            pady=8,
        ).pack(anchor="w", pady=(0, 14))
        tk.Button(
            left,
            text="Wallpaper Rotation",
            command=self._open_rotation_studio,
            bg="#253447",
            fg="#7cb8ff",
            relief="flat",
            padx=12,
            pady=8,
        ).pack(anchor="w", pady=(0, 14))

        tk.Label(left, text="Wallpapers", bg="#171a24", fg="#7cb8ff").pack(anchor="w", pady=(0, 6))
        list_frame = tk.Frame(left, bg="#171a24")
        list_frame.pack(fill="y", expand=True)
        scrollbar = tk.Scrollbar(list_frame)
        scrollbar.pack(side="right", fill="y")
        self.listbox = tk.Listbox(
            list_frame,
            width=34,
            height=26,
            bg="#252a37",
            fg="#c6d0f5",
            selectbackground="#4c7adf",
            selectforeground="#11131a",
            activestyle="none",
            relief="flat",
            yscrollcommand=scrollbar.set,
        )
        self.listbox.pack(side="left", fill="both", expand=True)
        scrollbar.config(command=self.listbox.yview)
        for path in self.wallpapers:
            self.listbox.insert("end", path.name)
        self.listbox.bind("<<ListboxSelect>>", self._on_select)
        self.listbox.bind("<Double-Button-1>", lambda _e: self._primary_action())
        if self.wallpapers:
            self.listbox.selection_set(0)
            self.listbox.activate(0)

        right = tk.Frame(top, bg="#171a24")
        right.pack(side="left", fill="both", expand=True, padx=(16, 0))
        tk.Label(right, text="Preview", bg="#171a24", fg="#7cb8ff").pack(anchor="w", pady=(0, 6))
        self.preview_canvas = tk.Canvas(right, width=PREVIEW_SIZE[0], height=PREVIEW_SIZE[1], bg="#11131a", bd=0, highlightthickness=0)
        self.preview_canvas.pack(fill="both", expand=True)
        self.preview_canvas.bind("<ButtonPress-1>", self._start_drag)
        self.preview_canvas.bind("<B1-Motion>", self._drag)
        self.preview_canvas.bind("<ButtonRelease-1>", self._stop_drag)
        self.preview_canvas.bind("<MouseWheel>", self._zoom)
        self.preview_canvas.bind("<Button-4>", lambda _e: self._zoom_step(1.08))
        self.preview_canvas.bind("<Button-5>", lambda _e: self._zoom_step(0.92))

        self.info = tk.Label(right, text="", bg="#171a24", fg="#c6d0f5", justify="left")
        self.info.pack(anchor="w", pady=(10, 0))

        buttons = tk.Frame(self, bg="#171a24")
        buttons.pack(fill="x", padx=16, pady=(0, 16))
        tk.Button(buttons, text="Cancel", command=self.destroy, bg="#252a37", fg="#c6d0f5", relief="flat").pack(side="right")
        self.primary_button = tk.Button(buttons, text="Apply", command=self._primary_action, bg="#4c7adf", fg="#11131a", relief="flat")
        self.primary_button.pack(side="right", padx=(0, 8))
        self.zoom_out_button = tk.Button(buttons, text="Zoom Out", command=lambda: self._zoom_step(0.92), bg="#252a37", fg="#c6d0f5", relief="flat")
        self.zoom_out_button.pack(side="left")
        self.zoom_in_button = tk.Button(buttons, text="Zoom In", command=lambda: self._zoom_step(1.08), bg="#252a37", fg="#c6d0f5", relief="flat")
        self.zoom_in_button.pack(side="left", padx=(8, 0))

        self.bind("<Escape>", lambda _e: self.destroy())
        self.bind("<Return>", lambda _e: self._primary_action())
        self.bind("<KP_Enter>", lambda _e: self._primary_action())
        self.bind("<plus>", lambda _e: self._zoom_step(1.08))
        self.bind("<equal>", lambda _e: self._zoom_step(1.08))
        self.bind("<minus>", lambda _e: self._zoom_step(0.92))
        self.bind("<KP_Add>", lambda _e: self._zoom_step(1.08))
        self.bind("<KP_Subtract>", lambda _e: self._zoom_step(0.92))
        self.bind("<Up>", lambda _e: self._move_rect(0, -18))
        self.bind("<Down>", lambda _e: self._move_rect(0, 18))
        self.bind("<Left>", lambda _e: self._move_rect(-18, 0))
        self.bind("<Right>", lambda _e: self._move_rect(18, 0))
        self._refresh_preview()

    def _selected_target(self) -> str:
        return self.target.get() or "All monitors"

    def _open_screensaver_studio(self) -> None:
        ScreensaverStudio(self)

    def _open_rotation_studio(self) -> None:
        RotationStudio(self)

    def _selected_path(self) -> Path | None:
        selection = self.listbox.curselection()
        if not selection:
            return None
        index = selection[0]
        return self.wallpapers[index]

    def _on_select(self, _event=None) -> None:
        self.current_path = self._selected_path()
        self._refresh_preview()

    def _on_target(self, _event=None) -> None:
        self._refresh_preview()

    def _refresh_preview(self) -> None:
        path = self.current_path
        if not path:
            self.preview_canvas.delete("all")
            self.info.configure(text="")
            return
        self.original_image = Image.open(path).convert("RGBA")
        self.display_image = fit_image(self.original_image, PREVIEW_SIZE)
        self.preview_photo = ImageTk.PhotoImage(self.display_image)
        self.preview_canvas.delete("all")
        self.image_offset_x = (PREVIEW_SIZE[0] - self.display_image.width) // 2
        self.image_offset_y = (PREVIEW_SIZE[1] - self.display_image.height) // 2
        self.scale_x = self.original_image.width / self.display_image.width
        self.scale_y = self.original_image.height / self.display_image.height
        self.preview_canvas.create_image(self.image_offset_x, self.image_offset_y, image=self.preview_photo, anchor="nw")
        info = f"{path.name}\n{self.original_image.width}x{self.original_image.height}"
        if self._selected_target() != "All monitors":
            mon_w, mon_h = self.monitor_map[self._selected_target()]
            info += f"\nTarget: {self._selected_target()} · {mon_w}x{mon_h}"
            info += "\nCrop is shown directly here. Drag the rectangle, use wheel or zoom buttons, then Apply Crop."
            self.target_aspect = mon_w / mon_h
            self._enable_crop()
            self.primary_button.configure(text="Apply Crop")
            self.zoom_in_button.configure(state="normal")
            self.zoom_out_button.configure(state="normal")
        else:
            info += "\nTarget: All monitors"
            info += "\nApply uses the original wallpaper on all monitors. Select one monitor above for manual cropping."
            self._disable_crop()
            self.primary_button.configure(text="Apply")
            self.zoom_in_button.configure(state="disabled")
            self.zoom_out_button.configure(state="disabled")
        self.info.configure(text=info)

    def _enable_crop(self) -> None:
        self.crop_enabled = True
        self.crop_rect = self._initial_rect()
        self._draw_crop()

    def _disable_crop(self) -> None:
        self.crop_enabled = False
        self.crop_rect = None
        self.crop_rect_id = None
        self.drag_last = None
        for shade in self.crop_shade_ids:
            self.preview_canvas.delete(shade)
        self.crop_shade_ids.clear()

    def _initial_rect(self) -> tuple[float, float, float, float]:
        assert self.display_image is not None
        display_w = self.display_image.width
        display_h = self.display_image.height
        target_w = display_w * 0.72
        target_h = target_w / self.target_aspect
        if target_h > display_h * 0.82:
            target_h = display_h * 0.82
            target_w = target_h * self.target_aspect
        x1 = self.image_offset_x + (display_w - target_w) / 2
        y1 = self.image_offset_y + (display_h - target_h) / 2
        return (x1, y1, x1 + target_w, y1 + target_h)

    def _draw_crop(self) -> None:
        if not self.crop_enabled or not self.crop_rect:
            return
        for shade in self.crop_shade_ids:
            self.preview_canvas.delete(shade)
        self.crop_shade_ids.clear()
        if self.crop_rect_id is not None:
            self.preview_canvas.delete(self.crop_rect_id)
        x1, y1, x2, y2 = self.crop_rect
        w = PREVIEW_SIZE[0]
        h = PREVIEW_SIZE[1]
        regions = [
            (0, 0, w, y1),
            (0, y2, w, h),
            (0, y1, x1, y2),
            (x2, y1, w, y2),
        ]
        for coords in regions:
            shade = self.preview_canvas.create_rectangle(*coords, fill="#0b0d14", stipple="gray50", outline="")
            self.crop_shade_ids.append(shade)
        self.crop_rect_id = self.preview_canvas.create_rectangle(*self.crop_rect, outline="#7cb8ff", width=3)

    def _crop_bounds(self) -> tuple[float, float, float, float]:
        assert self.display_image is not None
        return (
            self.image_offset_x,
            self.image_offset_y,
            self.image_offset_x + self.display_image.width,
            self.image_offset_y + self.display_image.height,
        )

    def _start_drag(self, event: tk.Event) -> None:
        if not self.crop_enabled or not self.crop_rect:
            return
        x1, y1, x2, y2 = self.crop_rect
        if x1 <= event.x <= x2 and y1 <= event.y <= y2:
            self.drag_last = (event.x, event.y)

    def _drag(self, event: tk.Event) -> None:
        if not self.crop_enabled or not self.drag_last:
            return
        last_x, last_y = self.drag_last
        dx = event.x - last_x
        dy = event.y - last_y
        self.drag_last = (event.x, event.y)
        self._move_rect(dx, dy)

    def _stop_drag(self, _event: tk.Event) -> None:
        self.drag_last = None

    def _move_rect(self, dx: float, dy: float) -> None:
        if not self.crop_enabled or not self.crop_rect:
            return
        x1, y1, x2, y2 = self.crop_rect
        width = x2 - x1
        height = y2 - y1
        bx1, by1, bx2, by2 = self._crop_bounds()
        x1 = min(max(bx1, x1 + dx), bx2 - width)
        y1 = min(max(by1, y1 + dy), by2 - height)
        self.crop_rect = (x1, y1, x1 + width, y1 + height)
        self._draw_crop()

    def _zoom(self, event: tk.Event) -> None:
        if not self.crop_enabled:
            return
        factor = 1.08 if event.delta > 0 else 0.92
        self._zoom_step(factor)

    def _zoom_step(self, factor: float) -> None:
        if not self.crop_enabled or not self.crop_rect or self.display_image is None:
            return
        x1, y1, x2, y2 = self.crop_rect
        cx = (x1 + x2) / 2
        cy = (y1 + y2) / 2
        width = (x2 - x1) / factor
        height = width / self.target_aspect
        min_w = self.display_image.width * 0.16
        max_w = self.display_image.width
        width = max(min_w, min(max_w, width))
        height = width / self.target_aspect
        if height > self.display_image.height:
            height = self.display_image.height
            width = height * self.target_aspect
        bx1, by1, bx2, by2 = self._crop_bounds()
        x1 = max(bx1, cx - width / 2)
        y1 = max(by1, cy - height / 2)
        x2 = x1 + width
        y2 = y1 + height
        if x2 > bx2:
            x2 = bx2
            x1 = x2 - width
        if y2 > by2:
            y2 = by2
            y1 = y2 - height
        self.crop_rect = (x1, y1, x2, y2)
        self._draw_crop()

    def _apply_direct(self) -> None:
        path = self._selected_path()
        if not path:
            return
        try:
            apply_wallpaper(self._selected_target(), path)
        except subprocess.CalledProcessError as exc:
            messagebox.showerror("ArchMerOS Wallpaper", f"Failed to apply wallpaper:\n{exc}")
            return
        self.destroy()

    def _crop(self) -> None:
        path = self._selected_path()
        if not path:
            return
        if not self.crop_rect or self.original_image is None:
            return
        target = self._selected_target()
        mon_w, mon_h = self.monitor_map[target]
        x1, y1, x2, y2 = self.crop_rect
        crop_box = (
            int(round((x1 - self.image_offset_x) * self.scale_x)),
            int(round((y1 - self.image_offset_y) * self.scale_y)),
            int(round((x2 - self.image_offset_x) * self.scale_x)),
            int(round((y2 - self.image_offset_y) * self.scale_y)),
        )
        cropped = self.original_image.crop(crop_box).resize((mon_w, mon_h), Image.Resampling.LANCZOS)
        GENERATED_DIR.mkdir(parents=True, exist_ok=True)
        output = GENERATED_DIR / f"{target.replace('/', '-')}-manual-{path.stem}-{mon_w}x{mon_h}.png"
        cropped.save(output, format="PNG")
        try:
            apply_wallpaper(target, output)
        except subprocess.CalledProcessError as exc:
            messagebox.showerror("ArchMerOS Wallpaper", f"Failed to apply cropped wallpaper:\n{exc}")
            return
        self.destroy()

    def _primary_action(self) -> None:
        if self._selected_target() == "All monitors":
            self._apply_direct()
            return
        self._crop()


def main() -> int:
    app = WallpaperBrowser()
    app.mainloop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
