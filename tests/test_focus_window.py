import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location(
    "focus_window", Path(__file__).resolve().parents[1] /
    "config/archmeros/scripts/archmeros-focus-window.py")
focus = importlib.util.module_from_spec(spec)
spec.loader.exec_module(focus)


class FocusRoutingTest(unittest.TestCase):
    def setUp(self):
        self.monitors = [dict(id=i, x=i * 1000, y=0, width=1000,
                              height=800, scale=1, dpmsStatus=True)
                         for i in range(3)]

    def test_nearer_monitor_in_both_directions(self):
        for source, destination, direction in [(0, 2, "right"), (2, 0, "left")]:
            self.assertEqual(focus.nearer_monitor(self.monitors[source],
                self.monitors[destination], self.monitors, direction)["id"], 1)

    def test_adjacent_and_disabled_monitor(self):
        self.assertIsNone(focus.nearer_monitor(self.monitors[0],
            self.monitors[1], self.monitors, "right"))
        self.monitors[1]["dpmsStatus"] = False
        self.assertIsNone(focus.nearer_monitor(self.monitors[0],
            self.monitors[2], self.monitors, "right"))

    def test_vertical_layout(self):
        for i, monitor in enumerate(self.monitors):
            monitor.update(x=0, y=i * 800)
        self.assertEqual(focus.nearer_monitor(self.monitors[0],
            self.monitors[2], self.monitors, "down")["id"], 1)

    def test_select_before_dispatch_without_application_filter(self):
        for monitor in self.monitors:
            monitor["activeWorkspace"] = {"id": monitor["id"] + 1}
        def window(address, monitor, app, floating):
            return dict(address=address, monitor=monitor, mapped=True, hidden=False,
                        workspace={"id": monitor + 1}, at=[monitor * 1000, 0],
                        size=[900, 700], focusHistoryID=0, **{"class": app},
                        floating=floating)
        source = window("source", 0, "terminal", True)
        firefox = window("firefox", 1, "firefox", False)
        terminal = window("terminal", 2, "terminal", True)
        self.assertEqual(focus.select_window(source, self.monitors,
            [source, firefox, terminal], "right"), firefox)
        self.assertEqual(focus.select_window(terminal, self.monitors,
            [source, firefox, terminal], "left"), firefox)
