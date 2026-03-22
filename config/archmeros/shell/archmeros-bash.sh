#!/usr/bin/env bash

[[ $- == *i* ]] || return 0
[[ -n "${ARCHMEROS_BASH_HOOK_LOADED:-}" ]] && return 0
export ARCHMEROS_BASH_HOOK_LOADED=1

shopt -s extdebug

declare -gA __archmeros_gui_commands=()

__archmeros_register_gui_command() {
  local command_name="${1:-}"
  [[ -n "$command_name" ]] || return 0
  __archmeros_gui_commands["$command_name"]=1
}

__archmeros_seed_gui_commands() {
  local desktop_file exec_line token command_name
  local -a app_dirs=(
    "$HOME/.local/share/applications"
    "/usr/share/applications"
  )

  while IFS= read -r desktop_file; do
    [[ -f "$desktop_file" ]] || continue
    exec_line="$(sed -n 's/^Exec=//p' "$desktop_file" | head -n 1)"
    [[ -n "$exec_line" ]] || continue

    for token in $exec_line; do
      case "$token" in
        %*|-[!-]*|--*)
          continue
          ;;
        env|flatpak|bash|sh|gtk-launch)
          continue
          ;;
        *=*)
          continue
          ;;
        /*)
          command_name="${token##*/}"
          ;;
        *)
          command_name="$token"
          ;;
      esac

      case "$command_name" in
        ""|python|python3|electron)
          continue
          ;;
      esac

      __archmeros_register_gui_command "$command_name"
      break
    done
  done < <(find "${app_dirs[@]}" -type f -name '*.desktop' 2>/dev/null)

  local known_gui_commands=(
    firefox
    floorp
    mousepad
    thunar
    pavucontrol
    obsidian
    code
    codium
    zen-browser
    chromium
    google-chrome-stable
    mpv
    vlc
  )

  local command_name
  for command_name in "${known_gui_commands[@]}"; do
    __archmeros_register_gui_command "$command_name"
  done
}

__archmeros_seed_gui_commands

__archmeros_detach_gui_preexec() {
  local command_line="${1:-}"
  [[ -n "$command_line" ]] || return 0
  [[ -n "${ARCHMEROS_GUI_DETACH_DISABLED:-}" ]] && return 0

  case "$command_line" in
    *'|'*|*';'*|*'&&'*|*'||'*|*'>'*|*'<'*|*'('*|*')'*|*'&')
      return 0
      ;;
  esac

  local -a argv=()
  read -r -a argv <<< "$command_line"
  [[ ${#argv[@]} -gt 0 ]] || return 0

  local command_name="${argv[0]}"
  case "$command_name" in
    sudo|doas|command|builtin|exec|time|setsid|nohup|walker|rofi|nvim|vim|vi|hx|helix)
      return 0
      ;;
  esac

  [[ -n "${__archmeros_gui_commands[$command_name]:-}" ]] || return 0

  local resolved_command
  resolved_command="$(type -P -- "$command_name" 2>/dev/null || true)"
  [[ -n "$resolved_command" ]] || return 0

  setsid "$resolved_command" "${argv[@]:1}" >/tmp/archmeros-gui-detach.log 2>&1 < /dev/null &
  disown || true
  exit
}

if declare -p preexec_functions >/dev/null 2>&1; then
  preexec_functions+=(__archmeros_detach_gui_preexec)
fi
