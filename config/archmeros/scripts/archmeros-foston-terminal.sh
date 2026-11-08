#!/usr/bin/env bash
# Windowless Foston terminal keyboard toggle; repository path is overridable.
set -euo pipefail
exec python3 "${MERO_FOSTON_REPO:-$HOME/projects/mero-monitor-#2}/scripts/foston_keyboard.py" toggle-terminal
