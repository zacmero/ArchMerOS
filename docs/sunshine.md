# Sunshine Streaming

Run `start-sunshine` on the host before connecting from Moonlight.
The command starts the existing `mero-sunshine.service` user service without
enabling autostart. Running it again does not create another server.

Autostart is disabled on this machine. Moonlight cannot directly start a
stopped Sunshine server. Existing pairing and streaming settings are preserved.

To stop the host server:

```bash
rtk systemctl --user stop mero-sunshine.service
```

The launcher is tracked in `config/archmeros/scripts/start-sunshine` and linked
to `~/.local/bin/start-sunshine` by `install/link.sh` on new installations.
It requires the configured `mero-sunshine.service` and Sunshine installation.
