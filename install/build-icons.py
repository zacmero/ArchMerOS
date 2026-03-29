#!/usr/bin/env python3

from __future__ import annotations

from pathlib import Path
import shutil


REPO_ROOT = Path(__file__).resolve().parent.parent
SOURCE_THEME = REPO_ROOT / "vendor" / "papirus-icon-theme" / "Papirus-Dark"
TARGET_THEME = REPO_ROOT / "local" / "share" / "icons" / "ArchMerOS-Icons"

BASE_COLOR = "#563a69"   # Dracula comment
SHADE_COLOR = "#4f5d86"


INDEX_THEME = """[Icon Theme]
Name=ArchMerOS-Icons
Comment=ArchMerOS icon theme with Dracula comment folders
Inherits=Papirus-Dark,breeze-dark,hicolor
Example=folder
FollowsColorScheme=true

Directories=16x16/places,22x22/places,24x24/places,32x32/places,48x48/places,64x64/places,96x96/places,128x128/places,scalable/apps
ScaledDirectories=16x16@2x/places,22x22@2x/places,24x24@2x/places,32x32@2x/places,48x48@2x/places,64x64@2x/places

[16x16/places]
Context=Places
Size=16
Type=Fixed

[22x22/places]
Context=Places
Size=22
Type=Fixed

[24x24/places]
Context=Places
Size=24
Type=Fixed

[32x32/places]
Context=Places
Size=32
Type=Fixed

[48x48/places]
Context=Places
Size=48
Type=Fixed

[64x64/places]
Context=Places
Size=64
Type=Fixed

[96x96/places]
Context=Places
Size=96
Type=Fixed

[128x128/places]
Context=Places
Size=128
Type=Fixed

[16x16@2x/places]
Context=Places
Size=16
Scale=2
Type=Fixed

[22x22@2x/places]
Context=Places
Size=22
Scale=2
Type=Fixed

[24x24@2x/places]
Context=Places
Size=24
Scale=2
Type=Fixed

[32x32@2x/places]
Context=Places
Size=32
Scale=2
Type=Fixed

[48x48@2x/places]
Context=Places
Size=48
Scale=2
Type=Fixed

[64x64@2x/places]
Context=Places
Size=64
Scale=2
Type=Fixed

[scalable/apps]
Context=Applications
Size=128
MinSize=16
MaxSize=512
Type=Scalable
"""


NIGHT_DRIVE_ICON = """<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256" fill="none">
  <defs>
    <linearGradient id="bg" x1="32" y1="24" x2="224" y2="232" gradientUnits="userSpaceOnUse">
      <stop stop-color="#0D1224"/>
      <stop offset="1" stop-color="#05070E"/>
    </linearGradient>
    <linearGradient id="frame" x1="48" y1="40" x2="208" y2="216" gradientUnits="userSpaceOnUse">
      <stop stop-color="#58D6FF"/>
      <stop offset="0.55" stop-color="#BE92FF"/>
      <stop offset="1" stop-color="#FF7EDB"/>
    </linearGradient>
    <linearGradient id="sun" x1="128" y1="98" x2="128" y2="162" gradientUnits="userSpaceOnUse">
      <stop stop-color="#FFD86F"/>
      <stop offset="0.45" stop-color="#FF7EDB"/>
      <stop offset="1" stop-color="#BE92FF"/>
    </linearGradient>
    <linearGradient id="road" x1="128" y1="154" x2="128" y2="226" gradientUnits="userSpaceOnUse">
      <stop stop-color="#1B2140"/>
      <stop offset="1" stop-color="#0A0E1C"/>
    </linearGradient>
  </defs>
  <rect x="18" y="18" width="220" height="220" rx="34" fill="url(#bg)"/>
  <rect x="18" y="18" width="220" height="220" rx="34" stroke="url(#frame)" stroke-width="10"/>
  <rect x="42" y="40" width="172" height="22" rx="11" fill="#131A33"/>
  <circle cx="60" cy="51" r="4" fill="#FF7EDB"/>
  <circle cx="76" cy="51" r="4" fill="#BE92FF"/>
  <circle cx="92" cy="51" r="4" fill="#58D6FF"/>
  <path d="M64 90H122L138 106L122 122H64V90Z" fill="#0F1730" stroke="#58D6FF" stroke-width="6" stroke-linejoin="round"/>
  <path d="M88 97L76 106L88 115" stroke="#58D6FF" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M98 118H114" stroke="#FF7EDB" stroke-width="6" stroke-linecap="round"/>
  <circle cx="182" cy="116" r="34" fill="url(#sun)"/>
  <path d="M148 101H216" stroke="#0D1224" stroke-width="4"/>
  <path d="M152 113H212" stroke="#0D1224" stroke-width="4"/>
  <path d="M148 125H216" stroke="#0D1224" stroke-width="4"/>
  <path d="M156 137H208" stroke="#0D1224" stroke-width="4"/>
  <path d="M66 154L128 222L190 154H66Z" fill="url(#road)"/>
  <path d="M128 160V220" stroke="#58D6FF" stroke-width="4" stroke-dasharray="10 10"/>
  <path d="M94 154L66 222" stroke="#BE92FF" stroke-width="3"/>
  <path d="M162 154L190 222" stroke="#FF7EDB" stroke-width="3"/>
  <path d="M80 171H176" stroke="#202A4E" stroke-width="3"/>
  <path d="M72 186H184" stroke="#1B2342" stroke-width="3"/>
  <path d="M64 201H192" stroke="#151D38" stroke-width="3"/>
  <path d="M92 186L104 176H126L140 188H160L170 198" stroke="#D8DDFF" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="88" cy="200" r="9" fill="#05070E" stroke="#58D6FF" stroke-width="5"/>
  <circle cx="168" cy="200" r="9" fill="#05070E" stroke="#FF7EDB" stroke-width="5"/>
</svg>
"""


def rewrite_svg(source: Path, target: Path) -> None:
    data = source.read_text(encoding="utf-8")
    data = data.replace("#5294e2", BASE_COLOR)
    data = data.replace("#4877b1", SHADE_COLOR)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(data, encoding="utf-8")


def write_app_icons(target_theme: Path) -> None:
    target = target_theme / "scalable" / "apps" / "archmeros-night-drive.svg"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(NIGHT_DRIVE_ICON, encoding="utf-8")


def main() -> None:
    if not SOURCE_THEME.exists():
        raise SystemExit(f"Missing Papirus source theme: {SOURCE_THEME}")

    if TARGET_THEME.exists():
        shutil.rmtree(TARGET_THEME)

    TARGET_THEME.mkdir(parents=True, exist_ok=True)
    (TARGET_THEME / "index.theme").write_text(INDEX_THEME, encoding="utf-8")

    count = 0
    for source in SOURCE_THEME.rglob("folder*.svg"):
        if "/places/" not in source.as_posix():
            continue
        rel = source.relative_to(SOURCE_THEME)
        rewrite_svg(source, TARGET_THEME / rel)
        count += 1

    write_app_icons(TARGET_THEME)

    print(f"generated {count} folder icons in {TARGET_THEME}")


if __name__ == "__main__":
    main()
