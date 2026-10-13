#!/usr/bin/env python3
"""Per-output video backgrounds; originals remain separate from conversion cache."""

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import time

SOURCE = Path.home() / "Pictures/LiveWallpapers"
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "archmeros"
STATE = STATE_DIR / "live-wallpapers.json"
CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "archmeros/live-wallpapers"
SCRIPT = Path(__file__).resolve()
VIDEO_SUFFIXES = {".mp4", ".webm", ".mkv", ".mov"}


def read_state():
    try:
        return json.loads(STATE.read_text())
    except FileNotFoundError:
        return {}


def write_state(state):
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    temporary = STATE.with_suffix(".tmp")
    temporary.write_text(json.dumps(state, indent=2) + "\n")
    temporary.replace(STATE)


def monitors():
    return json.loads(subprocess.check_output(["hyprctl", "-j", "monitors"], text=True))


def cache_key(source, width, height):
    stat = source.stat()
    payload = f"{source.resolve()}:{stat.st_size}:{stat.st_mtime_ns}:{width}:{height}:24:crop:hq-v2"
    return hashlib.sha256(payload.encode()).hexdigest()[:24]


def prepare(source, width, height):
    if source.suffix.lower() not in VIDEO_SUFFIXES or not source.is_file():
        raise ValueError("Choose an existing MP4, WebM, MKV or MOV video")
    width, height = width // 2 * 2, height // 2 * 2
    CACHE.mkdir(parents=True, exist_ok=True)
    output = CACHE / f"{cache_key(source, width, height)}-{width}x{height}.mp4"
    with (CACHE / (output.stem + ".lock")).open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if not output.exists():
            temporary = output.with_suffix(".partial.mp4")
            try:
                subprocess.run(["ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error",
                    "-y", "-threads", "2", "-i", str(source), "-map", "0:v:0", "-an",
                    "-vf", f"fps=24,scale={width}:{height}:flags=lanczos:force_original_aspect_ratio=increase,crop={width}:{height},setsar=1",
                    "-filter_threads", "1", "-c:v", "libx264", "-preset", "veryfast",
                    "-crf", "18", "-pix_fmt", "yuv420p", "-threads", "2",
                    "-movflags", "+faststart", str(temporary)], check=True)
                temporary.replace(output)
            finally:
                temporary.unlink(missing_ok=True)
    return output


def start():
    if not STATE.exists() or not read_state():
        return
    with (STATE_DIR / "live-wallpaper.log").open("a") as log:
        subprocess.Popen([sys.executable, str(SCRIPT), "run"], stdin=subprocess.DEVNULL,
                         stdout=log, stderr=log, start_new_session=True)


def run():
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    with (STATE_DIR / "live-wallpaper.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        backend = shutil.which("mpvpaper")
        if not backend:
            raise RuntimeError("mpvpaper is not installed")
        running = {}
        stopping = False
        def stop_signal(_signum, _frame):
            nonlocal stopping
            stopping = True
        signal.signal(signal.SIGTERM, stop_signal)
        signal.signal(signal.SIGINT, stop_signal)
        def stop_process(name):
            process, _path = running.pop(name)
            if process.poll() is not None:
                return
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        try:
            while not stopping:
                selected = read_state()
                if not selected:
                    break
                try:
                    outputs = {m["name"]: m for m in monitors()}
                except (subprocess.CalledProcessError, json.JSONDecodeError):
                    time.sleep(3)
                    continue
                saver = Path("/tmp/archmeros-screensaver.pid").exists()
                wanted = {name: item["cache"] for name, item in selected.items()
                          if name in outputs and outputs[name].get("dpmsStatus", True)
                          and not outputs[name].get("disabled", False) and not saver}
                for name in list(running):
                    process, path = running[name]
                    if wanted.get(name) != path or process.poll() is not None:
                        stop_process(name)
                for name, path in wanted.items():
                    if name not in running and Path(path).is_file():
                        original = selected[name].get("original", False)
                        scalers = ("scale=lanczos dscale=lanczos correct-downscaling=yes" if original
                                   else "scale=bilinear dscale=bilinear correct-downscaling=no")
                        options = f"no-audio loop-file=inf hwdec=auto-safe vo=libmpv {scalers} interpolation=no terminal=no msg-level=all=warn"
                        process = subprocess.Popen([backend, "-p", "-a", "MAX", "-o", options, name, path],
                                                   stdin=subprocess.DEVNULL)
                        running[name] = (process, path)
                time.sleep(3)
        finally:
            for name in list(running):
                stop_process(name)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=["select", "disable", "start", "run", "status"])
    parser.add_argument("monitor", nargs="?")
    parser.add_argument("video", nargs="?", type=Path)
    parser.add_argument("--original", action="store_true", help="Play the untouched source without conversion")
    args = parser.parse_args()
    SOURCE.mkdir(parents=True, exist_ok=True)
    if args.action == "run":
        run()
    elif args.action == "start":
        start()
    elif args.action == "status":
        print(json.dumps(read_state(), indent=2))
    elif args.action == "disable":
        state = read_state()
        if args.monitor == "All monitors":
            state = {}
        else:
            state.pop(args.monitor, None)
        write_state(state)
    else:
        if not shutil.which("mpvpaper"):
            raise RuntimeError("Install mpvpaper before selecting a live wallpaper")
        output = next((m for m in monitors() if m["name"] == args.monitor), None)
        if output is None or args.video is None:
            raise ValueError("Select one connected monitor and a video")
        source = args.video.expanduser().resolve()
        if not source.is_file() or source.suffix.lower() not in VIDEO_SUFFIXES:
            raise ValueError("Choose an existing video")
        converted = source if args.original else prepare(source, output["width"], output["height"])
        state = read_state()
        state[args.monitor] = {"source": str(source), "cache": str(converted), "original": args.original}
        write_state(state)
        start()


if __name__ == "__main__":
    main()
