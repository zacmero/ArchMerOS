#!/usr/bin/env bash
set -euo pipefail

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}/archmeros"
mkdir -p "$runtime_dir"
exec 9>"$runtime_dir/daemon-message.lock"
flock -n 9 || exit 0

umask 077
snapshot="$(mktemp "$runtime_dir/daemon-message.XXXXXX")"
trap 'rm -f "$snapshot"' EXIT
"$HOME/.config/archmeros/scripts/archmeros-beacon-familiar.py" context > "$snapshot"

for env_file in "$HOME/.config/archmeros/ai/aichat.env" /opt/mero_terminal/aichat.env; do
    if [[ -r "$env_file" ]]; then
        set -a
        # shellcheck disable=SC1090
        source "$env_file"
        set +a
    fi
done
export AICHAT_CONFIG_FILE="$HOME/.config/archmeros/ai/aichat/config.yaml"
unset AICHAT_ENV_FILE

prompt="You are Daemon Master, the AI daemon representing ArchMerOS. From this system snapshot, speak one original eerie but sometimes inspiring sentence of at most 18 words. Reflect actual activity subtly. No invented facts, instructions, or claims of action. No preamble."
if response="$(timeout 30s aichat -S -m openrouter:openrouter/free --file "$snapshot" "$prompt" 2>>"$runtime_dir/daemon-message.log")" && [[ -n "$response" ]]; then
    message="$(printf '%s' "$response" | python -c 'import re, sys, textwrap; text=sys.stdin.read(); text=re.sub(r"(?is)<think\b[^>]*>.*?</think>", "", text); text=re.sub(r"(?is)<think\b[^>]*>.*", "", text); text=re.sub(r"(?s)<[^>]+>", "", text); print(textwrap.shorten(" ".join(text.split()), width=110, placeholder="…"))')"
    [[ -n "$message" ]] || message="The signal is quiet. I remain at the threshold."
else
    message="The signal is quiet. I remain at the threshold."
fi
notify-send -a 'Daemon Master' -t 9000 'Daemon Master' "$message"
