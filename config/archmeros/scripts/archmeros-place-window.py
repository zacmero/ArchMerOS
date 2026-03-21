#!/usr/bin/env python3

import json
import subprocess
import sys
import time


def clients():
    try:
        data = subprocess.check_output(["hyprctl", "-j", "clients"], text=True)
    except Exception:
        return []
    try:
        return json.loads(data)
    except Exception:
        return []


def norm(v):
    return (v or "").strip().lower()


def choose_client(app_id: str, name: str):
    target_class = f"archmeros-{app_id}"
    name_n = name.lower()
    for _ in range(60):
        for client in clients():
            klass = norm(client.get("class"))
            initial_class = norm(client.get("initialClass"))
            title = norm(client.get("title"))
            initial_title = norm(client.get("initialTitle"))
            if (
                klass == target_class
                or initial_class == target_class
                or name_n in title
                or name_n in initial_title
            ):
                return client
        time.sleep(0.12)
    return None


def dispatch(*args: str):
    subprocess.run(["hyprctl", "dispatch", *args], check=False)


def main():
    if len(sys.argv) != 4:
        sys.exit(1)

    app_id, name, workspace = sys.argv[1:4]
    client = choose_client(app_id, name)
    if not client:
        sys.exit(0)

    address = client.get("address")
    if not address:
        sys.exit(0)

    dispatch("movetoworkspacesilent", f"{workspace},address:{address}")


if __name__ == "__main__":
    main()
