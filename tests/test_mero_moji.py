import importlib.util
import unittest
from pathlib import Path
from unittest.mock import patch


APP = Path(__file__).resolve().parents[1] / "mero-moji"


def load_module(name):
    spec = importlib.util.spec_from_file_location(name, APP / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


catalog = load_module("catalog")
insertion = load_module("insertion")


class MeroMojiTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.version, cls.entries = catalog.load_catalog()

    def test_searches_keywords_and_new_emoji(self):
        self.assertEqual(catalog.search(self.entries, "feet")[0].glyph, "🦶")
        self.assertIn("😂", [entry.glyph for entry in catalog.search(self.entries, ":joy:")])
        new = catalog.search(self.entries, "distorted face")[0]
        self.assertEqual((new.glyph, new.version), ("🫪", self.version))

    def test_variants_include_feet_and_mixed_tones(self):
        foot = catalog.search(self.entries, "foot")[0]
        self.assertEqual([glyph for glyph, _ in foot.variants], ["🦶🏻", "🦶🏼", "🦶🏽", "🦶🏾", "🦶🏿"])
        handshake = catalog.search(self.entries, "handshake")[0]
        self.assertIn("🫱🏻‍🫲🏼", [glyph for glyph, _ in handshake.variants])

    @patch.object(insertion.subprocess, "run")
    @patch.object(insertion, "wait_for_focus")
    def test_insertion_only_types_after_restoring_focus(self, wait_for_focus, run):
        wait_for_focus.side_effect = [False, False]
        with self.assertRaisesRegex(RuntimeError, "original window"):
            insertion.insert("🦶🏼", {"address": "0xbeef"})
        run.assert_called_once()
        self.assertEqual(run.call_args.args[0][1:], ["focuswindow", "address:0xbeef"])

    @patch.object(insertion.subprocess, "run")
    @patch.object(insertion, "wait_for_focus", return_value=True)
    def test_both_backends_type_without_the_clipboard(self, _wait_for_focus, run):
        insertion.insert("🦶🏼", {"address": "0xbeef", "xwayland": False})
        native = run.call_args.args[0]
        self.assertEqual(native[0], "wtype")
        self.assertIn("🦶🏼", native)

        insertion.insert("🦶🏼", {"address": "0xbeef", "xwayland": True})
        xwayland = run.call_args.args[0]
        self.assertEqual(xwayland[0], "xdotool")
        self.assertEqual(xwayland[-2:], ["U1F9B6", "U1F3FC"])

    @patch.object(insertion, "uses_chromium_input", return_value=True)
    def test_chromium_uses_hex_composition(self, _uses_chromium_input):
        command = insertion.typing_command("🦶🏼", {"pid": 1234})
        self.assertIn("1f9b6", command)
        self.assertIn("1f3fc", command)
        self.assertEqual(command.count("Return"), 2)
