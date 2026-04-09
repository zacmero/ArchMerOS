#!/usr/bin/env bash

set -euo pipefail

base_config_home="${YAZI_CONFIG_HOME:-$HOME/.config/yazi}"
select_config_home="${ARCHMEROS_YAZI_SELECT_HOME:-$HOME/.config/archmeros/yazi-select}"
tmp_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

mkdir -p "$select_config_home"

if [[ -d "$base_config_home" ]]; then
  cp -a "$base_config_home/." "$tmp_dir/" 2>/dev/null || true
fi

if [[ -f "$tmp_dir/yazi.toml" ]]; then
  if ! grep -q '^[[:space:]]*mouse_events[[:space:]]*=' "$tmp_dir/yazi.toml"; then
    if grep -q '^\[manager\]$' "$tmp_dir/yazi.toml"; then
      sed -i '/^\[manager\]$/a mouse_events = []' "$tmp_dir/yazi.toml"
    elif grep -q '^\[mgr\]$' "$tmp_dir/yazi.toml"; then
      sed -i '/^\[mgr\]$/a mouse_events = []' "$tmp_dir/yazi.toml"
    else
      printf '\n[mgr]\nmouse_events = []\n' >> "$tmp_dir/yazi.toml"
    fi
  fi
else
  cat > "$tmp_dir/yazi.toml" <<'EOF'
[mgr]
mouse_events = []
EOF
fi

exec env YAZI_CONFIG_HOME="$tmp_dir" yazi "$@"
