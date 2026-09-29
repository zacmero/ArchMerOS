#!/usr/bin/env python3
"""Focused checks for Beacon's local Git feed and audio renderer."""

import ast
import importlib.util
import io
import json
import tempfile
import time
import unittest
from unittest.mock import patch
from contextlib import redirect_stdout
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class BeaconTests(unittest.TestCase):
    def test_moon_stream_sleeps_inside_loop(self):
        path = ROOT / "config/archmeros/scripts/archmeros-beacon-moon.py"
        tree = ast.parse(path.read_text())
        main = next(node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name == "main")
        loop = next(node for node in ast.walk(main) if isinstance(node, ast.While))
        self.assertTrue(any(isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
                            and node.func.attr == "sleep" for statement in loop.body
                            for node in ast.walk(statement)))

    def test_moon_phase_weather_and_roman_clock(self):
        moon = load("beacon_moon", ROOT / "config/archmeros/scripts/archmeros-beacon-moon.py")
        self.assertEqual(moon.roman(2026), "MMXXVI")
        self.assertEqual(moon.roman(0), "N")
        self.assertEqual(moon.phase(moon.NEW_MOON)[0], "New Moon")
        self.assertEqual(moon.weather_mode({"cloud": 79, "rain": 0.1, "code": 176}), "rain")
        self.assertEqual(moon.weather_mode({"cloud": 79, "rain": 0, "code": 119}), "cloud")
        output = moon.moon_output(moon.NEW_MOON, {"cloud": 79, "rain": 0.1, "code": 176}, 1)
        self.assertIn("VI / I / MM", output["tooltip"])
        self.assertEqual(output["tooltip"], moon.moon_output(moon.NEW_MOON.replace(second=30), {"cloud": 79, "rain": 0.1, "code": 176}, 2)["tooltip"])
        self.assertEqual(output["class"], "rain")
        self.assertNotIn("New Moon", output["text"])
        self.assertNotEqual(moon.moon_art(0.4, "rain", 0), moon.moon_art(0.4, "rain", 1))
        self.assertNotEqual(moon.moon_art(0.4, "cloud", 0), moon.moon_art(0.4, "cloud", 1))
        self.assertNotEqual(moon.moon_art(0.4, "stars", 0), moon.moon_art(0.4, "stars", 1))
        self.assertTrue(all(len(row) == 15 for row in output["text"].splitlines()))
        with patch.object(moon.subprocess, "run") as notify:
            moon.show_moon(moon.NEW_MOON, {"cloud": 79, "rain": 0.1, "code": 176})
        command = notify.call_args.args[0]
        self.assertEqual(command[0], "notify-send")
        self.assertEqual(command[-2], "New Moon")
        self.assertIn("Farroupilha, RS", command[-1])

    def test_git_feed_shows_five_and_history_keeps_more(self):
        events = load("git_events_history", ROOT / "config/archmeros/scripts/archmeros-git-events.py")
        now = time.time()
        sample = [
            {"time": now - index, "kind": "PR" if index == 0 else "PUSH",
             "repo": f"repo-{index}", "head": str(index), "detail": "opened"}
            for index in range(7)
        ]
        events.collect_events = lambda: (sample, True)
        output = io.StringIO()
        with redirect_stdout(output):
            events.main()
        self.assertEqual(len(json.loads(output.getvalue())["text"].splitlines()), 5)
        self.assertIn("repo-6", events.history(sample, True))
        self.assertIn("\033[38;2;241;199;132m", events.history(sample, True))

    def test_familiar_state_and_sigils(self):
        familiar = load("beacon_familiar", ROOT / "config/archmeros/scripts/archmeros-beacon-familiar.py")
        services = familiar.rank([
            familiar.service("ssh", "idle"),
            familiar.service("herdr", "busy", cpu=9.0, count=2),
            familiar.service("oracle", "failed"),
        ])
        state = {
            "services": services,
            "network": "full",
            "ci_failed": False,
            "agent_flash": False,
            "ai_active": False,
            "audio_peak": 0.0,
            "wall_time": time.time(),
            "oracle_detail": "online",
            "repo": "none",
        }
        self.assertEqual(services[-1]["key"], "oracle")
        self.assertEqual(familiar.mode(state), "working")
        self.assertEqual(familiar.art(state, 0)["class"], "working")
        symbols = familiar.sigils(state)
        self.assertEqual(len(symbols["text"].splitlines()), 3)
        self.assertNotIn("Herdr", symbols["text"])
        self.assertIn("Herdr", symbols["tooltip"])
        self.assertIn("#d0a4eb", symbols["text"])
        self.assertIn("#ff6688", symbols["text"])
        self.assertIn("read-only", familiar.context(state))
        self.assertIn("Daemon Master", familiar.context(state))
        state["services"] = familiar.rank(services + [
            familiar.service("syncthing", "running"),
            familiar.service("pipewire", "running"),
            familiar.service("ai", "idle"),
            familiar.service("repo", "idle"),
        ])
        self.assertEqual(len(familiar.sigils(state)["text"].splitlines()), 5)
        self.assertIn("#ff6688", familiar.sigils(state)["text"])

    def test_local_commit_and_push_reflogs(self):
        events = load("git_events", ROOT / "config/archmeros/scripts/archmeros-git-events.py")
        stamp = int(time.time())
        old, new = "a" * 40, "b" * 40
        prefix = f"{old} {new} Agent <agent@example.invalid> {stamp} +0000\t"
        with tempfile.TemporaryDirectory() as temp:
            events.PROJECTS = Path(temp)
            git = events.PROJECTS / "repo" / ".git" / "logs"
            remote = git / "refs" / "remotes" / "origin"
            remote.mkdir(parents=True)
            (git / "HEAD").write_text(prefix + "checkout: moving from main to test\n" + prefix + "commit: feature\n")
            (remote / "main").write_text(prefix + "update by push\n")
            found = events.local_events()
        self.assertEqual({event["kind"] for event in found}, {"COMMIT", "PUSH"})
        self.assertTrue(all(event["head"] == new for event in found))

    def test_spectrum_grid(self):
        cava = load("cava_waybar", ROOT / "config/archmeros/scripts/archmeros-cava-waybar.py")
        image = cava.render([1000.0] + [0.0] * 19)
        rows = image["text"].splitlines()
        self.assertEqual(len(rows), 10)
        self.assertTrue(all(len(row) == 20 for row in rows))
        self.assertEqual(image["class"], "surge")

    def test_silence_switches_to_white_pattern_after_five_seconds(self):
        cava = load("cava_waybar", ROOT / "config/archmeros/scripts/archmeros-cava-waybar.py")
        quiet, last_sound = cava.visual([0.0] * 20, 100.0, 104.9)
        idle, last_sound = cava.visual([0.0] * 20, last_sound, 105.0)
        next_pulse, _ = cava.visual([0.0] * 20, last_sound, 105.25)
        resumed, last_sound = cava.visual([200.0] + [0.0] * 19, last_sound, 105.3)
        self.assertEqual(quiet["class"], "quiet")
        self.assertEqual(idle["class"], "idle-pulse")
        self.assertNotEqual(idle["text"], next_pulse["text"])
        self.assertEqual(len(idle["text"].splitlines()), 10)
        self.assertTrue(all(len(row) == 20 for row in idle["text"].splitlines()))
        self.assertNotEqual(resumed["class"], "idle-pulse")
        self.assertEqual(last_sound, 105.3)



if __name__ == "__main__":
    unittest.main()
