#!/usr/bin/env bash

set -euo pipefail

context_file="${1:-}"
archmeros_env="${2:-}"
archmeros_config_file="${HOME}/.config/archmeros/ai/aichat/config.yaml"

accent_cyan=$'\033[1;36m'
accent_magenta=$'\033[1;35m'
accent_gray=$'\033[38;5;245m'
accent_green=$'\033[1;32m'
reset=$'\033[0m'

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

session_slug() {
  printf '%s' "${1:-hud}" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//; s/-{2,}/-/g'
}

session_name_from_context() {
  local default_name="hud-chat-$(date +%H%M%S)"
  [[ -n "$context_file" && -s "$context_file" ]] || {
    printf '%s\n' "$default_name"
    return 0
  }

  local label file_path source raw_name
  label="$(sed -n 's/^Label: //p' "$context_file" | head -n 1)"
  file_path="$(sed -n 's/^File: //p' "$context_file" | head -n 1)"
  source="$(sed -n 's/^Source: //p' "$context_file" | head -n 1)"

  if [[ -n "$label" ]]; then
    raw_name="$label"
  elif [[ -n "$file_path" ]]; then
    raw_name="$(basename "$file_path")"
  elif [[ -n "$source" ]]; then
    raw_name="$source"
  else
    raw_name="chat"
  fi

  printf 'hud-%s-%s\n' "$(session_slug "${raw_name%.*}")" "$(date +%H%M%S)"
}

print_header() {
  local session_name="${1:-}"
  local context_source="${2:-none}"
  local context_summary="${3:-No context attached}"

  clear
  printf '%bARCHMEROS AI HUD%b\n' "$accent_cyan" "$reset"
  printf '%b────────────────────────────────────────────────────────────────────────────────%b\n' "$accent_cyan" "$reset"
  printf '%bSession%b  %s\n' "$accent_magenta" "$reset" "$session_name"
  printf '%bContext%b  %s\n' "$accent_magenta" "$reset" "$context_source"
  printf '%bNotes%b    %s\n' "$accent_magenta" "$reset" "$context_summary"
  printf '%bAichat%b   .help  .info session  .edit session  .save session\n' "$accent_magenta" "$reset"
  printf '%bHint%b     Right prompt shows session token usage, e.g. ctx 1177 (0.11%%)\n' "$accent_magenta" "$reset"
  printf '%b────────────────────────────────────────────────────────────────────────────────%b\n\n' "$accent_cyan" "$reset"
}

session_name="$(session_name_from_context)"
context_source="clean session"
context_summary="No terminal context detected. Starting an empty HUD chat."

if [[ -n "$context_file" && -s "$context_file" ]]; then
  case "$(sed -n 's/^Source: //p' "$context_file" | head -n 1)" in
    nvim)
      file_path="$(sed -n 's/^File: //p' "$context_file" | head -n 1)"
      filetype="$(sed -n 's/^Filetype: //p' "$context_file" | head -n 1)"
      cursor_line="$(sed -n 's/^Cursor line: //p' "$context_file" | head -n 1)"
      captured_lines="$(sed -n 's/^Captured lines: //p' "$context_file" | head -n 1)"
      context_source="nvim buffer"
      context_summary="$(basename "${file_path:-buffer}")"
      [[ -n "$filetype" ]] && context_summary="${context_summary} · ${filetype}"
      [[ -n "$cursor_line" ]] && context_summary="${context_summary} · cursor ${cursor_line}"
      [[ -n "$captured_lines" ]] && context_summary="${context_summary} · lines ${captured_lines}"
      ;;
    wezterm)
      pane_id="$(sed -n 's/^Pane: //p' "$context_file" | head -n 1)"
      captured_lines="$(sed -n 's/^Captured lines: //p' "$context_file" | head -n 1)"
      context_source="wezterm scrollback"
      context_summary="pane ${pane_id:-?}"
      [[ -n "$captured_lines" ]] && context_summary="${context_summary} · ${captured_lines}"
      ;;
  esac
fi

print_header "$session_name" "$context_source" "$context_summary"

if [[ -n "$context_file" && -s "$context_file" ]]; then
  preload_prompt="Use the attached source context as background context. Do not answer anything yet. Wait for my next question."

  if ! aichat "${model_args[@]}" --session "$session_name" --empty-session --save-session --file "$context_file" "$preload_prompt" >/tmp/archmeros-aichat-preload.log 2>&1; then
    printf '%bContext preload failed. Starting the interactive session anyway.%b\n\n' "$accent_green" "$reset" >&2
  fi

  exec aichat "${model_args[@]}" --session "$session_name"
fi

exec aichat "${model_args[@]}" --session "$session_name"
