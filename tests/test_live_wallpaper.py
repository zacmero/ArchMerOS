import importlib.util
from pathlib import Path
import tempfile
import sys
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "config/archmeros/scripts/archmeros-live-wallpaper.py"
spec = importlib.util.spec_from_file_location("live_wallpaper", SCRIPT)
live = importlib.util.module_from_spec(spec)
spec.loader.exec_module(live)


class LiveWallpaperTest(unittest.TestCase):
    def test_cache_identifies_source_resolution_and_changes(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "sample.mp4"
            source.write_bytes(b"source")
            key = live.cache_key(source, 1366, 768)
            self.assertEqual(key, live.cache_key(source, 1366, 768))
            self.assertNotEqual(key, live.cache_key(source, 1920, 1080))
            source.write_bytes(b"changed source")
            self.assertNotEqual(key, live.cache_key(source, 1366, 768))

    def test_conversion_preserves_original_and_reuses_cache(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "sample.mp4"
            source.write_bytes(b"original")
            def convert(command, **kwargs):
                self.assertIn("fps=24", command[command.index("-vf") + 1])
                self.assertIn("-an", command)
                self.assertEqual(command[command.index("-crf") + 1], "18")
                Path(command[-1]).write_bytes(b"converted")
            with patch.object(live, "CACHE", Path(directory) / "cache"), \
                 patch.object(live.subprocess, "run", side_effect=convert) as runner:
                output = live.prepare(source, 1366, 768)
                self.assertEqual(source.read_bytes(), b"original")
                self.assertEqual(live.prepare(source, 1366, 768), output)
                self.assertEqual(runner.call_count, 1)

    def test_failed_conversion_does_not_publish_partial_file(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "sample.mp4"
            source.write_bytes(b"original")
            with patch.object(live, "CACHE", Path(directory) / "cache"), \
                 patch.object(live.subprocess, "run", side_effect=RuntimeError("failure")):
                with self.assertRaises(RuntimeError):
                    live.prepare(source, 1366, 768)
                self.assertFalse(list(live.CACHE.glob("*.mp4")))

    def test_state_keeps_separate_outputs(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(live, "STATE_DIR", Path(directory)), \
                 patch.object(live, "STATE", Path(directory) / "state.json"):
                state = {"DP-3": {"source": "left", "cache": "left-cache"},
                         "DP-1": {"source": "right", "cache": "right-cache"}}
                live.write_state(state)
                self.assertEqual(live.read_state(), state)

    def test_original_mode_does_not_convert_or_replace_source(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source.mp4"
            source.write_bytes(b"original video")
            with patch.object(sys, "argv", [str(SCRIPT), "select", "DP-3", str(source), "--original"]), \
                 patch.object(live, "SOURCE", Path(directory)), \
                 patch.object(live, "monitors", return_value=[{"name": "DP-3", "width": 1366, "height": 768}]), \
                 patch.object(live.shutil, "which", return_value="mpvpaper"), \
                 patch.object(live, "prepare") as convert, \
                 patch.object(live, "read_state", return_value={}), \
                 patch.object(live, "write_state") as save, \
                 patch.object(live, "start"):
                live.main()
                convert.assert_not_called()
                selected = save.call_args.args[0]["DP-3"]
                self.assertTrue(selected["original"])
                self.assertEqual(selected["cache"], str(source))
                self.assertEqual(source.read_bytes(), b"original video")
