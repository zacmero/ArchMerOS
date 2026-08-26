#!/usr/bin/env bash
# Launch a nested Hyprland instance using the Lua configuration for safe preview and testing.

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
REPO_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/../../.." && pwd)"
LUA_CONFIG="${REPO_ROOT}/config/hypr/hyprland.lua"

printf "\033[1;34mLaunching nested Hyprland session with Lua config:\033[0m %s\n" "${LUA_CONFIG}"
printf "\033[0;36mThis opens a safe test window inside your current desktop session.\033[0m\n"
printf "\033[0;37mClose the window or press Ctrl+C in this terminal to exit.\033[0m\n\n"

# Run nested Hyprland with Lua config
Hyprland -c "${LUA_CONFIG}"
