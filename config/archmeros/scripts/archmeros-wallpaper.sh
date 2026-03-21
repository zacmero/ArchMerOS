#!/usr/bin/env bash

set -euo pipefail

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
repo_root="$(cd "$(dirname "$script_path")/../../.." && pwd)"

exec python3 "${repo_root}/config/archmeros/scripts/archmeros-wallpaper.py" "$@"
