#!/usr/bin/env python3
"""Give only Photopea a hosts view without system ad-block sinkholes."""

import ipaddress
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime


def configure_download_prompt(profile):
    profile = Path(profile)
    lock = profile / "SingletonLock"
    if lock.is_symlink():
        try:
            host, pid = os.readlink(lock).rsplit("-", 1)
            if host != os.uname().nodename:
                return False
            os.kill(int(pid), 0)
            return False
        except ProcessLookupError:
            pass
        except (OSError, ValueError):
            return False
    preferences = profile / "Default" / "Preferences"
    data = json.loads(preferences.read_text()) if preferences.exists() else {}
    downloads = data.setdefault("download", {})
    if downloads.get("prompt_for_download") is True:
        return True
    if preferences.exists():
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
        shutil.copy2(preferences, preferences.with_name("Preferences.before-save-prompt-" + stamp))
    downloads["prompt_for_download"] = True
    preferences.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=preferences.parent, delete=False) as temporary:
        json.dump(data, temporary)
        temporary_name = temporary.name
    os.replace(temporary_name, preferences)
    return True


def photopea_hosts(text):
    kept = []
    for line in text.splitlines():
        fields = line.split("#", 1)[0].split()
        if len(fields) >= 2:
            try:
                address = ipaddress.ip_address(fields[0])
            except ValueError:
                kept.append(line)
                continue
            if address.is_unspecified or address.is_loopback:
                names = [name for name in fields[1:]
                         if name in {"localhost", "localhost.localdomain", "ip6-localhost", "ip6-loopback", os.uname().nodename}]
                if names:
                    kept.append(fields[0] + " " + " ".join(names))
                continue
        kept.append(line)
    return "\n".join(kept) + "\n"


def main():
    if not shutil.which("bwrap"):
        raise SystemExit("Photopea hosts exception requires bubblewrap (bwrap).")
    profile = next((arg.split("=", 1)[1] for arg in sys.argv[1:]
                    if arg.startswith("--user-data-dir=")), None)
    if profile is not None:
        configure_download_prompt(profile)
    with tempfile.TemporaryDirectory(prefix="archmeros-photopea-", dir=os.environ.get("XDG_RUNTIME_DIR")) as directory:
        hosts = Path(directory) / "hosts"
        hosts.write_text(photopea_hosts(Path("/etc/hosts").read_text()))
        # Only override this process tree's hosts file; retain Chromium's sandbox,
        # network, profile, session, and existing filesystem permissions.
        return subprocess.call(["bwrap", "--bind", "/", "/", "--dev-bind", "/dev", "/dev",
                                "--proc", "/proc", "--ro-bind",
                                str(hosts), "/etc/hosts", "--", *sys.argv[1:]])


if __name__ == "__main__":
    raise SystemExit(main())
