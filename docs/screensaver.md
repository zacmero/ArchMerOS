# Wallpaper Screensaver

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
