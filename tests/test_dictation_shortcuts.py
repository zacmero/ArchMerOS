import os
from pathlib import Path
import subprocess
from tempfile import TemporaryDirectory
import unittest


SHORTCUT = Path(__file__).resolve().parents[1] / "config/archmeros/scripts/archmeros-dictation.sh"


class DictationShortcutsTest(unittest.TestCase):
    def test_pause_release_only_stops_a_hold_recording(self):
        with TemporaryDirectory() as temp_dir:
            directory = Path(temp_dir)
            voxtype = directory / "voxtype"
            voxtype.write_text(
                '#!/usr/bin/env bash\n'
                'if [[ "$1" == status ]]; then\n'
                '  cat "$XDG_RUNTIME_DIR/state"\n'
                'else\n'
                '  printf "%s\\n" "$2" >> "$XDG_RUNTIME_DIR/actions"\n'
                'fi\n'
            )
            voxtype.chmod(0o755)
            env = {**os.environ, "XDG_RUNTIME_DIR": temp_dir, "PATH": f"{temp_dir}:{os.environ['PATH']}"}
            state = directory / "state"

            state.write_text("idle")
            for action in ("hold", "release", "release", "toggle"):
                subprocess.run([SHORTCUT, action], env=env, check=True)

            state.write_text("recording")
            for action in ("release", "hold", "release", "toggle"):
                subprocess.run([SHORTCUT, action], env=env, check=True)

            self.assertEqual((directory / "actions").read_text().splitlines(), [
                "start", "stop", "toggle", "toggle",
            ])
