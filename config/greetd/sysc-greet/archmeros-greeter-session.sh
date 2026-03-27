#!/usr/bin/env bash
set -euo pipefail

exec start-hyprland -- -c /etc/greetd/hyprland-greeter-config.conf \
  >/var/cache/sysc-greet/greeter-hyprland.log 2>&1
