#!/usr/bin/env python3
"""Recent local project commits and GitHub activity for the DP-1 Waybar."""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import time
from datetime import datetime
from pathlib import Path


PROJECTS = Path.home() / "projects"
CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "archmeros" / "dp1-github-events.json"
REFLOG_TIME = re.compile(r" (\d{9,11}) [+-]\d{4}$")


def age(timestamp: float) -> str:
    seconds = max(0, int(time.time() - timestamp))
    if seconds < 60:
        return "now"
    if seconds < 3600:
        return f"{seconds // 60}m"
    if seconds < 86400:
        return f"{seconds // 3600}h"
    return f"{seconds // 86400}d"


def git_dir(marker: Path) -> Path | None:
    if marker.is_dir():
        return marker
    try:
        line = marker.read_text().splitlines()[0]
    except (OSError, IndexError):
        return None
    if not line.startswith("gitdir: "):
        return None
    return (marker.parent / line[8:]).resolve()


def parse_reflog(line: str, repo: str) -> dict | None:
    try:
        header, action = line.split("\t", 1)
        timestamp = float(REFLOG_TIME.search(header).group(1))
    except (ValueError, AttributeError):
        return None
    if action.startswith("update by push"):
        kind = "PUSH"
    elif action.startswith(("commit:", "commit (amend):", "merge ")):
        kind = "COMMIT"
    else:
        return None
    head = header.split(" ", 2)[1]
    return {"time": timestamp, "kind": kind, "repo": repo, "head": head,
            "detail": action.strip()}


def local_events() -> list[dict]:
    events = []
    if not PROJECTS.is_dir():
        return events
    for pattern in ("*/.git", "*/*/.git"):
        for marker in PROJECTS.glob(pattern):
            directory = git_dir(marker)
            if not directory:
                continue
            remote_logs = directory / "logs" / "refs" / "remotes"
            logs = [directory / "logs" / "HEAD"]
            if remote_logs.is_dir():
                logs.extend(path for path in remote_logs.rglob("*") if path.is_file())
            for log in logs:
                try:
                    size = log.stat().st_size
                    with log.open("rb") as stream:
                        stream.seek(max(0, size - 16384))
                        lines = stream.read().decode("utf-8", "replace").splitlines()[-40:]
                except OSError:
                    continue
                for line in lines:
                    event = parse_reflog(line, marker.parent.name)
                    if event and time.time() - event["time"] < 7 * 86400:
                        events.append(event)
    return events


def gh_json(args: list[str]) -> object | None:
    try:
        result = subprocess.run(["gh", "api", *args], capture_output=True, text=True,
                                timeout=3, check=False)
        return json.loads(result.stdout) if result.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired, json.JSONDecodeError):
        return None


def github_events() -> tuple[list[dict], bool]:
    try:
        cached = json.loads(CACHE.read_text())
    except (OSError, ValueError, TypeError):
        cached = {}
    if time.time() - cached.get("checked", 0) < 90:
        return cached.get("events", []), True
    if not shutil.which("gh"):
        return [], False
    user = gh_json(["user"])
    feed = gh_json([f"users/{user['login']}/events?per_page=30"]) if isinstance(user, dict) and user.get("login") else None
    if not isinstance(feed, list):
        return cached.get("events", []), False
    events = []
    for item in feed:
        kind = {"PushEvent": "PUSH", "PullRequestEvent": "PR", "ReleaseEvent": "RELEASE"}.get(item.get("type"))
        if not kind:
            continue
        try:
            timestamp = datetime.fromisoformat(item["created_at"].replace("Z", "+00:00")).timestamp()
        except (KeyError, ValueError):
            continue
        payload = item.get("payload") or {}
        events.append({"time": timestamp, "kind": kind, "repo": item.get("repo", {}).get("name", "?").rsplit("/", 1)[-1],
                       "head": payload.get("head", ""), "detail": payload.get("action", "push")})
    try:
        CACHE.parent.mkdir(parents=True, exist_ok=True)
        CACHE.write_text(json.dumps({"checked": time.time(), "events": events}))
    except OSError:
        pass
    return events, True


def main() -> None:
    remote, fresh = github_events()
    events = local_events() + remote
    pushed = {(event["repo"], event["head"]) for event in events if event["kind"] == "PUSH" and event["head"]}
    events = [event for event in events if event["kind"] != "COMMIT" or (event["repo"], event["head"]) not in pushed]
    events.sort(key=lambda event: event["time"], reverse=True)
    unique = {}
    for event in events:
        unique.setdefault((event["kind"], event["repo"], event["head"]), event)
    events = list(unique.values())
    if not events:
        print(json.dumps({"text": "- NO GIT EVENTS", "class": "idle", "tooltip": "Local: ~/projects Git reflogs. Remote: authenticated GitHub activity."}))
        return
    shown = events[:3]
    text = "\n".join(f"{event['kind']} {event['repo'][:11]} {age(event['time'])}" for event in shown)
    detail = "\n".join(f"{event['kind']} {event['repo']} {age(event['time'])}: {event['detail']}" for event in events[:6])
    source = "Local ~/projects reflogs; GitHub activity API" + ("" if fresh else " (remote unavailable/stale)")
    print(json.dumps({"text": text, "class": "active" if time.time() - events[0]["time"] < 600 else "idle",
                      "tooltip": f"{detail}\n\n{source}"}, ensure_ascii=False))


if __name__ == "__main__":
    main()
