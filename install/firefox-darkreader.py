#!/usr/bin/env python3
"""Apply the repo's Dark Reader settings to a closed, existing Firefox profile."""

import argparse
import json
import os
from pathlib import Path
import shutil
import sqlite3
import tempfile


def configure(profile):
    if os.path.lexists(profile / "lock"):
        raise SystemExit("Close Firefox before applying Dark Reader settings.")

    extension_id = "addon@darkreader.org"
    extensions_path = profile / "extensions.json"
    extensions = json.loads(extensions_path.read_text())
    addon = next((a for a in extensions["addons"] if a["id"] == extension_id), None)
    if not addon or addon.get("appDisabled") or addon.get("pendingUninstall"):
        raise SystemExit("Install a compatible Dark Reader extension in this profile first.")

    settings_path = Path(__file__).resolve().parents[1] / "config/firefox/darkreader.json"
    desired = json.loads(settings_path.read_text())
    database = profile / "storage-sync-v2.sqlite"
    # mode=rw prevents silently creating an empty database in the wrong profile.
    with sqlite3.connect(database.as_uri() + "?mode=rw", uri=True) as connection:
        row = connection.execute(
            "SELECT data FROM storage_sync_data WHERE ext_id = ?", (extension_id,)
        ).fetchone()
        if not row or not row[0]:
            raise SystemExit("Open Dark Reader with settings sync enabled once, then close Firefox.")
        settings = json.loads(row[0])
        if settings.get("syncSettings") is not True:
            raise SystemExit("Enable Dark Reader settings sync before using this helper.")
        settings.update(desired)
        if settings == json.loads(row[0]) and not addon.get("userDisabled"):
            print("Dark Reader already restricted to Mercado Livre.")
            return

        backup = Path(tempfile.mkdtemp(prefix="archmeros-darkreader-backup-", dir=profile))
        shutil.copy2(extensions_path, backup / extensions_path.name)
        with sqlite3.connect(backup / database.name) as destination:
            connection.backup(destination)
        startup = profile / "addonStartup.json.lz4"
        if startup.exists():
            shutil.copy2(startup, backup / startup.name)

        connection.execute(
            "UPDATE storage_sync_data SET data = ?, "
            "sync_change_counter = sync_change_counter + 1 WHERE ext_id = ?",
            (json.dumps(settings, separators=(",", ":")), extension_id),
        )
        connection.commit()

    # Rebuild Firefox's startup cache so the installed, signed addon is enabled.
    addon["userDisabled"] = False
    addon["active"] = True
    temporary = extensions_path.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(extensions, separators=(",", ":")))
    temporary.replace(extensions_path)
    startup.unlink(missing_ok=True)
    print(f"Dark Reader enabled only for Mercado Livre. Backup: {backup}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("profile", type=Path, help="Firefox profile directory (see about:profiles)")
    args = parser.parse_args()
    configure(args.profile.expanduser().resolve())
