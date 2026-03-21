#!/usr/bin/env bash

set -euo pipefail

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
repo_root="$(cd "$(dirname "$script_path")/../../.." && pwd)"
presets_dir="${repo_root}/config/hypr/presets"
active_file="${repo_root}/config/hypr/transparency.conf"

apply_preset() {
  local preset_name="$1"
  local preset_file="${presets_dir}/transparency-${preset_name}.conf"

  if [[ ! -f "$preset_file" ]]; then
    printf 'Unknown transparency preset: %s\n' "$preset_name" >&2
    exit 1
  fi

  cp "$preset_file" "$active_file"
  ~/.config/archmeros/scripts/archmeros-refresh-shell.sh >/dev/null
  printf 'Applied transparency preset: %s\n' "$preset_name"
}

list_presets() {
  find "$presets_dir" -maxdepth 1 -type f -name 'transparency-*.conf' -printf '%f\n' \
    | sed -e 's/^transparency-//' -e 's/\.conf$//' \
    | sort
}

pick_preset() {
  mapfile -t presets < <(list_presets)
  [[ ${#presets[@]} -gt 0 ]] || exit 1

  local choice
  choice="$(
    printf '%s\n' "${presets[@]}" \
      | rofi -dmenu -i -p "Transparency"
  )"

  [[ -n "${choice:-}" ]] || exit 0
  apply_preset "$choice"
}

case "${1:-pick}" in
  pick)
    pick_preset
    ;;
  list)
    list_presets
    ;;
  apply)
    [[ -n "${2:-}" ]] || {
      printf 'Usage: %s apply <preset>\n' "$0" >&2
      exit 1
    }
    apply_preset "$2"
    ;;
  *)
    printf 'Usage: %s [pick|list|apply <preset>]\n' "$0" >&2
    exit 1
    ;;
esac
