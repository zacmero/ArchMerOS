#!/usr/bin/env bash

set -euo pipefail

imv_common_args=(
  -c 'bind <Ctrl+h> prev'
  -c 'bind <Ctrl+l> next'
  -c 'bind <Ctrl+KP_4> prev'
  -c 'bind <Ctrl+KP_6> next'
)

if [[ $# -eq 1 && -f "$1" ]]; then
  image_path="$(realpath -- "$1")"
  exec ~/.config/archmeros/scripts/archmeros-launch-detached.sh \
    imv "${imv_common_args[@]}" \
    -n "$image_path" "$(dirname -- "$image_path")"
fi

exec ~/.config/archmeros/scripts/archmeros-launch-detached.sh \
  imv "${imv_common_args[@]}" \
  "$@"
