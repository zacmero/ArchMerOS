#!/usr/bin/env bash

set -euo pipefail

telegram_bin="$(command -v Telegram || command -v telegram-desktop || true)"

if [[ -z "${telegram_bin:-}" ]]; then
  printf 'archmeros-telegram: Telegram binary not found\n' >&2
  exit 1
fi

if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  telegram_window="$(
    hyprctl clients -j 2>/dev/null \
      | jq -r '
          map(select(.class == "TelegramDesktop" or .class == "org.telegram.desktop"))
          | first
          | if . == null then empty else "\(.workspace.id)\t\(.address)" end
        ' 2>/dev/null || true
  )"

  if [[ -n "${telegram_window:-}" ]]; then
    workspace_id="${telegram_window%%$'\t'*}"
    address="${telegram_window#*$'\t'}"

    if [[ -n "${workspace_id:-}" && -n "${address:-}" ]]; then
      hyprctl dispatch workspace "${workspace_id}" >/dev/null 2>&1 || true
      hyprctl dispatch focuswindow "address:${address}" >/dev/null 2>&1 || true
      exit 0
    fi
  fi
fi

python3 "$HOME/.config/archmeros/scripts/archmeros-reopen-history.py" \
  track-launch general telegramdesktop telegram telegram -- \
  "$HOME/.config/archmeros/scripts/archmeros-telegram.sh" \
  >/tmp/archmeros-reopen-track-telegram.log 2>&1 || true

nohup "$telegram_bin" >/tmp/archmeros-telegram.log 2>&1 &
disown || true
