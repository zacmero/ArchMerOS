#!/usr/bin/env python3
"""Resolve directional focus before dispatching, across tiled and floating windows."""

import json
import subprocess
import sys


def query(name):
    return json.loads(subprocess.check_output(["hyprctl", "-j", name], text=True))


def dispatch(fields):
    subprocess.run(["hyprctl", "eval", "hl.dispatch(hl.dsp.focus(" + fields + "))"],
                   check=True, stdout=subprocess.DEVNULL)


def nearer_monitor(source, destination, monitors, direction):
    horizontal = direction in {"left", "right"}
    axis, cross = ("x", "y") if horizontal else ("y", "x")
    dimension = "height" if horizontal else "width"
    sign = 1 if direction in {"right", "down"} else -1
    distance = sign * (destination[axis] - source[axis])
    candidates = [m for m in monitors
                  if m.get("dpmsStatus", True) and not m.get("disabled", False)
                  and 0 < sign * (m[axis] - source[axis]) < distance
                  and m[cross] < source[cross] + source[dimension] / source.get("scale", 1)
                  and source[cross] < m[cross] + m[dimension] / m.get("scale", 1)]
    return min(candidates, key=lambda m: sign * (m[axis] - source[axis]), default=None)


def select_window(before, monitors, clients, direction):
    by_id = {m["id"]: m for m in monitors
             if m.get("dpmsStatus", True) and not m.get("disabled", False)}
    source = by_id.get(before.get("monitor"))
    if not source:
        return None
    windows = [c for c in clients if c.get("monitor") in by_id
               and c.get("address") != before.get("address")
               and c.get("mapped") and not c.get("hidden")
               and c.get("acceptsInput", True)
               and (c.get("pinned") or c.get("workspace", {}).get("id") ==
                    by_id[c["monitor"]]["activeWorkspace"]["id"])]
    axis = 0 if direction in {"left", "right"} else 1
    sign = 1 if direction in {"right", "down"} else -1
    center = lambda c, a: c["at"][a] + c["size"][a] / 2
    local = [c for c in windows if c["monitor"] == source["id"]
             and sign * (center(c, axis) - center(before, axis)) > 1]
    if local:
        return min(local, key=lambda c: (
            abs(center(c, 1 - axis) - center(before, 1 - axis)),
            abs(center(c, axis) - center(before, axis))))
    coordinate = "x" if axis == 0 else "y"
    cross = "y" if axis == 0 else "x"
    dimension = "height" if axis == 0 else "width"
    destinations = [m for m in by_id.values()
                    if sign * (m[coordinate] - source[coordinate]) > 0
                    and any(c["monitor"] == m["id"] for c in windows)]
    if not destinations:
        return None
    def monitor_score(m):
        overlap = (m[cross] < source[cross] + source[dimension] / source.get("scale", 1)
                   and source[cross] < m[cross] + m[dimension] / m.get("scale", 1))
        return (not overlap, abs(m[coordinate] - source[coordinate]))
    target = min(destinations, key=monitor_score)
    return min((c for c in windows if c["monitor"] == target["id"]),
               key=lambda c: c.get("focusHistoryID", 999999))


def main():
    direction = sys.argv[1]
    if direction not in {"left", "right", "up", "down"}:
        return 1
    before = query("activewindow")
    monitors = query("monitors")
    window = select_window(before, monitors, query("clients"), direction)
    if window:
        dispatch("{window = " + json.dumps("address:" + window["address"]) + "}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
