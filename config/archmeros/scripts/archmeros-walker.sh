#!/usr/bin/env bash

set -euo pipefail

systemctl --user start archmeros-elephant.service archmeros-walker.service >/dev/null 2>&1 || true
sleep 0.2

exec walker
