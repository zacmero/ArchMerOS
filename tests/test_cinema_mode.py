#!/usr/bin/env python3
"""Focused-output cinema mode must only restore displays it changed."""

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "config/archmeros/scripts/archmeros-cinema-mode.sh"


def executable(path: Path, body: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("#!/usr/bin/env bash\n" + body)
    path.chmod(0o755)


class CinemaModeTests(unittest.TestCase):
    def test_focused_output_and_restore(self):
        for focused in ("HDMI-A-1", "DP-1"):
            with self.subTest(focused=focused), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                home = root / "home"
                scripts = home / ".config/archmeros/scripts"
                binaries = root / "bin"
                log = root / "calls.log"
                monitors = [
                    {"name": name, "focused": name == focused, "dpmsStatus": True}
                    for name in ("HDMI-A-1", "DP-1", "DP-2", "DP-3")
                ]
                executable(binaries / "hyprctl", 'printf "%s\\n" "$MOCK_MONITORS"\n')
                executable(binaries / "systemctl", 'case "$*" in *is-active*) exit 0;; esac\nprintf "service:%s\\n" "$*" >>"$MOCK_LOG"\n')
                executable(scripts / "archmeros-hyprctl-dispatch.sh", 'printf "dpms:%s\\n" "$*" >>"$MOCK_LOG"\n')
                executable(scripts / "archmeros-side-blackout.sh", '[[ "$1" != running ]] || exit 1\nprintf "blackout:%s\\n" "$1" >>"$MOCK_LOG"\n')
                env = {**os.environ, "HOME": str(home), "XDG_STATE_HOME": str(root / "state"),
                       "MOCK_MONITORS": json.dumps(monitors), "MOCK_LOG": str(log),
                       "PATH": f"{binaries}:{os.environ['PATH']}"}

                subprocess.run([SCRIPT, "toggle"], env=env, check=True)
                state = json.loads((root / "state/archmeros/cinema-mode.json").read_text())
                expected = [name for name in ("HDMI-A-1", "DP-1", "DP-2") if name != focused]
                self.assertEqual(state["keep"], focused)
                self.assertEqual(state["dpms_off"], expected)
                self.assertTrue(state["blackout_started"])
                self.assertTrue(state["turzx_stopped"])

                subprocess.run([SCRIPT, "toggle"], env=env, check=True)
                calls = log.read_text()
                for name in expected:
                    self.assertIn(f"dpms:dpms off {name}", calls)
                    self.assertIn(f"dpms:dpms on {name}", calls)
                self.assertNotIn(f"dpms:dpms off {focused}", calls)
                self.assertIn("blackout:start", calls)
                self.assertIn("blackout:stop", calls)
                self.assertIn("stop turzx-monitor.service", calls)
                self.assertIn("start turzx-monitor.service", calls)
                self.assertNotIn("mero-bridge", calls)
                self.assertFalse((root / "state/archmeros/cinema-mode.json").exists())


if __name__ == "__main__":
    unittest.main()
