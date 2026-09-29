#!/usr/bin/env bash
set -euo pipefail

scripts="$HOME/.config/archmeros/scripts"
if [[ "${1:-}" == --view ]]; then
    if command -v bat >/dev/null 2>&1; then
        "$scripts/archmeros-git-events.py" --history | bat --color=always --style=full --theme='Catppuccin Frappe' --file-name='ArchMerOS Git Activity.md' --paging=always --pager='less -R'
    else
        "$scripts/archmeros-git-events.py" --history | less -R
    fi
    exit
fi

"$scripts/archmeros-hyprctl-dispatch.sh" focusmonitor DP-1
ARCHMEROS_FORCE_POP_MODE=medium exec "$scripts/archmeros-launch-detached.sh" \
    --native-spawn archmeros-git-history \
    /usr/bin/wezterm start --always-new-process --class archmeros-git-history \
    --cwd "$HOME" -- bash "$scripts/archmeros-git-history.sh" --view
