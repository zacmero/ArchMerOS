# Mouse Drop Tiling

Super+left drag tiles on cross-monitor release. Alt/Shift+left drag stays free.
The release watcher discovers relative-pointer event devices by capability,
rescans every two seconds, and reconnects after USB/hub changes. It must never
depend on a particular mouse vendor or device path. An explicit
`ARCHMEROS_DROP_TILE_MOUSE` override remains supported.

The previous hard-coded USB path and vendor-specific udev permission caused
the watcher to crash after replacing the mouse. Missing mouse devices now leave
the watcher running, waiting for reconnect, rather than exhausting systemd's
restart limit. Its input access remains restricted to mouse interfaces.

Apply the system permission rule after install or upgrade:

```bash
rtk sudo bash install/system/apply-drop-tile-system.sh
```

The helper backs up the previous rule and reloads it for connected devices.
The watcher retries opening readable devices without needing a restart.

Verify Super cross-monitor drag tiles only after release, Alt drag remains
floating, same-monitor drags do not tile, and mouse reconnect restores behavior.
