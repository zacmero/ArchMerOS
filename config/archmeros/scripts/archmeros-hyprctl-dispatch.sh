#!/usr/bin/env bash

set -euo pipefail

lua_string() {
  local value="${1-}"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf '"%s"' "$value"
}

lua_dispatch() {
  hyprctl eval "hl.dispatch($1)" >/dev/null
}

main() {
  local dispatch_name="${1:-}"
  [[ -n "$dispatch_name" ]] || return 0
  shift
  local -a args=("$@")

  if ! hyprctl systeminfo 2>/dev/null | grep -q 'configProvider: lua'; then
    exec hyprctl dispatch "$dispatch_name" "${args[@]}"
  fi

  local arg target selector mode mode_name fields workspace monitor
  local width height internal client action mods key filter command

  case "$dispatch_name" in
    killactive)
      lua_dispatch 'hl.dsp.window.close()'
      ;;
    closewindow)
      target="${args[0]:-}"
      if [[ -n "$target" ]]; then
        lua_dispatch "hl.dsp.window.close({ window = $(lua_string "$target") })"
      else
        lua_dispatch 'hl.dsp.window.close()'
      fi
      ;;
    togglefloating)
      lua_dispatch 'hl.dsp.window.float({ action = "toggle" })'
      ;;
    settiled)
      lua_dispatch 'hl.dsp.window.float({ action = "disable" })'
      ;;
    fullscreen)
      arg="${args[0]:-0}"
      mode="${arg%%,*}"
      selector=""
      [[ "$arg" != *,* ]] || selector="${arg#*,}"
      case "$mode" in
        1|maximized) mode_name="maximized" ;;
        *) mode_name="fullscreen" ;;
      esac
      fields="mode = $(lua_string "$mode_name")"
      [[ -z "$selector" ]] || fields+=", window = $(lua_string "$selector")"
      lua_dispatch "hl.dsp.window.fullscreen({ $fields })"
      ;;
    fullscreenstate)
      internal="${args[0]:-0}"
      client="${args[1]:-0}"
      lua_dispatch "hl.dsp.window.fullscreen_state({ internal = $internal, client = $client })"
      ;;
    movewindow)
      arg="${args[0]:-}"
      if [[ "$arg" == mon:* ]]; then
        monitor="${arg#mon:}"
        lua_dispatch "hl.dsp.window.move({ monitor = $(lua_string "$monitor") })"
      else
        lua_dispatch "hl.dsp.window.move({ direction = $(lua_string "$arg") })"
      fi
      ;;
    moveactive)
      width="${args[0]:-0}"
      height="${args[1]:-0}"
      lua_dispatch "hl.dsp.window.move({ x = $width, y = $height, relative = true })"
      ;;
    swapwindow)
      arg="${args[0]:-}"
      case "$arg" in
        l) arg="left" ;;
        r) arg="right" ;;
        u) arg="up" ;;
        d) arg="down" ;;
      esac
      lua_dispatch "hl.dsp.window.swap({ direction = $(lua_string "$arg") })"
      ;;
    movetoworkspace)
      workspace="${args[0]:-1}"
      lua_dispatch "hl.dsp.window.move({ workspace = $(lua_string "$workspace"), follow = true })"
      ;;
    movetoworkspacesilent)
      target="${args[0]:-1}"
      selector=""
      workspace="$target"
      if [[ "$target" == *,address:* ]]; then
        workspace="${target%%,*}"
        selector="${target#*,}"
      fi
      fields="workspace = $(lua_string "$workspace"), follow = false"
      [[ -z "$selector" ]] || fields+=", window = $(lua_string "$selector")"
      lua_dispatch "hl.dsp.window.move({ $fields })"
      ;;
    moveworkspacetomonitor)
      workspace="${args[0]:-1}"
      monitor="${args[1]:-}"
      lua_dispatch "hl.dsp.workspace.move({ workspace = $(lua_string "$workspace"), monitor = $(lua_string "$monitor") })"
      ;;
    workspace)
      workspace="${args[0]:-1}"
      lua_dispatch "hl.dsp.focus({ workspace = $(lua_string "$workspace") })"
      ;;
    focuswindow)
      target="${args[0]:-}"
      lua_dispatch "hl.dsp.focus({ window = $(lua_string "$target") })"
      ;;
    focusmonitor)
      monitor="${args[0]:-}"
      lua_dispatch "hl.dsp.focus({ monitor = $(lua_string "$monitor") })"
      ;;
    focuscurrentorlast)
      lua_dispatch 'hl.dsp.focus({ last = true })'
      ;;
    pin)
      lua_dispatch 'hl.dsp.window.pin()'
      ;;
    bringactivetotop)
      lua_dispatch 'hl.dsp.window.bring_to_top()'
      ;;
    alterzorder)
      action="${args[0]:-top}"
      lua_dispatch "hl.dsp.window.alter_zorder({ mode = $(lua_string "$action") })"
      ;;
    resizeactive)
      if [[ "${args[0]:-}" == "exact" ]]; then
        width="${args[1]:-0}"
        height="${args[2]:-0}"
        lua_dispatch "hl.dsp.window.resize({ x = $width, y = $height, relative = false })"
      else
        width="${args[0]:-0}"
        height="${args[1]:-0}"
        lua_dispatch "hl.dsp.window.resize({ x = $width, y = $height, relative = true })"
      fi
      ;;
    centerwindow)
      lua_dispatch 'hl.dsp.window.center()'
      ;;
    sendshortcut)
      IFS=',' read -r mods key filter <<< "${args[0]:-}"
      fields="mods = $(lua_string "$mods"), key = $(lua_string "$key")"
      [[ -z "$filter" ]] || fields+=", window = $(lua_string "$filter")"
      lua_dispatch "hl.dsp.send_shortcut({ $fields })"
      ;;
    dpms)
      case "${args[0]:-on}" in
        on|enable) action="enable" ;;
        off|disable) action="disable" ;;
        *) action="toggle" ;;
      esac
      monitor="${args[1]:-}"
      fields="action = $(lua_string "$action")"
      [[ -z "$monitor" ]] || fields+=", monitor = $(lua_string "$monitor")"
      lua_dispatch "hl.dsp.dpms({ $fields })"
      ;;
    exec)
      command="${args[*]}"
      lua_dispatch "hl.dsp.exec_cmd($(lua_string "$command"))"
      ;;
    exit)
      lua_dispatch 'hl.dsp.exit()'
      ;;
    *)
      printf 'Unsupported Lua dispatcher: %s\n' "$dispatch_name" >&2
      return 2
      ;;
  esac
}

main "$@"
