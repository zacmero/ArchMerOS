#!/usr/bin/env python3

from __future__ import annotations

import json
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

PREVIEW_SIZE = (780, 440)


def run(command: list[str]) -> str:
    return subprocess.check_output(command, text=True).strip()


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
