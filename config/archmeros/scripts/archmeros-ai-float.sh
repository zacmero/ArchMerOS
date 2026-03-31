#!/usr/bin/env bash

set -euo pipefail

mode="${1:-aichat}"
shift || true

wezterm_cmd="/usr/bin/wezterm"
launch_wrapper="$HOME/.config/archmeros/scripts/archmeros-launch-detached.sh"
context_helper="$HOME/.config/archmeros/scripts/archmeros-ai-context.sh"
fabric_browser="$HOME/.config/archmeros/scripts/archmeros-fabric-browser.sh"
runner="$HOME/.config/archmeros/scripts/archmeros-aichat-runner.sh"
session_browser="$HOME/.config/archmeros/scripts/archmeros-aichat-sessions.sh"
archmeros_env="$HOME/.config/archmeros/ai/aichat.env"

launch_wezterm() {
  exec "$launch_wrapper" "$wezterm_cmd" start --always-new-process --class "$@"
}

case "$mode" in
  aichat)
    launch_class="archmeros-aichat-float"
    context_file=""
    if [[ -x "$context_helper" ]]; then
      context_file="$("$context_helper" 2>/dev/null || true)"
    fi

    ARCHMEROS_FORCE_POP_MODE=medium launch_wezterm "$launch_class" --cwd "$HOME" -- bash "$runner" "$context_file" "$archmeros_env"
    ;;
  fabric)
    launch_class="archmeros-fabric-browser"
    launch_wezterm "$launch_class" --cwd "$HOME" -- bash "$fabric_browser" "$@"
    ;;
  sessions)
    launch_class="archmeros-aichat-sessions"
    launch_wezterm "$launch_class" --cwd "$HOME" -- bash "$session_browser"
    ;;
  *)
    printf 'Usage: %s [aichat|fabric|sessions]\n' "$0" >&2
    exit 1
    ;;
esac
