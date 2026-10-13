# Live Wallpapers

The wallpaper picker has a **Live videos** toggle. It switches from the saved
static-image folder to `~/Pictures/LiveWallpapers`, and switching back restores
the static folder. MP4, WebM, MKV and MOV files are supported. Video thumbnails
are cached still frames, not continuously animated previews.

Choose one connected monitor and **Apply Live**. The initial test uses DP-3,
the 1366x768 screen left of the main monitor. Other outputs retain their
static wallpapers. Selecting a static image on an output disables its live
wallpaper, without touching live selections on other outputs.

The playback selector defaults to **Original (no re-encoding)**: play the original without new
encoding or a frame-rate cap, with Lanczos scaling to the output. It is still
the downloaded video's existing compression, not raw uncompressed video.
Choose **Screen-optimized (24 FPS)** for the screen-sized conversion described below. Native
60 FPS playback can cost more than the converted 24 FPS version.

Original videos are never rewritten. FFmpeg caches output-sized H.264 copies
under `~/.cache/archmeros/live-wallpapers`, at 24 FPS, without audio, with
aspect-preserving centered crop, Lanczos scaling and CRF 18. Conversion uses
two encoding threads and one filter thread, and runs outside the picker UI
thread. Cached conversions are reused until source content metadata or output
resolution changes. A new resolution requires applying the selection again.
There is no hard 20 MB cap: file size alone does not predict playback cost.

Per-output selections live in
`~/.local/state/archmeros/live-wallpapers.json`, separate from static wallpaper
state. A single lock-protected manager launches mpvpaper backgrounds, which
cannot take application focus. Hardware decoding is requested with
`hwdec=auto-safe`; NVIDIA NVDEC was confirmed on the test machine.

The manager checks monitor state every three seconds. It stops each background
process while that output is off/disconnected or the ArchMerOS screensaver
lock exists, and resumes it afterward. mpvpaper's native auto-pause/MAX mode
pauses for fullscreen/maximized applications; arbitrary collections of tiled
or floating windows are not guaranteed to be detected as fully covering the
wallpaper. A process paused this way still retains memory. Cinema controls
and ordinary window sizing/focus bindings are unchanged.

## Dependencies

`ffmpeg` is in the media package manifest; `mpvpaper` is in optional AUR
packages. On the development machine mpvpaper was built from the official
[upstream source](https://github.com/GhostNaN/mpvpaper) into `~/.local/bin`
using the already installed build dependencies, without a system upgrade.
Normal deployment uses the repository's `config/archmeros` configuration link.
Videos and caches are personal data outside Git, not repository assets.

CLI:

```bash
python3 ~/.config/archmeros/scripts/archmeros-live-wallpaper.py status
python3 ~/.config/archmeros/scripts/archmeros-live-wallpaper.py select DP-3 ~/Pictures/LiveWallpapers/example.mp4
python3 ~/.config/archmeros/scripts/archmeros-live-wallpaper.py select DP-3 ~/Pictures/LiveWallpapers/example.mp4 --original
python3 ~/.config/archmeros/scripts/archmeros-live-wallpaper.py disable DP-3
```

The original first test video was 1280x720 at 60 FPS, then replaced at the
user's request with the 1920x1080 night-city cyberpunk video. Resizing a 720p
source cannot recover missing detail. The initial low-quality CRF 25 cache
was superseded by CRF 18; old cache files are harmless and are not deleted.

Tests: `python -m unittest discover -s tests -p test_live_wallpaper.py`.

## Initial Measurements

For Midnight Drive in original 1080p/60 FPS mode on DP-3, a short live sample
measured playback at 11% of one CPU core and 639 MiB resident memory. GPU
power averaged 30.7 W with static wallpaper versus 37 W during playback;
temperature was 48 C versus 49 C. Other desktop activity remains a possible
confounder; this is not a sustained thermal or four-screen benchmark.
DP-3 standby was verified to stop playback and restore it afterward.
All six requested MoeWalls videos were downloaded and retained as originals.
