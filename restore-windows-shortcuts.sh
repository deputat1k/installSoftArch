#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -ne 0 ]] || { echo 'Run as regular user' >&2; exit 1; }
latest="$HOME/.local/share/installSoftArch/tweaks-backups/latest-shortcuts.txt"
dir="${1:-}"
if [[ -z "$dir" ]]; then
  [[ -r "$latest" ]] || { echo 'Backup path missing' >&2; exit 1; }
  dir="$(cat "$latest")"
fi
[[ -d "$dir" ]] || { echo "Backup directory does not exist: $dir" >&2; exit 1; }
read -r -p "Restore original Windows-like shortcut settings from $dir? [y/N] " answer
[[ "$answer" == y || "$answer" == Y ]] || exit 0
for entry in 'wm:org/gnome/desktop/wm/keybindings' 'shell:org/gnome/shell/keybindings' 'mutter:org/gnome/mutter/keybindings' 'media:org/gnome/settings-daemon/plugins/media-keys'; do
  file="${entry%%:*}"
  dconfpath="${entry#*:}"
  [[ -f "$dir/$file.dconf" ]] || { echo "Missing: $dir/$file.dconf" >&2; exit 1; }
  dconf load "/$dconfpath/" < "$dir/$file.dconf"
done
echo "Keyboard shortcuts restored. Previous GNOME extension and application settings unchanged."
