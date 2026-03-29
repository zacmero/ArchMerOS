#!/usr/bin/env bash

set -euo pipefail

pkill -f 'archmeros-reopen-history.py listen' >/dev/null 2>&1 || true
nohup python3 "$HOME/.config/archmeros/scripts/archmeros-reopen-history.py" listen \
  >/tmp/archmeros-reopen-listener.log 2>&1 </dev/null &
