#!/usr/bin/env bash
set -euo pipefail

# Keep the installed shortcut working when this script has already been linked.
script_path="$(readlink -f "${BASH_SOURCE[0]}")"
exec "${script_path%/config/archmeros/scripts/*}/mero-moji/mero-moji" "$@"
