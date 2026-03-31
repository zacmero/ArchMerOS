#!/usr/bin/env bash

set -euo pipefail

archmeros_env="${HOME}/.config/archmeros/ai/aichat.env"
archmeros_config_file="${HOME}/.config/archmeros/ai/aichat/config.yaml"
sessions_dir="${HOME}/.config/aichat/sessions"

if [[ -f "$archmeros_env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$archmeros_env"
  set +a
fi

if [[ -f /opt/mero_terminal/aichat.env ]]; then
  set -a
  # shellcheck disable=SC1091
  source /opt/mero_terminal/aichat.env
  set +a
fi

export AICHAT_CONFIG_FILE="$archmeros_config_file"
unset AICHAT_ENV_FILE

mkdir -p "$sessions_dir"

session_slug() {
  printf '%s' "${1:-hud-chat}" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//; s/-{2,}/-/g'
}

list_sessions() {
  find "$sessions_dir" -maxdepth 1 -type f -name '*.yaml' -printf '%T@\t%TY-%Tm-%Td %TH:%TM\t%f\n' 2>/dev/null \
    | sort -nr \
    | awk -F '\t' '{
        name = $3;
        sub(/\.yaml$/, "", name);
        printf "%s\t%s\n", name, $2;
      }'
}

preview_session() {
  local session_name="${1:-}"
  local session_file="${sessions_dir}/${session_name}.yaml"
  [[ -f "$session_file" ]] || {
    printf 'No saved session file.\n'
    return 0
  }

  if command -v bat >/dev/null 2>&1; then
    bat --color=always --style=plain --language=yaml --line-range=1:220 "$session_file"
    return 0
  fi

  sed -n '1,220p' "$session_file"
}

if [[ "${1:-}" == "--preview" ]]; then
  preview_session "${2:-}"
  exit 0
fi

prompt_for_name() {
  local prompt_text="${1:-Session name}"
  local default_name="${2:-hud-chat-$(date +%H%M%S)}"
  local input=""
  printf '%s [%s]: ' "$prompt_text" "$default_name" >/dev/tty
  IFS= read -r input </dev/tty || true
  input="${input:-$default_name}"
  session_slug "$input"
}

while true; do
  entries="$(list_sessions || true)"
  if [[ -z "$entries" ]]; then
    session_name="$(prompt_for_name "New session name" "hud-chat-$(date +%H%M%S)")"
    exec aichat --session "$session_name"
  fi

  selection="$(
    printf '%s\n' "$entries" \
      | fzf --ansi --delimiter=$'\t' --with-nth=1,2 \
          --expect=enter,ctrl-r,ctrl-n,ctrl-d \
          --header=$'Enter load  |  Ctrl-R rename  |  Ctrl-N new session  |  Ctrl-D delete  |  Esc close' \
          --preview "bash $HOME/.config/archmeros/scripts/archmeros-aichat-sessions.sh --preview {1}"
  )"

  [[ -n "$selection" ]] || exit 0

  key="$(printf '%s\n' "$selection" | sed -n '1p')"
  selected_session="$(printf '%s\n' "$selection" | sed -n '2p' | cut -f1)"
  [[ -n "$selected_session" ]] || exit 0

  case "$key" in
    ctrl-r)
      new_name="$(prompt_for_name "Rename session" "$selected_session")"
      if [[ -n "$new_name" && "$new_name" != "$selected_session" ]]; then
        mv -f "${sessions_dir}/${selected_session}.yaml" "${sessions_dir}/${new_name}.yaml"
      fi
      ;;
    ctrl-d)
      printf 'Delete session "%s"? [y/N]: ' "$selected_session" >/dev/tty
      confirm=""
      IFS= read -r confirm </dev/tty || true
      case "$confirm" in
        y|Y|yes|YES)
          rm -f "${sessions_dir}/${selected_session}.yaml"
          ;;
      esac
      ;;
    ctrl-n)
      session_name="$(prompt_for_name "New session name" "hud-chat-$(date +%H%M%S)")"
      exec aichat --session "$session_name"
      ;;
    *)
      exec aichat --session "$selected_session"
      ;;
  esac
done

exit 0
