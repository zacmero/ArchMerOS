#!/usr/bin/env bash
set -euo pipefail

# Upstream's Arch package; update the version and checksum together after validation.
version=1.0.8
sha256=191f7f0d12a30aacb4adef675bbfe3fb4bbc77baec101e562ab3e00065ee9362
[[ "$(uname -m)" == x86_64 ]] || { printf 'Sentinel package requires x86_64\n' >&2; exit 1; }
if [[ "${1:-}" != --verify-only ]] && pacman -Q sentinel 2>/dev/null | grep -qx "sentinel ${version}-1"; then
  exit 0
fi
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/archmeros/packages"
mkdir -p "$cache_dir"
package="$cache_dir/sentinel-${version}.pkg.tar.zst"
if ! printf '%s  %s\n' "$sha256" "$package" | sha256sum --check --status 2>/dev/null; then
  curl --fail --location --retry 3 --output "$package" \
    "https://github.com/RemakeCode/sentinel/releases/download/v${version}/sentinel.pkg.tar.zst"
fi
printf '%s  %s\n' "$sha256" "$package" | sha256sum --check
[[ "${1:-}" == --verify-only ]] && exit 0
sudo pacman -U --needed --noconfirm "$package"
