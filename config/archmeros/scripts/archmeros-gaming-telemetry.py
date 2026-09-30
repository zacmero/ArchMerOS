#!/usr/bin/env python3
import datetime
import json
import os
from pathlib import Path
import sys
import time

state = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "archmeros"
state.mkdir(parents=True, exist_ok=True)
log = state / "gaming-telemetry.jsonl"
ticks = os.sysconf("SC_CLK_TCK")


def processes():
    result = {}
    for path in Path("/proc").glob("[0-9]*/stat"):
        try:
            text = path.read_text()
            end = text.rindex(")")
            fields = text[end + 2:].split()
            result[(int(path.parent.name), fields[19])] = (
                text[text.index("(") + 1:end], int(fields[11]) + int(fields[12])
            )
        except (OSError, ValueError, IndexError):
            continue
    return result


previous = processes()
last = time.monotonic()
while True:
    time.sleep(5)
    now = time.monotonic()
    current = processes()
    loads = []
    for key, (name, used) in current.items():
        if key in previous:
            cpu = max(0, used - previous[key][1]) / ticks / (now - last) * 100
            loads.append({"pid": key[0], "name": name, "cpu_percent": round(cpu, 1)})
    temperatures = {}
    for path in Path("/sys/class/hwmon").glob("hwmon*/temp*_input"):
        try:
            device = (path.parent / "name").read_text().strip()
            label_path = path.with_name(path.name.replace("_input", "_label"))
            label = label_path.read_text().strip() if label_path.exists() else path.stem
            temperatures[f"{device}/{label}"] = int(path.read_text()) / 1000
        except (OSError, ValueError):
            continue
    record = {"time": datetime.datetime.now().astimezone().isoformat(),
              "temperatures_c": temperatures,
              "top_cpu": sorted(loads, key=lambda x: x["cpu_percent"], reverse=True)[:8]}
    if log.exists() and log.stat().st_size > 5_000_000:
        log.replace(log.with_suffix(".previous.jsonl"))
    with log.open("a") as file:
        file.write(json.dumps(record) + "\n")
    previous, last = current, now
    if "--once" in sys.argv:
        print(json.dumps(record))
        break
