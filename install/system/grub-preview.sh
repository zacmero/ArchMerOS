#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
theme_dir="/boot/grub/themes/archmeros-80s"
grub_cfg_src="/boot/grub/grub.cfg"
preview_cfg="/tmp/archmeros-grub-preview.cfg"

if [[ ! -d "${theme_dir}" ]]; then
  printf 'grub-preview: theme directory not found: %s\n' "${theme_dir}" >&2
  exit 1
fi

sudo cp "${grub_cfg_src}" "${preview_cfg}"
sudo chown "${USER}:${USER}" "${preview_cfg}"

python3 - "${preview_cfg}" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = re.sub(r"(?m)^\s*search --no-floppy --fs-uuid --set=root .*\n", "", text)
path.write_text(text, encoding="utf-8")
PY

grub2-theme-preview "${theme_dir}" --grub-cfg "${preview_cfg}" --timeout -1 --no-kvm --display gtk
