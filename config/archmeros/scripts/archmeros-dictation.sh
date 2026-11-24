#!/usr/bin/env bash

set -euo pipefail

runtime_dir="${XDG_RUNTIME_DIR:?}/archmeros"
mkdir -p "$runtime_dir"
hold_file="$runtime_dir/dictation-hold"
exec 9>"$runtime_dir/dictation.lock"
flock 9

# Pause release can arrive with different modifiers. Only stop a recording
# that was started by holding Pause.
case "$1" in
  hold)
    [[ "$(voxtype status)" == idle ]] || exit 0
    voxtype record start
    : > "$hold_file"
    ;;
  release)
    [[ -f "$hold_file" ]] || exit 0
    rm -f "$hold_file"
    exec voxtype record stop
    ;;
  toggle)
    rm -f "$hold_file"
    exec voxtype record toggle
    ;;
esac
