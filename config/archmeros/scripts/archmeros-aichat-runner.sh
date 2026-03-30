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
printf 'Esc/close the window when done. Ctrl+D exits the chat cleanly.\n\n'

if [[ -n "$context_file" && -s "$context_file" ]]; then
  printf 'Loaded context from the last focused WezTerm pane.\n\n'
  exec aichat "${model_args[@]}" --file "$context_file"
fi

printf 'No terminal context detected. Starting a clean AI session.\n\n'
exec aichat "${model_args[@]}"
