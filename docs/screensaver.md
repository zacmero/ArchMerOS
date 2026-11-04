# Wallpaper Screensaver

Emergency exit: **Super+Escape** stops the screensaver and restores all outputs,
the side black cover, telemetry service, and bars. It bypasses the short startup
guard, so it also works immediately after activation. It is independent of USB
keyboard model. Slideshow mpv uses `--stop-screensaver=no` so the screensaver
does not itself inhibit the idle monitor responsible for wake-on-activity.

The Waybar manager serializes all lifecycle operations with a runtime lock.
Screensaver cleanup and idle-resume callbacks can both request restoration;
their requests must not interleave and spawn duplicate Beacon widgets or
overwrite the visibility state concurrently. Bar processes do not inherit
the manager lock. Concurrent-start testing must leave exactly one Beacon.

The slideshow uses mpv to display static wallpaper images on HDMI-A-1.
DP-2 and DP-1 (Bravia) receive DPMS off while it runs; DP-3 retains its
existing black-cover behavior. Resume restores the outputs. The separate
Foston display and cinema bindings are unchanged.

The static slideshow explicitly uses `vo=gpu` with the Wayland context,
bilinear scaling, no debanding or interpolation, and audio timing rather
than display-resampling. This avoids the default gpu-next renderer for a
simple image slideshow. Image duration and randomized playlist are unchanged.
No continuous animation, conversion daemon, or extra background worker is added.

A short live static-image sample on this machine measured mpv at 0.6% of one
CPU core with the previous default renderer and 0.0% with the lightweight
settings, rounded over five seconds after startup. Both launched without errors.
This measures steady image display only, not decode spikes on image changes,
GPU utilization, or total compositor/system consumption.

DP-1 was live-tested off and restored. These settings are repository-managed
under `config/archmeros/scripts`, deployed by the normal configuration links.
