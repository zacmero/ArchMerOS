#!/usr/bin/env bash

set -euo pipefail

lines="${ARCHMEROS_AI_CONTEXT_LINES:-120}"
uid="$(id -u)"
socket_dir="/run/user/${uid}/wezterm"

if ! command -v hyprctl >/dev/null 2>&1 || ! command -v wezterm >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  exit 1
fi

json_or_default() {
  local raw="${1:-}"
  local fallback="${2:-}"
  case "$raw" in
    \[*|\{*)
      printf '%s\n' "$raw"
      ;;
    *)
      printf '%s\n' "$fallback"
      ;;
  esac
}

wezterm_cli() {
  local output=""
  if output="$(timeout 1s wezterm cli "$@" 2>/dev/null)" && [[ -n "$output" ]]; then
    printf '%s\n' "$output"
    return 0
  fi

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

sanitize_name() {
  printf '%s' "${1:-session}" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//; s/-{2,}/-/g'
}

nvim_remote() {
  local socket="${1:-}"
  local expr="${2:-}"
  [[ -S "$socket" ]] || return 1
  nvim --server "$socket" --remote-expr "$expr" 2>/dev/null || return 1
}

capture_nvim_context() {
  local tty_name="${1:-}"
  [[ -n "$tty_name" ]] || return 1

  local tty_short="${tty_name#/dev/}"
  local nvim_pid=""
  nvim_pid="$(
    ps -eo pid=,tty=,comm= --sort=-pid 2>/dev/null \
      | awk -v tty="$tty_short" '$2 == tty && $3 == "nvim" { print $1; exit }'
  )"
  [[ -n "$nvim_pid" ]] || return 1

  local embed_pid=""
  embed_pid="$(pgrep -P "$nvim_pid" -x nvim | head -n 1 || true)"

  local socket=""
  for candidate in \
    "/run/user/${uid}/nvim.${embed_pid}.0" \
    "/run/user/${uid}/nvim.${nvim_pid}.0"; do
    if [[ -S "$candidate" ]]; then
      socket="$candidate"
      break
    fi
  done
  [[ -n "$socket" ]] || return 1

  local file_path file_name filetype cursor_line total_lines start_line end_line payload_json
  file_path="$(nvim_remote "$socket" 'expand("%:p")' || true)"
  [[ -n "$file_path" ]] || return 1
  filetype="$(nvim_remote "$socket" '&filetype' || true)"
  cursor_line="$(nvim_remote "$socket" 'line(".")' || true)"
  total_lines="$(nvim_remote "$socket" 'line("$")' || true)"
  start_line="$(nvim_remote "$socket" 'max([1, line("w0") - 20])' || true)"
  end_line="$(nvim_remote "$socket" 'min([line("$"), line("w$") + 40])' || true)"

  [[ "$cursor_line" =~ ^[0-9]+$ ]] || return 1
  [[ "$total_lines" =~ ^[0-9]+$ ]] || return 1
  [[ "$start_line" =~ ^[0-9]+$ ]] || start_line=1
  [[ "$end_line" =~ ^[0-9]+$ ]] || end_line="$total_lines"

  payload_json="$(
    nvim_remote "$socket" "json_encode(map(range(${start_line}, ${end_line}), 'printf(\"%5d | %s\", v:val, getline(v:val))'))" || true
  )"
  [[ -n "$payload_json" ]] || return 1

  local context_file
  context_file="$(mktemp /tmp/archmeros-ai-context.XXXXXX.txt)"
  file_name="$(basename "$file_path")"
  {
    printf 'ArchMerOS nvim buffer context\n'
    printf 'Source: nvim\n'
    printf 'File: %s\n' "$file_path"
    printf 'Label: %s\n' "$file_name"
    printf 'Filetype: %s\n' "${filetype:-text}"
    printf 'Cursor line: %s of %s\n' "$cursor_line" "$total_lines"
    printf 'Captured lines: %s-%s\n\n' "$start_line" "$end_line"
    printf '%s\n' "$payload_json" | jq -r '.[]'
  } >"$context_file"

  printf '%s\n' "$context_file"
  return 0
}

active_json="$(json_or_default "$(hyprctl activewindow -j 2>/dev/null || true)" '{}')"
active_class="$(printf '%s' "$active_json" | jq -r '.class // empty' 2>/dev/null | tr '[:upper:]' '[:lower:]')"
active_pid="$(printf '%s' "$active_json" | jq -r '.pid // empty' 2>/dev/null || true)"
active_title="$(printf '%s' "$active_json" | jq -r '.title // empty' 2>/dev/null || true)"
active_title_stripped="$(printf '%s' "$active_title" | sed -E 's/^\[[0-9]+\/[0-9]+\][[:space:]]*//')"
active_tab_index="$(printf '%s' "$active_title" | sed -nE 's/^\[([0-9]+)\/[0-9]+\].*/\1/p' | head -n 1)"

case "$active_class" in
  org.wezfurlong.wezterm|archmeros-wezterm-*)
    ;;
  *)
    exit 1
    ;;
esac

clients_json='[]'
list_json='[]'
preferred_socket=""
if [[ -n "$active_pid" && -S "${socket_dir}/gui-sock-${active_pid}" ]]; then
  preferred_socket="${socket_dir}/gui-sock-${active_pid}"
fi

if [[ -n "$preferred_socket" ]]; then
  clients_json="$(WEZTERM_UNIX_SOCKET="$preferred_socket" timeout 1s wezterm cli list-clients --format json 2>/dev/null || printf '[]')"
  list_json="$(WEZTERM_UNIX_SOCKET="$preferred_socket" timeout 1s wezterm cli list --format json 2>/dev/null || printf '[]')"
else
  clients_json="$(wezterm_cli list-clients --format json || printf '[]')"
  list_json="$(wezterm_cli list --format json || printf '[]')"
fi

pane_id=""
if [[ -n "$preferred_socket" ]]; then
  pane_id="$(
    printf '%s' "$clients_json" \
      | jq -r 'map(select(.focused_pane_id? != null)) | .[0].focused_pane_id // empty' 2>/dev/null || true
  )"
fi

if [[ -z "$pane_id" && -n "$active_title_stripped" ]]; then
  pane_id="$(
    printf '%s' "$list_json" \
      | jq -r --arg title "$active_title" --arg stripped "$active_title_stripped" '
          [
            .[]
            | select(
                (.title? == $title) or
                (.title? == $stripped) or
                (.window_title? == $title) or
                (.window_title? == $stripped)
              )
            | .pane_id
          ] | .[0] // empty
        ' 2>/dev/null || true
  )"
fi

if [[ -z "$pane_id" ]]; then
  if [[ -n "$active_tab_index" && "$active_tab_index" =~ ^[0-9]+$ ]]; then
    pane_id="$(
      printf '%s' "$list_json" \
        | jq -r --argjson idx "$active_tab_index" '
            ([.[].tab_id] | unique) as $tabs
            | ($tabs[$idx - 1] // empty) as $wanted
            | if $wanted == empty then empty else
                ([ .[] | select(.tab_id == $wanted) | .pane_id ] | .[0] // empty)
              end
          ' 2>/dev/null || true
    )"
  fi
fi

if [[ -z "$pane_id" ]]; then
  pane_id="$(
    printf '%s' "$list_json" | jq -r '.[0].pane_id // empty' 2>/dev/null || true
  )"
fi

[[ -n "$pane_id" ]] || exit 1

tty_name="$(
  printf '%s' "$list_json" \
    | jq -r --argjson pane_id "$pane_id" '
        [
          .. | objects
          | select(.pane_id? == $pane_id)
          | .tty_name
        ] | .[0] // empty
      ' 2>/dev/null || true
)"

if context_file="$(capture_nvim_context "$tty_name" 2>/dev/null)"; then
  printf '%s\n' "$context_file"
  exit 0
fi

context_text="$(wezterm_cli get-text --pane-id "$pane_id" --start-line "-${lines}" --end-line -1 || true)"
context_text="${context_text//$'\0'/}"
[[ -n "${context_text//[$'\t\r\n ']}" ]] || exit 1

context_file="$(mktemp /tmp/archmeros-ai-context.XXXXXX.txt)"
cat >"$context_file" <<EOF
ArchMerOS wezterm pane context
Source: wezterm
Pane: ${pane_id}
TTY: ${tty_name}
Captured lines: last ${lines} visible lines

${context_text}
EOF

printf '%s\n' "$context_file"
