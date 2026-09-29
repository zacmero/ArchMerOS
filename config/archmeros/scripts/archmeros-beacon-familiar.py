#!/usr/bin/env python3
"""Read-only Beacon state sampler, ranked sigils, and animated familiar."""

from __future__ import annotations

import json
import os
import runpy
import subprocess
import sys
import time
from pathlib import Path


RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")) / "archmeros"
STATE_FILE = RUNTIME / "beacon-familiar.json"
AUDIO_FILE = RUNTIME / "beacon-audio.json"
ACTIVITY = runpy.run_path(str(Path(__file__).with_name("archmeros-dp1-activity.py")))
TICKS_PER_SECOND = os.sysconf("SC_CLK_TCK")
ORDER = ("herdr", "oracle", "syncthing", "pipewire", "ssh", "ai", "repo")
GLYPHS = {"herdr": "⛧", "oracle": "◈", "syncthing": "⌁", "pipewire": "∴", "ssh": "⋈", "ai": "λ", "repo": "⟁"}
LABELS = {"herdr": "Herdr", "oracle": "Oracle A1", "syncthing": "Syncthing", "pipewire": "PipeWire", "ssh": "SSH", "ai": "AI HUB", "repo": "focused Git repo"}


def command(args: list[str], timeout: float = 0.7) -> str | None:
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=timeout, check=False)
        return result.stdout.strip() if result.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired):
        return None


def process_snapshot() -> tuple[dict[str, int], dict[str, int], bool]:
    ticks = {key: 0 for key in ("herdr", "syncthing", "pipewire", "ssh")}
    counts = {key: 0 for key in ticks}
    herdr_client = False
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            name = (entry / "comm").read_text().strip()
            if name not in {"herdr", "syncthing", "pipewire", "pipewire-pulse", "ssh"}:
                continue
            args = (entry / "cmdline").read_bytes().split(b"\0")
            stat = (entry / "stat").read_text().rsplit(") ", 1)[1].split()
            cpu_ticks = int(stat[11]) + int(stat[12])
        except (OSError, ValueError, IndexError):
            continue
        key = "pipewire" if name.startswith("pipewire") else name
        ticks[key] += cpu_ticks
        counts[key] += 1
        if key == "herdr" and len(args) > 1 and args[1] == b"":
            herdr_client = True
    return ticks, counts, herdr_client


def audio_peak(now: float) -> float:
    try:
        data = json.loads(AUDIO_FILE.read_text())
        return float(data["peak"]) if now - float(data["time"]) < 2.0 else 0.0
    except (OSError, ValueError, KeyError, TypeError):
        return 0.0


def active_ai_hub() -> bool:
    raw = command(["hyprctl", "-j", "clients"], timeout=0.5)
    if not raw:
        return False
    try:
        clients = json.loads(raw)
    except json.JSONDecodeError:
        return False
    return any(str(client.get("class", "")).startswith("archmeros-aichat-") and not client.get("hidden", False) for client in clients)


def focused_repo() -> tuple[bool, Path | None]:
    repo = ACTIVITY["active_repo"]()
    if repo is None:
        return False, None
    status = ACTIVITY["git"](repo, "status", "--porcelain=v1", "--untracked-files=no", timeout=0.8)
    return bool(status), repo


def recent_ci_failure(repo: Path | None) -> bool:
    if repo is None:
        return False
    runs = ACTIVITY["cached_runs"](repo)
    if not runs:
        return False
    latest = runs[0]
    created = ACTIVITY["parse_gh_time"](str(latest.get("createdAt") or ""))
    return bool(created and time.time() - created < 3600 and latest.get("conclusion") in {"failure", "timed_out"})


def new_agent_notification(seen: set[int] | None) -> tuple[set[int], bool]:
    raw = command(["makoctl", "list", "-j"], timeout=0.5)
    if not raw:
        return seen or set(), False
    try:
        notes = json.loads(raw)
    except json.JSONDecodeError:
        return seen or set(), False
    current = {int(note["id"]): note for note in notes if isinstance(note, dict) and "id" in note}
    if seen is None:
        return set(current), False
    finished = any(
        any(word in str(note.get("summary", "")).lower() for word in ("finished", "completed", "done"))
        and any(word in (str(note.get("summary", "")) + " " + str(note.get("app_name", ""))).lower()
                for word in ("agent", "codex", "antigravity", "herdr"))
        for ident, note in current.items() if ident not in seen
    )
    return set(current), finished


def service(key: str, state: str, cpu: float = 0.0, count: int = 0, bonus: float = 0.0) -> dict:
    failed = state in {"offline", "failed"}
    score = 0.0 if state in {"stopped", "idle", "unknown"} else 1.0 + min(5.0, cpu / 3.0) + min(2, count) * 0.35 + bonus
    return {"key": key, "glyph": GLYPHS[key], "label": LABELS[key], "state": state,
            "cpu": round(cpu, 1), "count": count, "score": round(score, 2), "failed": failed}


def rank(services: list[dict]) -> list[dict]:
    return sorted(services, key=lambda item: (item["failed"], -item["score"], ORDER.index(item["key"])))


def sample(previous: dict | None, cached: dict, now: float) -> tuple[dict, dict]:
    ticks, counts, herdr_client = process_snapshot()
    interval = max(0.1, now - previous["monotonic"]) if previous else 1.0
    cpu = {key: max(0.0, (value - previous["ticks"].get(key, value)) / TICKS_PER_SECOND / interval * 100.0)
           for key, value in ticks.items()} if previous else {key: 0.0 for key in ticks}
    if now - cached.get("slow_checked", 0) >= 5:
        cached["network"] = command(["nmcli", "-t", "-f", "CONNECTIVITY", "general"]) or "unknown"
        cached["oracle"], cached["oracle_detail"] = ACTIVITY["tailscale_peer"]()
        cached["ai"] = active_ai_hub()
        cached["slow_checked"] = now
    if now - cached.get("repo_checked", 0) >= 15:
        cached["dirty"], cached["repo"] = focused_repo()
        cached["ci_failed"] = recent_ci_failure(cached["repo"])
        cached["repo_checked"] = now
    if now - cached.get("note_checked", 0) >= 1:
        cached["seen_notifications"], finished = new_agent_notification(cached.get("seen_notifications"))
        if finished:
            cached["flash_until"] = now + 1.5
        cached["note_checked"] = now
    peak = audio_peak(now)
    oracle = cached.get("oracle", "unknown")
    services = [
        service("herdr", "busy" if herdr_client and cpu["herdr"] >= 2 else "running" if herdr_client else "stopped", cpu["herdr"], counts["herdr"], 1.5 if herdr_client else 0),
        service("oracle", "online" if oracle == "online" else "offline" if oracle == "offline" else "unknown"),
        service("syncthing", "busy" if counts["syncthing"] and cpu["syncthing"] >= 2 else "running" if counts["syncthing"] else "stopped", cpu["syncthing"], counts["syncthing"]),
        service("pipewire", "active" if peak >= 0.03 else "running" if counts["pipewire"] else "stopped", cpu["pipewire"], counts["pipewire"], min(2.0, peak * 3)),
        service("ssh", "active" if counts["ssh"] else "idle", cpu["ssh"], counts["ssh"]),
        service("ai", "active" if cached.get("ai") else "idle", bonus=2.0 if cached.get("ai") else 0.0),
        service("repo", "dirty" if cached.get("dirty") else "idle", bonus=1.0 if cached.get("dirty") else 0.0),
    ]
    state = {"monotonic": now, "wall_time": time.time(), "ticks": ticks, "services": rank(services),
             "network": cached.get("network", "unknown"), "oracle_detail": cached.get("oracle_detail", "unavailable"),
             "repo": str(cached["repo"]) if cached.get("repo") else None, "audio_peak": round(peak, 3),
             "ai_active": bool(cached.get("ai")), "ci_failed": bool(cached.get("ci_failed")),
             "agent_flash": now < cached.get("flash_until", 0)}
    return state, cached


def save_state(state: dict) -> None:
    try:
        RUNTIME.mkdir(mode=0o700, parents=True, exist_ok=True)
        temporary = STATE_FILE.with_name(f"{STATE_FILE.name}.{os.getpid()}")
        temporary.write_text(json.dumps(state))
        os.replace(temporary, STATE_FILE)
    except OSError:
        pass


def read_state() -> dict:
    try:
        state = json.loads(STATE_FILE.read_text())
        if time.monotonic() - state["monotonic"] < 4:
            return state
    except (OSError, ValueError, KeyError, TypeError):
        pass
    state, _ = sample(None, {}, time.monotonic())
    return state


def status_lines(state: dict) -> list[str]:
    lines = []
    for item in state["services"]:
        detail = f"{item['cpu']:.1f}% of one CPU" if item["key"] in {"herdr", "syncthing", "pipewire", "ssh"} else item["state"]
        lines.append(f"{item['glyph']} {item['label']}: {item['state']}, {detail}, score {item['score']:.1f}")
    return lines


def sigils(state: dict) -> dict:
    rows = []
    palette = {"herdr": "#d0a4eb", "oracle": "#8cbfe5", "syncthing": "#79cbb9",
               "pipewire": "#e5c590", "ssh": "#aab9d9", "ai": "#e9a1c6", "repo": "#b7d49a"}
    visible = state["services"][:5]
    failed = next((item for item in state["services"] if item["failed"]), None)
    if failed and failed not in visible:
        visible[-1] = failed
    for item in visible:
        trend = "▼" if item["failed"] else "▲▲" if item["score"] >= 4 else "▲" if item["score"] >= 2 else "·"
        color = "#ff6688" if item["failed"] else palette.get(item["key"], "#d9dbe8")
        rows.append(f'<span foreground="{color}">{item["glyph"]}  {trend}</span>')
    tooltip = "ACTIVITY HIERARCHY\n" + "\n".join(status_lines(state))
    tooltip += "\n\nCPU delta, process count, current state. Not scheduler priority or Herdr agent count."
    return {"text": "\n".join(rows), "tooltip": tooltip, "class": "ranked"}


def mode(state: dict) -> str:
    if state["network"] == "none":
        return "offline"
    if state["ci_failed"]:
        return "failure"
    if state["agent_flash"]:
        return "flash"
    if state["ai_active"]:
        return "awake"
    if any(item["key"] == "herdr" and item["state"] == "busy" for item in state["services"]):
        return "working"
    return "music" if state["audio_peak"] >= 0.03 else "idle"


def art(state: dict, now: float) -> dict:
    active_mode = mode(state)
    phase = int(now * (1 if active_mode == "idle" else 4)) % 4
    core = state["services"][0]["glyph"] if state["services"][0]["score"] > 0 else "⟡"
    if active_mode == "offline":
        rows = ("       ╱╲       ", "      ◇  ◇      ", "       ╲╱       ", "       │        ", "       ⌁        ")
    elif active_mode == "failure":
        rows = ("       ×        ", "    ╱     ╲     ", f"  ×    {core}    ×   ", "    ╲     ╱     ", "       ×        ")
    elif active_mode == "flash":
        rows = ("   ✦   ◈   ✦    ", "    ╲  │  ╱     ", f"  ◈ ─  {core}  ─ ◈   ", "    ╱  │  ╲     ", "   ✦   ◈   ✦    ")
    elif active_mode == "working":
        rows = ("       ◈        ", "     ╱ │ ╲      ", f"  ◇ ─  {core}  ─ ◇   ", "     ╲ │ ╱      ", "       ◈        ") if phase % 2 else ("    ◈     ◈     ", "      ╲│╱       ", f"  ◇ ─  {core}  ─ ◇   ", "      ╱│╲       ", "    ◈     ◈     ")
    elif active_mode == "awake":
        rows = ("  ╱╲       ╱╲   ", " ◈  ╲     ╱  ◈  ", f"     ╲  {core}  ╱    ", "     ╱  ⛧  ╲    ", " ◈  ╱     ╲  ◈  ", "  ╲╱       ╲╱   ") if phase % 2 else (" ╱  ╲     ╱  ╲  ", "◈    ╲   ╱    ◈ ", f"      ╲{core}╱      ", "      ╱⛧╲      ", "◈    ╱   ╲    ◈ ", " ╲  ╱     ╲  ╱  ")
    else:
        eye = "◈" if phase in {1, 2} else "◇"
        wing = "╱ ╲" if phase in {1, 2} else "╱╲"
        rows = (f"   {wing}     {wing}   ", f"  {eye}  ╲   ╱  {eye}  ", f"   ╲   {core}   ╱   ", "   ╱   │   ╲   ", f"  {eye}  ╱   ╲  {eye}  ", f"   ╲╱     ╲╱   ")
    tooltip = f"DAEMON MASTER · {active_mode.upper()}\n" + "\n".join(status_lines(state)[:5])
    tooltip += f"\nNetwork: {state['network']} · Audio: {state['audio_peak']:.0%} · CI failure: {'yes' if state['ci_failed'] else 'no'}"
    tooltip += "\nClick for a read-only AI HUB status conversation."
    return {"text": "\n".join(rows), "class": active_mode, "tooltip": tooltip}


def context(state: dict) -> str:
    lines = ["Source: daemon", "Label: daemon-master", "Role: You are Daemon Master, the AI daemon persona representing ArchMerOS as a whole. Speak as the system, grounded in this read-only snapshot.",
             "Voice: concise, cryptic, precise. Use a distinct personality, but never invent sensors, feelings, access, completed actions, or unseen system state.",
             "Do not run commands or claim restoration. Distinguish observed state from inference. Ask before any future action.",
             f"Snapshot age: {max(0, int(time.time() - state['wall_time']))} seconds", f"NetworkManager connectivity: {state['network']}",
             f"Oracle A1 Tailscale peer: {state['oracle_detail']}", f"Audio peak: {state['audio_peak']:.0%}",
             f"AI HUB window open: {state['ai_active']}", f"Focused Git repo: {state['repo'] or 'none'}",
             f"Recent focused-repo CI failure: {state['ci_failed']}",
             "Herdr agent counts and remote VM jobs are not available from this snapshot.", "Activity ranking:", *status_lines(state)]
    return "\n".join(lines) + "\n"


def stream() -> None:
    previous = None
    cached = {}
    last_sample = 0.0
    last_frame = None
    while True:
        now = time.monotonic()
        if now - last_sample >= 1:
            previous, cached = sample(previous, cached, now)
            save_state(previous)
            last_sample = now
        frame = art(previous, now)
        if frame != last_frame:
            try:
                print(json.dumps(frame, ensure_ascii=False), flush=True)
            except BrokenPipeError:
                return
            last_frame = frame
        time.sleep(0.25)


def main() -> int:
    action = sys.argv[1] if len(sys.argv) > 1 else "sigils"
    if action == "stream":
        stream()
    elif action == "sigils":
        print(json.dumps(sigils(read_state()), ensure_ascii=False))
    elif action == "context":
        print(context(read_state()), end="")
    elif action == "frame":
        print(json.dumps(art(read_state(), time.monotonic()), ensure_ascii=False))
    else:
        print("Usage: archmeros-beacon-familiar.py [stream|sigils|context|frame]", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
