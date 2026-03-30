#!/usr/bin/env bash

set -euo pipefail

printf '%s pipe-trigger\n' "$(date +%s.%N)" >> /tmp/archmeros-type-pipe.log 2>/dev/null || true
sleep 0.18
exec wtype '|'
