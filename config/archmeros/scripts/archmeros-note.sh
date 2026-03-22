#!/usr/bin/env bash

set -euo pipefail

note_path="${HOME}/Desktop/note-$(date +%Y%m%d-%H%M%S).txt"
touch "${note_path}"

exec ~/.config/archmeros/scripts/archmeros-nvim.sh "${note_path}"
