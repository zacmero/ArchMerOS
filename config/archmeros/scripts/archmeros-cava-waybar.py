#!/usr/bin/env python3
"""Convert CAVA raw ASCII frames into Waybar JSON spectrum updates."""

from __future__ import annotations

import json
import sys
import time


BAR_COUNT = 20
ROW_COUNT = 10
MAX_VALUE = 1000.0
SOUND_THRESHOLD = 10.0
IDLE_AFTER_SECONDS = 5.0
PULSE_RADII = (0.20, 0.35, 0.50, 0.65, 0.80, 0.65, 0.50, 0.35)


def idle_pattern(now: float) -> str:
    radius = PULSE_RADII[int(now * 4) % len(PULSE_RADII)]
    rows = []
    for row in range(ROW_COUNT):
        y = (row - (ROW_COUNT - 1) / 2) / ((ROW_COUNT - 1) / 2)
        cells = []
        for column in range(BAR_COUNT):
            x = (column - (BAR_COUNT - 1) / 2) / ((BAR_COUNT - 1) / 2)
            distance = (x * x + y * y) ** 0.5
            cells.append("▮" if abs(distance - radius) < 0.17 else "·")
        rows.append("".join(cells))
    return "\n".join(rows)


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
    levels = [min(ROW_COUNT, round(v / MAX_VALUE * ROW_COUNT)) for v in values]
    bars = "\n".join(
        "".join("▮" if level > row else "·" for level in levels)
        for row in reversed(range(ROW_COUNT))
    )
    peak = max(values, default=0.0) / MAX_VALUE
    state = "quiet" if peak < 0.08 else "spark" if peak < 0.32 else "flow" if peak < 0.68 else "surge"
    return {"text": bars, "class": state, "tooltip": f"CAVA spectrum · peak {peak:.0%}"}


def visual(values: list[float], last_sound: float, now: float) -> tuple[dict[str, str], float]:
    if max(values, default=0.0) > SOUND_THRESHOLD:
        last_sound = now
    if now - last_sound >= IDLE_AFTER_SECONDS:
        return {"text": idle_pattern(now), "class": "idle-pulse", "tooltip": "No audio detected"}, last_sound
    return render(values), last_sound


def main() -> int:
    last_sound = time.monotonic()
    previous = None
    for line in sys.stdin:
        values = frame_values(line)
        if values:
            frame, last_sound = visual(values, last_sound, time.monotonic())
            if frame != previous:
                print(json.dumps(frame, ensure_ascii=False), flush=True)
                previous = frame
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
