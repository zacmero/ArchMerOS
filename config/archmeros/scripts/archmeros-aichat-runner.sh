#!/usr/bin/env bash

set -euo pipefail

context_file="${1:-}"
archmeros_env="${2:-}"
archmeros_config_file="${HOME}/.config/archmeros/ai/aichat/config.yaml"

cleanup() {
  if [[ -n "$context_file" && -f "$context_file" ]]; then
    rm -f "$context_file"
  fi
}

trap cleanup EXIT

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

model_args=()
if [[ -n "${ARCHMEROS_AICHAT_MODEL:-}" ]]; then
  model_args=(-m "$ARCHMEROS_AICHAT_MODEL")
fi

clear
printf 'ARCHMEROS AI HUD\n'
printf 'Ctrl+D exits the chat cleanly. Close the window with your normal close shortcut.\n\n'

if [[ -n "$context_file" && -s "$context_file" ]]; then
  printf 'Loaded context from the last focused WezTerm pane.\n\n'
  session_name="archmeros-hud-$(date +%Y%m%d-%H%M%S)"
  preload_prompt="Use the attached terminal context as background context. Briefly confirm you loaded it, then wait for my next question."

  if ! aichat "${model_args[@]}" --session "$session_name" --empty-session --save-session --file "$context_file" "$preload_prompt"; then
    printf '\nContext preload failed. Starting an interactive session anyway.\n\n' >&2
  else
    printf '\nContext loaded. Continuing in interactive session.\n\n'
  fi

  exec aichat "${model_args[@]}" --session "$session_name"
fi

printf 'No terminal context detected. Starting a clean AI session.\n\n'
exec aichat "${model_args[@]}"
