#!/usr/bin/env python3
"""Focused checks for Beacon's local Git feed and audio renderer."""

import importlib.util
import tempfile
import time
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class BeaconTests(unittest.TestCase):
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
