#!/usr/bin/env python3
"""Convert CAVA raw ASCII frames into Waybar JSON spectrum updates."""

from __future__ import annotations

import json
import sys


GLYPHS = "▁▂▃▄▅▆▇█"
BAR_COUNT = 18
MAX_VALUE = 1000.0


def frame_values(line: str) -> list[float]:
    values = []
    for item in line.strip().split(";"):
        try:
            values.append(max(0.0, min(MAX_VALUE, float(item))))
        except ValueError:
            continue
    return values[:BAR_COUNT]


def render(values: list[float]) -> dict[str, str]:
    values += [0.0] * (BAR_COUNT - len(values))
    bars = "".join(GLYPHS[min(len(GLYPHS) - 1, int(v / MAX_VALUE * len(GLYPHS)))] for v in values)
    peak = max(values, default=0.0) / MAX_VALUE
    state = "quiet" if peak < 0.08 else "spark" if peak < 0.32 else "flow" if peak < 0.68 else "surge"
    return {"text": bars, "class": state, "tooltip": f"CAVA spectrum · peak {peak:.0%}"}


def main() -> int:
    for line in sys.stdin:
        values = frame_values(line)
        if values:
            print(json.dumps(render(values), ensure_ascii=False), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
