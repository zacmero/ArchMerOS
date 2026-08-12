#!/usr/bin/env bash

set -euo pipefail

# Native Wayland popup resizing flickers with delayed extension menu items.
export MOZ_ENABLE_WAYLAND=0
exec /usr/bin/firefox "$@"
