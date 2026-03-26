#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
build_script="${repo_root}/install/build-sysc-greet.sh"
binary_path="${repo_root}/.build/sysc-greet/archmeros-sysc-greet"
kitty_conf="${repo_root}/config/greetd/sysc-greet/kitty-greeter.conf"
theme_name="${ARCHMEROS_SYSC_GREET_THEME:-archmeros}"

fullscreen=1
pass_args=()

for arg in "$@"; do
  case "$arg" in
    --inline)
      fullscreen=0
      ;;
    *)
      pass_args+=("$arg")
      ;;
  esac
done

bash "${build_script}"

default_args=(
  --test
  --theme "${theme_name}"
  --remember-username=false
)

if (( fullscreen )) && command -v kitty >/dev/null 2>&1; then
  exec kitty \
    --class ArchMerOS-GreeterTest \
    --start-as=fullscreen \
    --config "${kitty_conf}" \
    "${binary_path}" \
    "${default_args[@]}" \
    "${pass_args[@]}"
fi

exec "${binary_path}" "${default_args[@]}" "${pass_args[@]}"
