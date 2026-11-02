import importlib.util
from pathlib import Path
import unittest
import tempfile
import json
import os

spec = importlib.util.spec_from_file_location("photopea_hosts", Path(__file__).resolve().parents[1] /
    "config/archmeros/scripts/archmeros-photopea-browser.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PhotopeaHostsTest(unittest.TestCase):
    def test_prompt_preserves_preferences_and_makes_backup(self):
        with tempfile.TemporaryDirectory() as directory:
            preferences = Path(directory) / "Default" / "Preferences"
            preferences.parent.mkdir()
            original = {"download": {"default_directory": "/tmp/export"}, "custom": 42}
            preferences.write_text(json.dumps(original))
            self.assertTrue(module.configure_download_prompt(directory))
            result = json.loads(preferences.read_text())
            self.assertTrue(result["download"]["prompt_for_download"])
            self.assertEqual(result["download"]["default_directory"], "/tmp/export")
            self.assertEqual(result["custom"], 42)
            backups = list(preferences.parent.glob("Preferences.before-save-prompt-*"))
            self.assertEqual(len(backups), 1)
            self.assertEqual(json.loads(backups[0].read_text()), original)
            module.configure_download_prompt(directory)
            self.assertEqual(len(list(preferences.parent.glob("Preferences.before-save-prompt-*"))), 1)

    def test_running_browser_preferences_not_touched(self):
        with tempfile.TemporaryDirectory() as directory:
            (Path(directory) / "SingletonLock").symlink_to(f"{os.uname().nodename}-{os.getpid()}")
            self.assertFalse(module.configure_download_prompt(directory))
            self.assertFalse((Path(directory) / "Default").exists())

    def test_first_launch_creates_prompt(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertTrue(module.configure_download_prompt(directory))
            data = json.loads((Path(directory) / "Default" / "Preferences").read_text())
            self.assertTrue(data["download"]["prompt_for_download"])

    def test_sinkholes_removed_local_entries_preserved(self):
        source = "127.0.0.1 localhost ad.example\n::1 ip6-localhost\n0.0.0.0 ads.example\n127.0.0.2 tracker.example\n:: ipv6ads.example\n192.168.1.5 nas\n"
        result = module.photopea_hosts(source)
        self.assertIn("127.0.0.1 localhost\n", result)
        self.assertIn("::1 ip6-localhost\n", result)
        self.assertIn("192.168.1.5 nas\n", result)
        for blocked in ["ad.example", "ads.example", "tracker.example", "ipv6ads.example"]:
            self.assertNotIn(blocked, result)
