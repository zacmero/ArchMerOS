from pathlib import Path
import subprocess
import unittest

SCRIPTS = Path(__file__).resolve().parents[1] / "config/archmeros/scripts"


class ScreensaverConfigTest(unittest.TestCase):
    def test_shell_syntax(self):
        subprocess.run(["bash", "-n", str(SCRIPTS / "archmeros-screensaver.sh"),
                        str(SCRIPTS / "archmeros-screensaver-window.sh")], check=True)

    def test_bravia_has_off_and_restore(self):
        script = (SCRIPTS / "archmeros-screensaver.sh").read_text()
        self.assertIn("dpms off DP-1", script)
        self.assertIn("dpms on DP-1", script)

    def test_lightweight_slideshow_keeps_playlist(self):
        script = (SCRIPTS / "archmeros-screensaver-window.sh").read_text()
        for option in ["--vo=gpu", "--gpu-context=wayland", "--scale=bilinear",
                       "--interpolation=no", "--video-sync=audio",
                       '--playlist="$playlist_path"', '--image-display-duration="$duration"']:
            self.assertIn(option, script)
