#!/usr/bin/env python3

import calendar
import datetime as dt
import locale
import os
import signal
import sys
from pathlib import Path

import gi

gi.require_version("Gdk", "3.0")
gi.require_version("Gtk", "3.0")
from gi.repository import Gdk, Gtk


PIDFILE = Path("/tmp/archmeros-calendar-popup.pid")
STAMPFILE = Path("/tmp/archmeros-calendar-popup.stamp")
WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
MONTH_NAMES = [
    "JANUARY",
    "FEBRUARY",
    "MARCH",
    "APRIL",
    "MAY",
    "JUNE",
    "JULY",
    "AUGUST",
    "SEPTEMBER",
    "OCTOBER",
    "NOVEMBER",
    "DECEMBER",
]


for candidate in ("C.UTF-8", "en_US.UTF-8", "C"):
    try:
        locale.setlocale(locale.LC_TIME, candidate)
        break
    except locale.Error:
        continue


def toggle_existing_instance() -> None:
    now = dt.datetime.now().timestamp()

    if not PIDFILE.exists():
        STAMPFILE.write_text(str(now))
        return
    try:
        pid = int(PIDFILE.read_text().strip())
    except (OSError, ValueError):
        PIDFILE.unlink(missing_ok=True)
        STAMPFILE.write_text(str(now))
        return

    if pid == os.getpid():
        return

    last_toggle = 0.0
    if STAMPFILE.exists():
        try:
            last_toggle = float(STAMPFILE.read_text().strip())
        except (OSError, ValueError):
            last_toggle = 0.0

    try:
        os.kill(pid, 0)
    except OSError:
        PIDFILE.unlink(missing_ok=True)
        STAMPFILE.write_text(str(now))
        return

    if now - last_toggle < 0.45:
        sys.exit(0)

    STAMPFILE.write_text(str(now))
    os.kill(pid, signal.SIGTERM)
    sys.exit(0)


class CalendarWindow(Gtk.Window):
    def __init__(self) -> None:
        super().__init__(title="ArchMerOS Calendar")
        self.set_name("archmeros-calendar")
        self.set_type_hint(Gdk.WindowTypeHint.DIALOG)
        self.set_keep_above(True)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        self.set_resizable(False)
        self.set_decorated(False)
        self.set_border_width(16)
        self.set_default_size(420, 430)
        self.set_size_request(420, 430)
        self.set_position(Gtk.WindowPosition.CENTER_ALWAYS)

        today = dt.date.today()
        self.today = today
        self.view_year = today.year
        self.view_month = today.month
        self.day_labels: list[Gtk.Label] = []
        self.day_boxes: list[Gtk.EventBox] = []

        self.connect("destroy", self.on_destroy)
        self.connect("key-press-event", self.on_key_press)

        self.install_css()
        self.build_ui()
        self.render_month()

    def install_css(self) -> None:
        css = b"""
        #archmeros-calendar {
          background: rgba(9, 12, 22, 0.97);
          border: 2px solid #58d6ff;
        }

        #calendar-frame {
          background: rgba(13, 17, 30, 0.97);
          border: 2px solid #58d6ff;
          padding: 12px;
        }

        #calendar-title {
          color: #d8ddff;
          font-family: "CaskaydiaCove Nerd Font", "CommitMono Nerd Font", monospace;
          font-size: 18px;
          font-weight: 800;
          letter-spacing: 0.08em;
        }

        #calendar-subtitle {
          color: #aab4ea;
          font-family: "CaskaydiaCove Nerd Font", "CommitMono Nerd Font", monospace;
          font-size: 11px;
          letter-spacing: 0.1em;
        }

        #calendar-separator {
          min-height: 2px;
          background: #58d6ff;
        }

        eventbox.calendar-control {
          background: rgba(29, 35, 60, 0.92);
          border: 2px solid #58d6ff;
        }

        eventbox.calendar-control.hover {
          background: rgba(43, 49, 83, 0.96);
          border-color: #ff7edb;
        }

        eventbox#today-button {
          border-color: #8fe388;
        }

        eventbox#today-button.hover {
          border-color: #ff7edb;
        }

        label.control-label {
          color: #58d6ff;
          font-family: "CaskaydiaCove Nerd Font", "CommitMono Nerd Font", monospace;
          font-size: 20px;
          font-weight: 700;
        }

        label.control-label.hover {
          color: #ff7edb;
        }

        label#today-label {
          color: #8fe388;
          font-size: 15px;
          font-weight: 800;
        }

        label#today-label.hover {
          color: #ff7edb;
        }

        #calendar-grid-shell {
          background: rgba(21, 26, 44, 0.96);
          padding: 14px;
        }

        label.weekday-label {
          color: #ff7edb;
          font-family: "CaskaydiaCove Nerd Font", "CommitMono Nerd Font", monospace;
          font-size: 13px;
          font-weight: 700;
        }

        eventbox.day-cell {
          background: transparent;
          border: 2px solid transparent;
          min-width: 42px;
          min-height: 38px;
        }

        eventbox.day-cell.today-cell {
          background: rgba(45, 53, 93, 0.96);
          border-color: rgba(45, 53, 93, 0.96);
          border-radius: 8px;
        }

        label.day-label {
          color: #d8ddff;
          font-family: "CaskaydiaCove Nerd Font", "CommitMono Nerd Font", monospace;
          font-size: 16px;
          font-weight: 500;
        }

        label.day-label.other-month {
          color: #7a89d0;
        }

        label.day-label.today-label {
          color: #ff7edb;
          font-weight: 800;
        }
        """
        provider = Gtk.CssProvider()
        provider.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

    def build_ui(self) -> None:
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add(root)

        frame = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        frame.set_name("calendar-frame")
        root.pack_start(frame, True, True, 0)

        header = Gtk.Fixed()
        header.set_size_request(388, 72)
        frame.pack_start(header, False, False, 0)

        self.prev_button = self.make_control("‹", self.on_prev_month, 44, 32)
        header.put(self.prev_button, 0, 14)

        self.title_label = Gtk.Label()
        self.title_label.set_name("calendar-title")
        self.title_label.set_size_request(190, 24)
        self.title_label.set_xalign(0.5)
        header.put(self.title_label, 99, 2)

        self.subtitle_label = Gtk.Label(label="CURRENT MONTH VIEW")
        self.subtitle_label.set_name("calendar-subtitle")
        self.subtitle_label.set_size_request(190, 18)
        self.subtitle_label.set_xalign(0.5)
        header.put(self.subtitle_label, 99, 30)

        self.today_button = self.make_control("Today", self.on_today, 96, 32, button_name="today-button", label_name="today-label")
        header.put(self.today_button, 260, 14)

        self.next_button = self.make_control("›", self.on_next_month, 44, 32)
        header.put(self.next_button, 344, 14)

        separator = Gtk.EventBox()
        separator.set_name("calendar-separator")
        separator.set_size_request(388, 2)
        frame.pack_start(separator, False, False, 0)

        grid_shell = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        grid_shell.set_name("calendar-grid-shell")
        grid_shell.set_size_request(388, 286)
        frame.pack_start(grid_shell, False, False, 0)

        weekday_grid = Gtk.Grid()
        weekday_grid.set_column_spacing(8)
        weekday_grid.set_row_spacing(0)
        weekday_grid.set_column_homogeneous(True)
        grid_shell.pack_start(weekday_grid, False, False, 0)

        for col, weekday in enumerate(WEEKDAYS):
            label = Gtk.Label(label=weekday)
            label.set_size_request(42, 24)
            label.get_style_context().add_class("weekday-label")
            label.set_xalign(0.5)
            weekday_grid.attach(label, col, 0, 1, 1)

        self.days_grid = Gtk.Grid()
        self.days_grid.set_column_spacing(8)
        self.days_grid.set_row_spacing(8)
        self.days_grid.set_column_homogeneous(True)
        self.days_grid.set_row_homogeneous(True)
        grid_shell.pack_start(self.days_grid, False, False, 0)

        for row in range(6):
            for col in range(7):
                box = Gtk.EventBox()
                box.get_style_context().add_class("day-cell")
                box.set_size_request(42, 38)

                label = Gtk.Label()
                label.get_style_context().add_class("day-label")
                label.set_xalign(0.5)
                label.set_yalign(0.5)

                box.add(label)
                self.days_grid.attach(box, col, row, 1, 1)
                self.day_boxes.append(box)
                self.day_labels.append(label)

    def make_control(
        self,
        text: str,
        handler,
        width: int,
        height: int,
        button_name: str | None = None,
        label_name: str | None = None,
    ) -> Gtk.EventBox:
        button = Gtk.EventBox()
        button.set_visible_window(True)
        button.set_size_request(width, height)
        if button_name:
            button.set_name(button_name)
        button.get_style_context().add_class("calendar-control")
        button.set_events(
            button.get_events()
            | Gdk.EventMask.ENTER_NOTIFY_MASK
            | Gdk.EventMask.LEAVE_NOTIFY_MASK
            | Gdk.EventMask.BUTTON_PRESS_MASK
        )
        button.connect("enter-notify-event", self.on_control_enter)
        button.connect("leave-notify-event", self.on_control_leave)
        button.connect("button-press-event", lambda *_args: handler(None) or True)

        inner = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        inner.set_size_request(width, height)

        label = Gtk.Label(label=text)
        label.set_size_request(width - 4, height - 4)
        if label_name:
            label.set_name(label_name)
        label.get_style_context().add_class("control-label")
        label.set_xalign(0.5)
        label.set_yalign(0.5)

        inner.pack_start(label, True, True, 0)
        button.add(inner)
        button.label_widget = label
        return button

    def on_control_enter(self, widget: Gtk.EventBox, *_args) -> bool:
        widget.get_style_context().add_class("hover")
        label = getattr(widget, "label_widget", None)
        if label is not None:
            label.get_style_context().add_class("hover")
        return False

    def on_control_leave(self, widget: Gtk.EventBox, *_args) -> bool:
        widget.get_style_context().remove_class("hover")
        label = getattr(widget, "label_widget", None)
        if label is not None:
            label.get_style_context().remove_class("hover")
        return False

    def render_month(self) -> None:
        self.title_label.set_text(f"{MONTH_NAMES[self.view_month - 1]} {self.view_year}")

        cal = calendar.Calendar(firstweekday=6)
        weeks = cal.monthdatescalendar(self.view_year, self.view_month)
        while len(weeks) < 6:
            last = weeks[-1][-1]
            next_week = [last + dt.timedelta(days=i) for i in range(1, 8)]
            weeks.append(next_week)

        flat_days = [day for week in weeks[:6] for day in week]
        for day, box, label in zip(flat_days, self.day_boxes, self.day_labels):
            label.set_text(str(day.day))
            context = label.get_style_context()
            box_context = box.get_style_context()

            context.remove_class("other-month")
            context.remove_class("today-label")
            box_context.remove_class("today-cell")

            if day.month != self.view_month:
                context.add_class("other-month")

            if day == self.today and day.month == self.view_month and day.year == self.view_year:
                context.add_class("today-label")
                box_context.add_class("today-cell")

    def on_prev_month(self, _button) -> None:
        if self.view_month == 1:
            self.view_month = 12
            self.view_year -= 1
        else:
            self.view_month -= 1
        self.render_month()

    def on_next_month(self, _button) -> None:
        if self.view_month == 12:
            self.view_month = 1
            self.view_year += 1
        else:
            self.view_month += 1
        self.render_month()

    def on_today(self, _button) -> None:
        self.view_year = self.today.year
        self.view_month = self.today.month
        self.render_month()

    def on_key_press(self, _widget: Gtk.Widget, event: Gdk.EventKey) -> bool:
        if event.keyval in (Gdk.KEY_Escape, Gdk.KEY_q):
            self.close()
            return True
        if event.keyval == Gdk.KEY_Left:
            self.on_prev_month(None)
            return True
        if event.keyval == Gdk.KEY_Right:
            self.on_next_month(None)
            return True
        if event.keyval == Gdk.KEY_Home:
            self.on_today(None)
            return True
        return False

    def on_destroy(self, *_args) -> None:
        PIDFILE.unlink(missing_ok=True)
        STAMPFILE.unlink(missing_ok=True)
        Gtk.main_quit()


def main() -> None:
    toggle_existing_instance()
    PIDFILE.write_text(str(os.getpid()))
    window = CalendarWindow()
    window.show_all()
    Gtk.main()


if __name__ == "__main__":
    main()
