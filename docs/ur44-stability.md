## Hardware Fix: Steinberg UR44 Audio Stability

On Linux the Steinberg UR44 must run in **Class Compliant (CC)** mode for the kernel `snd-usb-audio` driver to treat it as a standard ALSA device. If the rear switch is left in the proprietary mode the interface relies on Yamaha Windows/macOS drivers and PipeWire playback will crackle, drop channels, or refuse to start entirely.

### Fix Procedure

1. **Hardware Toggle**
   - Flip the CC MODE switch on the back of the UR44 to **ON** so the interface presents the class compliant descriptor.
2. **Power Cycle**
   - Turn the UR44 off, wait a few seconds, and turn it back on so the host sees the new descriptor before enumerating.
3. **USB Port Selection**
   - Connect to a **USB 2.0 port (black)** instead of a USB 3.0 (blue) port. The USB 3.0 XHCI stack can introduce scheduling jitter that shows up as pops/clicks in `PipeWire`, especially on fully buffered interfaces like the UR44.
4. **Audio Server Refresh**
   - Restart PipeWire so it re-discovers the interface in CC mode:
     ```bash
     systemctl --user restart pipewire pipewire-pulse wireplumber
     ```
5. **Kernel Optimization (optional)**
   - Install `rtkit` (it is already installed on ArchMerOS) and add your user to the `rt`/`realtime` group so PipeWire can grant realtime priority to audio threads and avoid xruns.

### Result

After these steps the UR44 appears as `alsa_card.usb-Yamaha_Corporation_Steinberg_UR44-01`, and in `pavucontrol` you can safely set the **Pro Audio** profile for ultra-low latency multi-channel routing. If the device still crackles, try a different USB controller or cable before assuming the kernel cannot handle it.

Use this guide when you switch machines or reinstall the system so the UR44 stays reliable on Linux.
