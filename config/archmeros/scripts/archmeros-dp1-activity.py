#!/usr/bin/env python3
"""Low-overhead project, CI, and execution-fabric status for the DP-1 bar."""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
from collections import defaultdict, deque
from datetime import datetime
from pathlib import Path
from typing import Any


TERMINAL_OR_EDITOR = re.compile(r"wezterm|kitty|alacritty|foot|xterm|code|codium|nvim|neovide|emacs", re.I)
HERDR_INSTALLED = shutil.which("herdr") is not None


def run(args: list[str], *, cwd: Path | None = None, timeout: float = 1.0) -> subprocess.CompletedProcess[str] | None:
    try:
        return subprocess.run(args, cwd=cwd, text=True, capture_output=True, timeout=timeout, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return None


def output(text: str, state: str, tooltip: str) -> None:
    print(json.dumps({"text": text, "class": state, "tooltip": tooltip}, ensure_ascii=False))


def process_tree(root_pid: int) -> list[tuple[int, int]]:
    children: dict[int, list[int]] = defaultdict(list)
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            raw = (entry / "stat").read_text()
            rest = raw[raw.rfind(")") + 2 :].split()
            children[int(rest[1])].append(int(entry.name))
        except (OSError, ValueError, IndexError):
            continue
    found = [(root_pid, 0)]
    pending = deque([(root_pid, 0)])
    seen = {root_pid}
    while pending and len(found) < 500:
        parent, depth = pending.popleft()
        if depth >= 7:
            continue
        for child in children.get(parent, []):
            if child in seen:
                continue
            seen.add(child)
            found.append((child, depth + 1))
            pending.append((child, depth + 1))
    return found


def active_repo() -> Path | None:
    response = run(["hyprctl", "-j", "activewindow"], timeout=0.35)
    if response is None or response.returncode != 0:
        return None
    try:
        window = json.loads(response.stdout)
        pid = int(window.get("pid") or 0)
    except (ValueError, TypeError, json.JSONDecodeError):
        return None
    if pid <= 0:
        return None

    app_class = str(window.get("class") or "")
    pids = process_tree(pid) if TERMINAL_OR_EDITOR.search(app_class) else [(pid, 0)]
    seen: set[str] = set()
    for candidate, _depth in sorted(pids, key=lambda item: item[1], reverse=True):
        try:
            path = os.readlink(f"/proc/{candidate}/cwd")
        except OSError:
            continue
        if path in seen:
            continue
        seen.add(path)
        result = run(["git", "-C", path, "rev-parse", "--show-toplevel"], timeout=0.4)
        if result and result.returncode == 0:
            root = Path(result.stdout.strip())
            if root.is_dir():
                return root
    return None


def git(repo: Path, *args: str, timeout: float = 1.0) -> str | None:
    result = run(["git", "-C", str(repo), *args], cwd=repo, timeout=timeout)
    if result is None or result.returncode != 0:
        return None
    return result.stdout.strip()


def branch_name(repo: Path) -> str:
    branch = git(repo, "branch", "--show-current") or ""
    if not branch:
        branch = git(repo, "rev-parse", "--short", "HEAD") or "detached"
    return branch


def ahead_behind(repo: Path) -> tuple[int, int] | None:
    counts = git(repo, "rev-list", "--left-right", "--count", "HEAD...@{upstream}", timeout=0.8)
    if not counts:
        return None
    try:
        ahead, behind = (int(value) for value in counts.split())
        return ahead, behind
    except (ValueError, TypeError):
        return None


def project() -> tuple[Path, str, str, str] | None:
    repo = active_repo()
    if repo is None:
        return None
    branch = branch_name(repo)
    changes = git(repo, "status", "--porcelain=v1", "--untracked-files=normal", timeout=1.5)
    if changes is None:
        state, change_count = "unknown", "status scan timed out"
    elif changes:
        state, change_count = "dirty", f"{len(changes.splitlines())} changed paths"
    else:
        state, change_count = "clean", "working tree clean"
    return repo, branch, state, change_count


def relative_age(timestamp: float) -> str:
    seconds = max(0, int(time.time() - timestamp))
    if seconds < 60:
        return "now"
    if seconds < 3600:
        return f"{seconds // 60}m"
    if seconds < 86400:
        return f"{seconds // 3600}h"
    return f"{seconds // 86400}d"


def cached_runs(repo: Path) -> list[dict[str, Any]] | None:
    cache_root = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "archmeros" / "dp1-ci"
    cache_key = hashlib.sha256(str(repo).encode()).hexdigest()[:16]
    cache_file = cache_root / f"{cache_key}.json"
    try:
        cached = json.loads(cache_file.read_text())
        if time.time() - float(cached.get("checked", 0)) < 75:
            return cached.get("runs")
    except (OSError, ValueError, TypeError, json.JSONDecodeError):
        pass

    if not shutil.which("gh"):
        return None
    result = run(
        ["gh", "run", "list", "--limit", "3", "--json", "status,conclusion,createdAt,displayTitle,name,headBranch"],
        cwd=repo,
        timeout=2.0,
    )
    runs: list[dict[str, Any]] | None = None
    if result and result.returncode == 0:
        try:
            runs = json.loads(result.stdout)
        except json.JSONDecodeError:
            runs = None
    try:
        cache_root.mkdir(parents=True, exist_ok=True)
        cache_file.write_text(json.dumps({"checked": time.time(), "runs": runs}))
    except OSError:
        pass
    return runs


def render_project() -> None:
    data = project()
    if data is None:
        output("⌁  NO REPO", "idle", "No Git repository in the focused terminal or editor")
        return
    repo, branch, state, change_count = data
    sync = ahead_behind(repo)
    sync_text = ""
    if sync:
        ahead, behind = sync
        sync_text = (f" ↑{ahead}" if ahead else "") + (f" ↓{behind}" if behind else "")
    icon = {"clean": "✓", "dirty": "●", "unknown": "◌"}[state]
    text = f"{repo.name[:18]}\n{branch[:17]} {icon}{sync_text}"
    output(text, state, f"{repo}\n{branch}\n{change_count}")


def tailscale_peer() -> tuple[str, str]:
    result = run(["tailscale", "status", "--json"], timeout=0.7) if shutil.which("tailscale") else None
    if not result or result.returncode != 0:
        return "unknown", "Tailscale status unavailable"
    try:
        status = json.loads(result.stdout)
    except json.JSONDecodeError:
        return "unknown", "Tailscale returned invalid status"
    backend = str(status.get("BackendState") or "")
    peers = status.get("Peer") or {}
    for peer in peers.values():
        addresses = peer.get("TailscaleIPs") or []
        if peer.get("HostName") == "prod-attack" or "100.98.14.36" in addresses:
            online = bool(peer.get("Online"))
            state = "online" if online else "offline"
            return state, f"prod-attack {state}"
    return "unknown", f"Tailscale {backend or 'not running'}; Oracle A1 peer not present"


def render_fabric() -> None:
    oracle_state, oracle_detail = tailscale_peer()
    if os.environ.get("HERDR_ENV") == "1":
        herdr_state = "attached"
    else:
        herdr_state = "unattached" if HERDR_INSTALLED else "not installed"
    oracle_icon = "●" if oracle_state == "online" else "○" if oracle_state == "offline" else "◇"
    herdr_icon = "●" if herdr_state == "attached" else "○"
    style = "online" if oracle_state == "online" else "partial"
    text = f"● LOCAL\n{oracle_icon} ORACLE A1\n{herdr_icon} HERDR"
    tooltip = (
        f"LOCAL · active session\nORACLE A1 · {oracle_detail}\n"
        f"HERDR · {herdr_state}; agent counts unavailable without a Herdr-attached session"
    )
    output(text, style, tooltip)


def parse_gh_time(value: str) -> float | None:
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp()
    except (ValueError, TypeError):
        return None


def render_events() -> None:
    repo = active_repo()
    if repo is None:
        output("◦  EVENT STREAM IDLE", "idle", "No active Git repository or CI event source")
        return
    runs = cached_runs(repo)
    if runs:
        run_info = runs[0]
        status = str(run_info.get("status") or "").lower()
        conclusion = str(run_info.get("conclusion") or "").lower()
        created = parse_gh_time(str(run_info.get("createdAt") or ""))
        age = relative_age(created) if created is not None else ""
        if status != "completed":
            icon, state, label = "◌", "running", status or "running"
        elif conclusion == "success":
            icon, state, label = "✓", "success", "pass"
        elif conclusion:
            icon, state, label = "×", "failure", conclusion
        else:
            icon, state, label = "◌", "running", "completed"
        title = str(run_info.get("displayTitle") or run_info.get("name") or "GitHub Actions")
        output(f"{icon} CI {label} {age}".strip(), state, f"{title}\n{repo.name} · GitHub Actions · {age}")
        return
    commit = git(repo, "log", "-1", "--format=%ct%x1f%s", timeout=0.8)
    if commit and "\x1f" in commit:
        timestamp, subject = commit.split("\x1f", 1)
        try:
            age = relative_age(float(timestamp))
        except ValueError:
            age = ""
        output(f"↗ GIT {age}".strip(), "idle", f"{subject}\n{repo.name} · {age}")
        return
    output("◦  EVENT STREAM IDLE", "idle", f"No CI run found for {repo.name}")


def main() -> int:
    commands = {"project": render_project, "fabric": render_fabric, "events": render_events}
    if len(sys.argv) != 2 or sys.argv[1] not in commands:
        print(f"Usage: {Path(sys.argv[0]).name} [project|fabric|events]", file=sys.stderr)
        return 2
    commands[sys.argv[1]]()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
