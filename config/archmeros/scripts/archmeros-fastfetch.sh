#!/usr/bin/env bash

set -euo pipefail

config_path="${HOME}/.config/archmeros/fastfetch/archmeros.jsonc"
host_name="$(hostnamectl --static 2>/dev/null || hostname)"
desktop_name="${XDG_CURRENT_DESKTOP:-}"
hypr_sig="${HYPRLAND_INSTANCE_SIGNATURE:-}"

if [[ "$host_name" == "mero-machine" ]] && [[ "$desktop_name" == *Hyprland* || -n "$hypr_sig" ]] && [[ -f "$config_path" ]]; then
  exec fastfetch -c "$config_path" "$@"
fi

exec fastfetch -c none "$@"
