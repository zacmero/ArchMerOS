#!/usr/bin/env bash

set -u

action=${1:-}
case "$action" in
    previous|play-pause|next) ;;
    *) exit 2 ;;
esac

mapfile -t players < <(playerctl --list-all 2>/dev/null)
((${#players[@]})) || exit 0

target=
playing=
for player in "${players[@]}"; do
    url=$(playerctl --player="$player" metadata xesam:url 2>/dev/null || true)
    if [[ $url == https://music.youtube.com/* ]]; then
        target=$player
        break
    fi

    if [[ -z $playing ]] && [[ $(playerctl --player="$player" status 2>/dev/null) == Playing ]]; then
        playing=$player
    fi
done

target=${target:-${playing:-${players[0]}}}
exec playerctl --player="$target" "$action"
