#!/usr/bin/env bash

set -euo pipefail

telegram_bin="/usr/bin/telegram-desktop"

if command -v hyprctl >/dev/null 2>&1 && pgrep -x telegram-desktop >/dev/null 2>&1; then
  hyprctl dispatch focuswindow "class:^(TelegramDesktop|org.telegram.desktop)$" >/dev/null 2>&1 && exit 0
fi

nohup "$telegram_bin" >/tmp/archmeros-telegram.log 2>&1 &
disown || true
