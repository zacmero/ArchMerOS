#!/usr/bin/env bash

set -euo pipefail

lines="${ARCHMEROS_AI_CONTEXT_LINES:-120}"

if ! command -v hyprctl >/dev/null 2>&1 || ! command -v wezterm >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  exit 1
fi

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

clients_json="$(timeout 1s wezterm cli list-clients --format json 2>/dev/null || printf '[]')"
pane_id="$(printf '%s' "$clients_json" | jq -r 'map(select(.focused_pane_id? != null)) | .[0].focused_pane_id // empty' 2>/dev/null || true)"

if [[ -z "$pane_id" ]]; then
  list_json="$(timeout 1s wezterm cli list --format json 2>/dev/null || printf '[]')"
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

context_text="$(timeout 1s wezterm cli get-text --pane-id "$pane_id" --start-line "-${lines}" --end-line -1 2>/dev/null || true)"
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
