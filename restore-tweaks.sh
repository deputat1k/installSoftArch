#!/usr/bin/env bash
# Restore the GNOME dconf snapshot made before running tweaks.sh.
set -Eeuo pipefail
[[ $EUID -ne 0 ]] || { echo 'Run without sudo.' >&2; exit 1; }
backup_dir="${1:-}"
[[ -d "$backup_dir" && -f "$backup_dir/wm-preferences.dconf" && -f "$backup_dir/shell.dconf" && -f "$backup_dir/enabled-extensions.txt" ]] || {
  echo 'Usage: bash restore-tweaks.sh ~/.local/share/installSoftArch/tweaks-backups/YYYYmmdd-HHMMSS' >&2
  exit 1
}
read -r -p 'Restore previous GNOME settings from this backup? [y/N] ' confirm
[[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 0
dconf load /org/gnome/desktop/wm/preferences/ < "$backup_dir/wm-preferences.dconf"
dconf load /org/gnome/shell/ < "$backup_dir/shell.dconf"
gsettings set org.gnome.shell enabled-extensions "$(cat "$backup_dir/enabled-extensions.txt")"
printf '%s\n' 'Previous GNOME settings restored. Log out and log back in.'
printf '%s\n' 'Installed system packages and extension files remain installed; this restores settings only.'