#!/usr/bin/env bash

set -euo pipefail

repo_patterns="$HOME/.config/archmeros/fabric/patterns"
user_patterns="${XDG_CONFIG_HOME:-$HOME/.config}/fabric/patterns"
data_patterns="${XDG_DATA_HOME:-$HOME/.local/share}/fabric/patterns"
fabric_cmd="$(command -v fabric-ai || command -v fabric || true)"
script_path="$(readlink -f "$0")"
fabric_help_filter="sed '/failed to create modcache index dir/d;/Failed to download translation/d;/mkdir .*\\.config\\/fabric: read-only file system/d'"

declare -a roots=("$repo_patterns" "$user_patterns" "$data_patterns")
declare -A seen=()
declare -a entries=()

add_entry() {
  local label="$1"
  local target="$2"
  local detail="$3"
  if [[ -z "${seen["$label|$target"]+x}" ]]; then
    seen["$label|$target"]=1
    entries+=("$(printf '%s\t%s\t%s' "$label" "$target" "$detail")")
  fi
}

pick_preview_file() {
  local dir="$1"
  local candidate=""
  for candidate in README.md system.md user.md prompt.md; do
    if [[ -f "$dir/$candidate" ]]; then
      printf '%s\n' "$dir/$candidate"
      return 0
    fi
  done
  find "$dir" -maxdepth 1 -type f 2>/dev/null | sort | head -n 1
}

show_install_state() {
  if [[ -n "$fabric_cmd" ]]; then
    cat <<EOF
Fabric is installed, but no pattern directories were discovered yet.

Search paths:
  - $repo_patterns
  - $user_patterns
  - $data_patterns

Current Fabric binary:
  $fabric_cmd

Practical next steps:
  1. Run: fabric-ai --setup
  2. Put ArchMerOS-owned patterns in:
     $repo_patterns
  3. Reopen this browser
EOF
  else
    cat <<'EOF'
Fabric is not installed on this machine yet.

Install it with:
  yay -S fabric-ai-bin
EOF
  fi
}

preview_target() {
  local target="$1"
  if [[ "$target" == "__FABRIC_HELP__" ]]; then
    if [[ -n "$fabric_cmd" ]]; then
      "$fabric_cmd" --help 2>&1 | eval "$fabric_help_filter" | sed -n '1,220p'
    else
      show_install_state
    fi
    return 0
  fi

  if [[ "$target" == "__FABRIC_SETUP__" ]]; then
    show_install_state
    return 0
  fi

  for candidate in README.md system.md user.md prompt.md; do
    if [[ -f "$target/$candidate" ]]; then
      if command -v bat >/dev/null 2>&1; then
        bat --color=always --style=plain --language=markdown --line-range=1:220 "$target/$candidate"
      else
        sed -n '1,220p' "$target/$candidate"
      fi
      return 0
    fi
  done

  find "$target" -maxdepth 1 -type f | sort | sed -n '1,40p'
}

open_target() {
  local label="$1"
  local target="$2"

  clear
  if [[ "$target" == "__FABRIC_HELP__" ]]; then
    if [[ -n "$fabric_cmd" ]]; then
      "$fabric_cmd" --help 2>&1 | eval "$fabric_help_filter" | ${PAGER:-less}
    else
      show_install_state
      printf '\nPress Enter to return...'
      read -r _
    fi
    return 0
  fi

  if [[ "$target" == "__FABRIC_SETUP__" ]]; then
    cat <<EOF
ARCHMEROS FABRIC SETUP

EOF
    show_install_state
    printf '\nPress Enter to return...'
    read -r _
    return 0
  fi

  local preview_file
  preview_file="$(pick_preview_file "$target")"
  cat <<EOF
ARCHMEROS FABRIC PATTERN

Pattern: $label
Path:    $target

Suggested usage:
  cat some_input.txt | ${fabric_cmd:-fabric-ai} --pattern $label
  ${fabric_cmd:-fabric-ai} --pattern $label < some_input.txt

EOF

  if [[ -n "$preview_file" && -f "$preview_file" ]]; then
    if command -v bat >/dev/null 2>&1; then
      bat --paging=always --style=plain --language=markdown "$preview_file"
    else
      ${PAGER:-less} "$preview_file"
    fi
  else
    printf 'No preview file found in this pattern directory.\n'
    printf '\nPress Enter to return...'
    read -r _
  fi
}

if [[ "${1:-}" == "--preview" ]]; then
  preview_target "${2:-}"
  exit 0
fi

if [[ "${1:-}" == "--open" ]]; then
  open_target "${2:-}" "${3:-}"
  exit 0
fi

add_entry "Fabric CLI help" "__FABRIC_HELP__" "Show the installed fabric command help and usage"
add_entry "Fabric setup hint" "__FABRIC_SETUP__" "Show the next step when Fabric is installed but patterns are not populated yet"

for root in "${roots[@]}"; do
  [[ -d "$root" ]] || continue
  while IFS= read -r dir; do
    name="$(basename "$dir")"
    preview_file="$(pick_preview_file "$dir")"
    description="Pattern from $root"
    if [[ -n "$preview_file" && -f "$preview_file" ]]; then
      description="$(sed -n '1,3p' "$preview_file" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | cut -c1-120)"
    fi
    add_entry "$name" "$dir" "$description"
  done < <(find "$root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
done

while true; do
  selection="$(
    printf '%s\n' "${entries[@]}" \
      | sort -u \
      | fzf \
          --ansi \
          --no-mouse \
          --delimiter=$'\t' \
          --with-nth=1,3 \
          --layout=reverse \
          --height=100% \
          --border=rounded \
          --prompt='fabric> ' \
          --header='Enter: inspect • Esc: close' \
          --preview '
target=$(printf "%s" {} | cut -f2)
'"$script_path"' --preview "$target"
          ' \
          --preview-window='right:64%:wrap'
  )"

  [[ -n "$selection" ]] || exit 0

  label="$(printf '%s' "$selection" | cut -f1)"
  target="$(printf '%s' "$selection" | cut -f2)"
  open_target "$label" "$target"
done
