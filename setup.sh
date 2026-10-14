#!/usr/bin/env bash
set -Eeuo pipefail
dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
[[ $EUID -ne 0 ]] || { echo "Run as a regular user, not root." >&2; exit 1; }
bash "$dir/install.sh" "$@"
bash "$dir/power-boot.sh"
echo "Setup finished. Reboot manually to activate lid and GRUB settings."
