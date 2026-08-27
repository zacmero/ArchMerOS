#!/usr/bin/env bash

set -euo pipefail

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
repo_root="$(cd "$(dirname "$script_path")/../../.." && pwd)"
lua_config="${repo_root}/config/hypr/hyprland.lua"
nested_launcher="${repo_root}/config/archmeros/scripts/archmeros-hyprland-nested.sh"

verify_lua() {
  Hyprland -c "$lua_config" --verify-config
}

case "${1:-verify}" in
  verify)
    verify_lua
    ;;
  test|nested)
    verify_lua
    exec "$nested_launcher"
    ;;
  apply)
    verify_lua
    printf 'No files changed. Log out and select HyprMero(Lua) for an explicit Lua session.\n'
    ;;
  revert)
    printf 'No files changed. HyprMero explicitly loads ~/.config/hypr/hyprland.conf.\n'
    ;;
  *)
    printf 'Usage: %s [verify|test|nested|apply|revert]\n' "$0" >&2
    exit 1
    ;;
esac
