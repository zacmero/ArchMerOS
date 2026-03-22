#!/usr/bin/env bash

set -euo pipefail

script_path="$(readlink -f -- "${BASH_SOURCE[0]}")"
script_dir="$(cd -- "$(dirname -- "$script_path")" && pwd)"
template_root="${script_dir}/../../firefox/profiles/youtube-music"
profile_root="${XDG_DATA_HOME:-$HOME/.local/share}/archmeros/firefox/youtube-music"
chrome_root="${profile_root}/chrome"

mkdir -p "$chrome_root"

install -m 0644 "${template_root}/user.js" "${profile_root}/user.js"
install -m 0644 "${template_root}/chrome/userChrome.css" "${chrome_root}/userChrome.css"

exec env MOZ_ENABLE_WAYLAND=1 firefox \
  --new-instance \
  --profile "${profile_root}" \
  --new-window "https://music.youtube.com/"
