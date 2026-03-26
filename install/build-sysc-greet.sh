#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src_root="${repo_root}/vendor/sysc-greet"
build_root="${repo_root}/.build/sysc-greet"
binary_path="${build_root}/archmeros-sysc-greet"
data_dir="${repo_root}/config/greetd/sysc-greet/share"
go_cache_dir="${build_root}/gocache"
go_mod_cache_dir="${build_root}/gomodcache"

mkdir -p "${build_root}"
mkdir -p "${go_cache_dir}" "${go_mod_cache_dir}"

(
  cd "${src_root}"
  export GOCACHE="${go_cache_dir}"
  export GOMODCACHE="${go_mod_cache_dir}"
  GOWORK=off go build \
    -ldflags "-X main.dataDir=${data_dir}" \
    -o "${binary_path}" \
    ./cmd/sysc-greet
)

printf 'built: %s\n' "${binary_path}"
printf 'data:  %s\n' "${data_dir}"
