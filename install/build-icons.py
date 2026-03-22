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

Directories=16x16/places,22x22/places,24x24/places,32x32/places,48x48/places,64x64/places,96x96/places,128x128/places
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
"""


def rewrite_svg(source: Path, target: Path) -> None:
    data = source.read_text(encoding="utf-8")
    data = data.replace("#5294e2", BASE_COLOR)
    data = data.replace("#4877b1", SHADE_COLOR)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(data, encoding="utf-8")


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

    print(f"generated {count} folder icons in {TARGET_THEME}")


if __name__ == "__main__":
    main()
