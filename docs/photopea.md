# Photopea

Photopea launches as a Chromium web app with a separate persistent profile.
On 2026-11-02 its GPU process was present in nvidia-smi on the GTX 1060.
This confirms browser GPU activity, not acceleration of every editor operation.

In the Lua session, `photopea_input.lua` disables only the six compositor
Shift/Alt/Super mouse drag and resize bindings when the focused Photopea window
is fullscreen. Native input then reaches the editor. Focus or fullscreen changes
restore the bindings automatically; keyboard shortcuts and other apps are unchanged.
The existing deployment links install this module with the Hyprland directory.

Test: `lua tests/test_photopea_input.lua`.

## USB Reset Incident

At 15:33:47 on 2026-11-02 the kernel reported USB transaction errors (-71),
multiple over-current conditions, and hub disconnects. The shared USB 2-4 hub
contains the Steinberg UR44, Turzx UsbMonitor, mouse, and Bluetooth adapter.
Their simultaneous loss can interrupt sound and reset the telemetry display.
No NVIDIA Xid or GPU-reset error was found in that boot's kernel log.
Photopea's Chromium log also contains a Vulkan/Wayland compatibility warning;
that is separate evidence, not proof that it caused the USB failure.

Save editor documents before tests. Isolate the hub/cable/devices by using
direct motherboard keyboard/mouse connections and disconnecting the suspect hub.
Do not disable over-current protection or repeatedly reproduce electrical faults.
Repeated reports on multiple root ports warrant checking the motherboard USB
controller and power path as well as the hub. A fault report does not alone
identify which component is defective. No driver or USB power settings were changed.
