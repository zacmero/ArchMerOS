#!/usr/bin/env bash

set -euo pipefail

# Native Wayland restores Firefox's normal rendering and video path.
export MOZ_ENABLE_WAYLAND=1
exec /usr/bin/firefox "$@"
