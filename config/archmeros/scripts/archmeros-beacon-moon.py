#!/usr/bin/env python3
"""Moon phase and cached Farroupilha weather for the DP-1 Beacon."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import textwrap
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

LOCATION = "Farroupilha, RS"
WEATHER_URL = "https://wttr.in/Farroupilha,RS?format=j1"
CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "archmeros/beacon-weather.json"
STATE = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")) / "archmeros/beacon-familiar.json"
NEW_MOON = datetime(2000, 1, 6, 18, 14, tzinfo=timezone.utc)
SYNODIC_DAYS = 29.530588853
PHASES = ("New Moon", "Waxing Crescent", "First Quarter", "Waxing Gibbous",
          "Full Moon", "Waning Gibbous", "Last Quarter", "Waning Crescent")


def roman(number: int) -> str:
    if number == 0:
        return "N"
    values = ((1000, "M"), (900, "CM"), (500, "D"), (400, "CD"), (100, "C"),
              (90, "XC"), (50, "L"), (40, "XL"), (10, "X"), (9, "IX"),
              (5, "V"), (4, "IV"), (1, "I"))
    result = ""
    for value, glyph in values:
        count, number = divmod(number, value)
        result += glyph * count
    return result


def phase(now: datetime) -> tuple[str, float]:
    fraction = ((now.astimezone(timezone.utc) - NEW_MOON).total_seconds() / 86400 / SYNODIC_DAYS) % 1
    return PHASES[int(fraction * 8 + 0.5) % 8], fraction


def weather(now: float) -> dict:
    try:
        cached = json.loads(CACHE.read_text())
    except (OSError, ValueError):
        cached = {}
    if now - cached.get("checked", 0) < 600:
        return cached
    try:
        request = urllib.request.Request(WEATHER_URL, headers={"User-Agent": "ArchMerOS-Beacon/1.0"})
        with urllib.request.urlopen(request, timeout=4) as response:
            current = json.load(response)["current_condition"][0]
        cached = {"checked": now, "cloud": int(current["cloudcover"]),
                  "rain": float(current["precipMM"]), "code": int(current["weatherCode"])}
        CACHE.parent.mkdir(parents=True, exist_ok=True)
        CACHE.write_text(json.dumps(cached))
    except (OSError, ValueError, KeyError, IndexError, TypeError):
        if now - cached.get("checked", 0) > 10800:
            return {}
    return cached


def weather_mode(reading: dict) -> str:
    code = reading.get("code", 0)
    if reading.get("rain", 0) > 0 or code in (*range(51, 68), *range(80, 83), *range(95, 100)):
        return "rain"
    return "cloud" if reading.get("cloud", 0) >= 55 else "stars"


def moon_art(fraction: float, background: str, frame: int) -> str:
    lit = 1 - abs(2 * fraction - 1)

    def shade(width: int) -> str:
        threshold = width * (1 - lit)
        cells = []
        for index in range(width):
            bright = index >= threshold if fraction < 0.5 else index < width - threshold
            cells.append("#" if bright else ".")
        return "".join(cells)

    moon = ("  .---.  ", f" /{shade(5)}\\ ", f"|{shade(7)}|",
            f" \\{shade(5)}/ ", "  '---'  ")
    stars = (("* .", " + "), (" .+", "*  "), ("+ *", " . "), ("  .", "+ *"))
    rows = []
    for index, disk in enumerate(moon):
        left, right = stars[(frame + index) % len(stars)]
        if background == "rain":
            left = ("| *", "' +", "* |", "+ '")[(frame + index) % 4]
            right = ("+ |", "* '", "| +", "' *")[(frame + index + 1) % 4]
        elif background == "cloud":
            left = ("~ *", "* ~", "_ +", "+ _")[(frame + index) % 4]
            right = ("+ ~", "~ +", "* _", "_ *")[(frame + index + 2) % 4]
        rows.append(f"{left}{disk}{right}")
    return "\n".join(rows)


def moon_output(now: datetime, reading: dict, frame: int) -> dict:
    name, fraction = phase(now)
    background = weather_mode(reading)
    tooltip = (f"{LOCATION}\n{now.strftime('%A')}  {roman(now.day)} / {roman(now.month)} / {roman(now.year)}"
        f"\n{roman(now.hour)}:{roman(now.minute)}\n{name}")
    if reading:
        tooltip += f"\nWeather: {background}"
    else:
        tooltip += "\nWeather unavailable; showing stars"
    return {"text": moon_art(fraction, background, frame), "tooltip": tooltip,
            "class": background}


def show_moon(now: datetime, reading: dict) -> None:
    details = moon_output(now, reading, 0)["tooltip"]
    name, _ = phase(now)
    subprocess.run(["notify-send", "-a", "ArchMerOS", "-t", "8000",
                    name, details], check=False)


def whisper(now: datetime) -> dict:
    try:
        state = json.loads(STATE.read_text())
        if time.monotonic() - state["monotonic"] > 8:
            state = {}
    except (OSError, ValueError, KeyError, TypeError):
        state = {}
    services = {item["key"]: item["state"] for item in state.get("services", [])}
    if state.get("network") == "none":
        line = "the signal is buried"
    elif state.get("ci_failed"):
        line = "the forge remembers"
    elif state.get("agent_flash"):
        line = "a worker returns"
    elif "offline" in state.get("oracle_detail", "").lower():
        line = "oracle sleeps"
    elif services.get("herdr") == "busy":
        line = "the forge is awake"
    elif state.get("ai_active"):
        line = "another voice crosses mine"
    elif services.get("repo") == "dirty":
        line = "the ink has not dried"
    else:
        daily = ("the quiet has a pulse", "the circuits keep their vows",
                 "a small light endures", "the stars need no witness")
        line = daily[now.date().toordinal() % len(daily)]
    wrapped = "\n".join(textwrap.wrap(line, width=18, break_long_words=False))
    return {"text": f'"{wrapped}"', "tooltip": "Daemon Master whisper: local, event-driven or daily; no AI call"}


def main() -> None:
    if len(sys.argv) > 1 and sys.argv[1] == "whisper":
        print(json.dumps(whisper(datetime.now().astimezone())))
    elif len(sys.argv) > 1 and sys.argv[1] == "moon":
        now = datetime.now().astimezone()
        print(json.dumps(moon_output(now, weather(time.time()), int(time.monotonic())), ensure_ascii=False))
    elif len(sys.argv) > 1 and sys.argv[1] == "show":
        show_moon(datetime.now().astimezone(), weather(time.time()))
    elif len(sys.argv) > 1 and sys.argv[1] == "stream":
        reading = weather(time.time())
        checked = time.monotonic()
        frame = 0
        try:
            while True:
                now = time.monotonic()
                if now - checked >= 60:
                    reading = weather(time.time())
                    checked = now
                print(json.dumps(moon_output(datetime.now().astimezone(), reading, frame),
                                 ensure_ascii=False), flush=True)
                frame += 1
                time.sleep(1)
        except BrokenPipeError:
            return
    else:
        print("Usage: archmeros-beacon-moon.py [moon|whisper|stream|show]", file=sys.stderr)
        raise SystemExit(2)


if __name__ == "__main__":
    main()
