#!/usr/bin/env python3

from __future__ import annotations

import ipaddress
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def run(cmd: list[str]) -> str:
    return subprocess.check_output(cmd, text=True).strip()


def detect_primary_ip() -> str | None:
    try:
        route = run(["ip", "-4", "route", "get", "1.1.1.1"])
        match = re.search(r"\bsrc\s+(\d+\.\d+\.\d+\.\d+)\b", route)
        if match:
            return match.group(1)
    except Exception:
        pass
    try:
        hosts = run(["hostname", "-I"]).split()
        for host in hosts:
            if host.startswith("127."):
                continue
            ipaddress.ip_address(host)
            return host
    except Exception:
        pass
    return None


def detect_network_for_ip(ip: str) -> str | None:
    try:
        lines = run(["ip", "-4", "-o", "addr", "show", "scope", "global", "up"]).splitlines()
    except Exception:
        lines = []
    for line in lines:
        parts = line.split()
        if len(parts) < 4:
            continue
        cidr = parts[3]
        if not cidr.startswith(f"{ip}/"):
            continue
        iface = ipaddress.ip_interface(cidr)
        return f"{iface.network.network_address}/{iface.network.netmask}"
    # Fallback for restricted environments: assume a /24 LAN.
    try:
        octets = ip.split(".")
        if len(octets) == 4:
            return f"{octets[0]}.{octets[1]}.{octets[2]}.0/255.255.255.0"
    except Exception:
        pass
    return None


def merge_csv(existing: str | None, extra: str | None) -> str | None:
    values: list[str] = []
    for raw in (existing or "").split(","):
        raw = raw.strip()
        if raw and raw not in values:
            values.append(raw)
    if extra:
        for raw in extra.split(","):
            raw = raw.strip()
            if raw and raw not in values:
                values.append(raw)
    return ",".join(values) if values else None


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: archmeros-plex-preferences.py <Preferences.xml>", file=sys.stderr)
        return 1

    prefs_path = Path(sys.argv[1])
    if not prefs_path.exists():
        return 0

    primary_ip = detect_primary_ip()
    if not primary_ip:
        return 0

    lan_network = detect_network_for_ip(primary_ip)
    custom_connection = f"http://{primary_ip}:32400"

    tree = ET.parse(prefs_path)
    root = tree.getroot()

    root.set("GdmEnabled", "1")
    root.set("customConnections", merge_csv(root.get("customConnections"), custom_connection) or custom_connection)
    if lan_network:
        root.set("allowedNetworks", merge_csv(root.get("allowedNetworks"), lan_network) or lan_network)

    temp_path = prefs_path.with_suffix(".xml.tmp")
    tree.write(temp_path, encoding="utf-8", xml_declaration=True)
    os.replace(temp_path, prefs_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
