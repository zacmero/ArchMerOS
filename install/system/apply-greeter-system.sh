#!/usr/bin/env bash

set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  printf 'apply-greeter-system: run as root\n' >&2
  exit 1
fi

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
src_root="${repo_root}/vendor/sysc-greet"
system_share_root="/usr/local/share/archmeros/sysc-greet"
system_data_dir="${system_share_root}/share"
system_binary="/usr/local/bin/sysc-greet"
greetd_dir="/etc/greetd"
polkit_rule_path="/etc/polkit-1/rules.d/85-greeter.rules"
go_cache_root="/var/cache/archmeros-sysc-greet"
go_cache_dir="${go_cache_root}/gocache"
go_mod_cache_dir="${go_cache_root}/gomodcache"

pacman -S --needed --noconfirm greetd kitty

install -d "${system_data_dir}"
cp -a "${repo_root}/config/greetd/sysc-greet/share/." "${system_data_dir}/"

install -d "${go_cache_dir}" "${go_mod_cache_dir}"
(
  cd "${src_root}"
  export GOCACHE="${go_cache_dir}"
  export GOMODCACHE="${go_mod_cache_dir}"
  GOWORK=off go build \
    -buildvcs=false \
    -ldflags "-X main.dataDir=${system_data_dir}" \
    -o "${system_binary}" \
    ./cmd/sysc-greet
)
chmod 755 "${system_binary}"

install -Dm644 "${repo_root}/config/greetd/sysc-greet/kitty-greeter.conf" \
  "${greetd_dir}/kitty-greeter.conf"
install -Dm644 "${repo_root}/config/greetd/sysc-greet/hyprland-greeter-config.conf" \
  "${greetd_dir}/hyprland-greeter-config.conf"
install -Dm755 "${repo_root}/config/greetd/sysc-greet/archmeros-greeter-session.sh" \
  /usr/local/bin/archmeros-greeter-session
install -Dm755 "${repo_root}/config/greetd/sysc-greet/archmeros-start-hyprmero.sh" \
  /usr/local/bin/archmeros-start-hyprmero
install -Dm644 "${repo_root}/install/system/etc/greetd/config.toml" \
  "${greetd_dir}/config.toml"
install -Dm644 "${repo_root}/install/system/etc/polkit-1/rules.d/85-greeter.rules" \
  "${polkit_rule_path}"

install -d \
  /var/lib/greeter \
  /var/cache/sysc-greet \
  /var/lib/greeter/Pictures/wallpapers \
  /var/lib/greeter/.config/dconf \
  /var/lib/greeter/.cache \
  /var/lib/greeter/.local/state \
  /var/lib/greeter/.local/share
if ! id greeter >/dev/null 2>&1; then
  useradd -M -G video,render,input -s /usr/bin/nologin greeter
else
  usermod -aG video,render,input greeter || true
fi
chown -R greeter:greeter /var/lib/greeter /var/cache/sysc-greet
chmod 755 /var/lib/greeter

systemctl disable lightdm.service || true
systemctl enable greetd.service

printf 'archmeros greeter applied\n'
printf 'binary: %s\n' "${system_binary}"
printf 'data:   %s\n' "${system_data_dir}"
printf 'dm:     greetd enabled, lightdm disabled\n'
