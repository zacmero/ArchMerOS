#!/usr/bin/env bash

set -euo pipefail

systemctl --user start archmeros-elephant.service archmeros-walker.service >/dev/null 2>&1 || true

workspace="$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // empty')"
dispatch_cmd="$HOME/.config/archmeros/scripts/archmeros-hyprctl-dispatch.sh"

walker >/tmp/archmeros-walker.log 2>&1 &

for _ in $(seq 1 40); do
  address="$(
    hyprctl clients -j 2>/dev/null \
      | jq -r '[.[] | select((.class == "walker" or .class == "dev.benz.walker") and .mapped == true and .hidden == false)] | last | .address // empty'
  )"
  if [[ -n "$address" ]]; then
    if hyprctl systeminfo 2>/dev/null | grep -q 'configProvider: lua'; then
      hyprctl repl \
        "hl.dispatch(hl.dsp.window.move({ workspace = \"$workspace\", follow = false, window = \"address:$address\" })); hl.dispatch(hl.dsp.focus({ window = \"address:$address\" })); hl.dispatch(hl.dsp.window.center()); hl.dispatch(hl.dsp.window.bring_to_top())" \
        >/dev/null 2>&1 || true
    else
      "$dispatch_cmd" movetoworkspacesilent "$workspace,address:$address" >/dev/null 2>&1 || true
      "$dispatch_cmd" focuswindow "address:$address" >/dev/null 2>&1 || true
      "$dispatch_cmd" centerwindow 1 >/dev/null 2>&1 || true
      "$dispatch_cmd" bringactivetotop >/dev/null 2>&1 || true
    fi
    exit 0
  fi
  sleep 0.02
done

exit 0
