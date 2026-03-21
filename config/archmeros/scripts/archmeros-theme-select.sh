#!/usr/bin/env bash

set -euo pipefail

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
repo_root="$(cd "$(dirname "$script_path")/../../.." && pwd)"
bundle_dir="${repo_root}/themes/bundles"
rofi_theme="${HOME}/.config/rofi/launchers/theme-selector.rasi"
appearance_script="${HOME}/.config/archmeros/scripts/archmeros-theme.py"
transparency_script="${HOME}/.config/archmeros/scripts/archmeros-transparency.sh"

list_bundles() {
  find "${bundle_dir}" -maxdepth 1 -type f -name '*.json' -print0 \
    | sort -z \
    | while IFS= read -r -d '' file; do
        jq -r '[.id, (.label // .id), (.description // "")] | @tsv' "$file"
      done
}

apply_bundle() {
  local bundle_file="$1"
  local appearance_mode appearance_name transparency_name

  appearance_mode="$(jq -r '.appearance.mode // "preset"' "$bundle_file")"
  appearance_name="$(jq -r '.appearance.name // "default"' "$bundle_file")"
  transparency_name="$(jq -r '.transparency // empty' "$bundle_file")"

  case "$appearance_mode" in
    default)
      "$appearance_script" --apply-default --no-refresh
      ;;
    auto)
      "$appearance_script" --apply-auto --no-refresh
      ;;
    preset)
      "$appearance_script" --apply-preset "$appearance_name" --no-refresh
      ;;
    *)
      printf 'Unknown appearance mode in %s: %s\n' "$bundle_file" "$appearance_mode" >&2
      exit 1
      ;;
  esac

  if [[ -n "$transparency_name" ]]; then
    "$transparency_script" apply "$transparency_name" >/dev/null
  else
    ~/.config/archmeros/scripts/archmeros-refresh-shell.sh >/dev/null
  fi
}

pick_bundle() {
  mapfile -t entries < <(list_bundles)
  [[ ${#entries[@]} -gt 0 ]] || exit 1

  local choice
  choice="$(
    printf '%s\n' "${entries[@]}" \
      | awk -F '\t' '{print $2 "  ::  " $3 "\t" $1}' \
      | rofi -dmenu -i -markup-rows -p "Shell Theme" -theme "$rofi_theme"
  )"

  [[ -n "${choice:-}" ]] || exit 0

  local bundle_id
  bundle_id="$(printf '%s' "$choice" | awk -F '\t' '{print $2}')"
  [[ -n "${bundle_id:-}" ]] || exit 1
  apply_bundle "${bundle_dir}/${bundle_id}.json"
}

case "${1:-pick}" in
  pick)
    pick_bundle
    ;;
  list)
    list_bundles
    ;;
  apply)
    [[ -n "${2:-}" ]] || {
      printf 'Usage: %s apply <bundle-id>\n' "$0" >&2
      exit 1
    }
    apply_bundle "${bundle_dir}/${2}.json"
    ;;
  *)
    printf 'Usage: %s [pick|list|apply <bundle-id>]\n' "$0" >&2
    exit 1
    ;;
esac
