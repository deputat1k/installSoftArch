#!/usr/bin/env bash
# Compatibility wrapper. Theme only. Use SYSTEM branch for software/drivers.
set -Eeuo pipefail
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$here/apply-kali-look.sh" "$@"
