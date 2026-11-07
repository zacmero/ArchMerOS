import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location(
    "focus_window", Path(__file__).resolve().parents[1] /
    "config/archmeros/scripts/archmeros-focus-window.py")
focus = importlib.util.module_from_spec(spec)
spec.loader.exec_module(focus)


class FocusRoutingTest(unittest.TestCase):
    def test_leave_empty_focused_monitor(self):
        for monitor in self.monitors:
            monitor["activeWorkspace"] = {"id": monitor["id"] + 1}
        self.monitors[1]["focused"] = True
        for direction, target_id in [("left", 0), ("right", 2)]:
            target = dict(address="target", monitor=target_id, mapped=True,
                          workspace={"id": target_id + 1})
            self.assertEqual(focus.select_window({}, self.monitors,
                [target], direction), target)

    def test_empty_screen_does_not_select_hidden_workspace(self):
        for monitor in self.monitors:
            monitor["activeWorkspace"] = {"id": monitor["id"] + 1}
        self.monitors[0]["focused"] = True
        hidden = dict(address="hidden", monitor=1, mapped=True,
                      workspace={"id": 99})
        self.assertEqual(focus.select_window({}, self.monitors, [hidden], "right"),
                         {"monitor": 1})

    def test_enter_nearest_empty_monitor_in_both_directions(self):
        for source_id, direction in [(0, "right"), (2, "left")]:
            for monitor in self.monitors:
                monitor["focused"] = monitor["id"] == source_id
            self.assertEqual(focus.select_window({}, self.monitors, [], direction),
                             {"monitor": 1})

    def test_skip_standby_and_disabled_monitors(self):
        self.monitors[0]["focused"] = True
        self.monitors[1]["dpmsStatus"] = False
        self.assertEqual(focus.select_window({}, self.monitors, [], "right"),
                         {"monitor": 2})
        self.monitors[2]["disabled"] = True
        self.assertIsNone(focus.select_window({}, self.monitors, [], "right"))

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
