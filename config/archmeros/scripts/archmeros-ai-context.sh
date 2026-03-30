#!/usr/bin/env bash

set -euo pipefail

lines="${ARCHMEROS_AI_CONTEXT_LINES:-120}"

if ! command -v hyprctl >/dev/null 2>&1 || ! command -v wezterm >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  exit 1
fi

wezterm_cli() {
  local output=""
  if output="$(timeout 1s wezterm cli "$@" 2>/dev/null)" && [[ -n "$output" ]]; then
    printf '%s\n' "$output"
    return 0
  fi

  local socket_dir="/run/user/$(id -u)/wezterm"
  local socket=""
  while IFS= read -r socket; do
    output="$(WEZTERM_UNIX_SOCKET="$socket" timeout 1s wezterm cli "$@" 2>/dev/null || true)"
    if [[ -n "$output" ]]; then
      printf '%s\n' "$output"
      return 0
    fi
  done < <(find "$socket_dir" -maxdepth 1 -type s -name 'gui-sock-*' 2>/dev/null | sort -r)

  return 1
}

active_class="$(
  hyprctl activewindow -j 2>/dev/null \
    | jq -r '.class // empty' 2>/dev/null \
    | tr '[:upper:]' '[:lower:]'
)"

case "$active_class" in
  org.wezfurlong.wezterm|archmeros-wezterm-*|archmeros-aichat-float|archmeros-fabric-browser)
    ;;
  *)
    exit 1
    ;;
esac

clients_json="$(wezterm_cli list-clients --format json || printf '[]')"
pane_id="$(printf '%s' "$clients_json" | jq -r 'map(select(.focused_pane_id? != null)) | .[0].focused_pane_id // empty' 2>/dev/null || true)"

if [[ -z "$pane_id" ]]; then
  list_json="$(wezterm_cli list --format json || printf '[]')"
  pane_id="$(printf '%s' "$list_json" | jq -r '
    [
      .. | objects
      | select(.pane_id? != null)
      | select((.is_active? == true) or (.active? == true) or (.focused? == true))
      | .pane_id
    ] | .[0] // empty
  ' 2>/dev/null || true)"
fi

[[ -n "$pane_id" ]] || exit 1

context_text="$(wezterm_cli get-text --pane-id "$pane_id" --start-line "-${lines}" --end-line -1 || true)"
context_text="${context_text//$'\0'/}"
[[ -n "${context_text//[$'\t\r\n ']}" ]] || exit 1

context_file="$(mktemp /tmp/archmeros-ai-context.XXXXXX.txt)"
cat >"$context_file" <<EOF
ArchMerOS terminal context
Captured from WezTerm pane ${pane_id}
Last ${lines} visible lines

${context_text}
EOF

printf '%s\n' "$context_file"
