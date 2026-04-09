#!/usr/bin/env bash

set -euo pipefail

base_config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
base_config_file="$base_config_home/lazydocker/config.yml"
select_config_home="${ARCHMEROS_LAZYDOCKER_SELECT_HOME:-$HOME/.config/archmeros/lazydocker-select}"
tmp_dir="$(mktemp -d)"
target_config="$tmp_dir/lazydocker/config.yml"

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

mkdir -p "$(dirname "$target_config")" "$select_config_home"

if [[ -f "$base_config_file" ]]; then
  cp "$base_config_file" "$target_config"
else
  : > "$target_config"
fi

if grep -qi '^gui:[[:space:]]*$' "$target_config"; then
  if ! grep -qi '^[[:space:]]*mouseEvents:[[:space:]]*true[[:space:]]*$' "$target_config"; then
    awk '
      BEGIN { inserted = 0 }
      /^gui:[[:space:]]*$/ && inserted == 0 {
        print
        print "  mouseEvents: true"
        inserted = 1
        next
      }
      { print }
      END {
        if (inserted == 0) {
          print ""
          print "gui:"
          print "  mouseEvents: true"
        }
      }
    ' "$target_config" > "$target_config.tmp"
    mv "$target_config.tmp" "$target_config"
  fi
else
  printf '\ngui:\n  mouseEvents: true\n' >> "$target_config"
fi

exec env XDG_CONFIG_HOME="$tmp_dir" lazydocker "$@"
