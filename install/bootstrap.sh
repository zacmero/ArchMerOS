#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cat <<EOF
ArchMerOS bootstrap plan

Repository: ${repo_root}

This script is intentionally non-destructive at this stage.
It does not install packages yet.

Planned actions:
- install package manifests via install/packages/install.sh
- verify required binaries
- optionally install Hyprland stack later
- deploy tracked configs by symlink via install/link.sh
- apply tracked system defaults later via install/system/apply-system.sh

Current status:
- bootstrap scaffolding only
EOF
