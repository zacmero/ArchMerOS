from pathlib import Path
import subprocess
import unittest

SCRIPTS = Path(__file__).resolve().parents[1] / "config/archmeros/scripts"


class ScreensaverConfigTest(unittest.TestCase):
    def test_resume_and_waybar_guards(self):
        stop = (SCRIPTS / "archmeros-screensaver-stop.sh").read_text()
        self.assertIn('"--force"', stop)
        waybar = (SCRIPTS / "archmeros-waybar.sh").read_text()
        self.assertIn("flock 9", waybar)
        self.assertIn("9>&- &", waybar)
        window = (SCRIPTS / "archmeros-screensaver-window.sh").read_text()
        self.assertIn("--stop-screensaver=no", window)

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
