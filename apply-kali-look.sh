#!/usr/bin/env bash
# Optional visual theme only: copies GTK/Xfwm assets from official Kali sources.
# NEVER installs Kali APT repos, packages, scripts, or configuration wholesale.
set -Eeuo pipefail
[[ "$EUID" -ne 0 ]] || { echo 'Run as your normal user (without sudo).' >&2; exit 1; }
command -v git >/dev/null || { echo 'Install git first.' >&2; exit 1; }
command -v xfconf-query >/dev/null || { echo 'Run from an installed Xfce desktop.' >&2; exit 1; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
printf 'Cloning official Kali theme source (for static theme files only)...\n'
git clone --quiet --depth=1 --branch kali/master \
    https://gitlab.com/kalilinux/packages/kali-themes.git "$tmp/kali-themes"
source_theme="$tmp/kali-themes/share/themes/Kali-Dark"
[[ -d "$source_theme" ]] || { echo 'Kali-Dark theme not found: upstream structure changed.' >&2; exit 1; }
mkdir -p "$HOME/.local/share/themes" "$HOME/.local/share/icons"
# Do not erase/overwrite an existing Kali-Dark install without explicit action.
if [[ -e "$HOME/.local/share/themes/Kali-Dark" ]]; then
    echo 'Theme already exists; preserving it. Remove it manually to reinstall.' >&2
else
    cp -a "$source_theme" "$HOME/.local/share/themes/Kali-Dark"
fi
# Some Kali icon assets may depend on other themes: use Papirus-Dark as fallback.
icons="$tmp/kali-themes/share/icons/Flat-Remix-Blue-Dark"
if [[ -d "$icons" && ! -e "$HOME/.local/share/icons/Flat-Remix-Blue-Dark" ]]; then
    cp -a "$icons" "$HOME/.local/share/icons/Flat-Remix-Blue-Dark"
fi
setxf() {
    local channel="$1" name="$2" value="$3"
    if xfconf-query -c "$channel" -p "$name" >/dev/null 2>&1; then
        xfconf-query -c "$channel" -p "$name" -s "$value"
    else
        xfconf-query -c "$channel" -p "$name" -n -t string -s "$value"
    fi
}
setxf xsettings /Net/ThemeName Kali-Dark
if [[ -d "$HOME/.local/share/themes/Kali-Dark/xfwm4" ]]; then
    setxf xfwm4 /general/theme Kali-Dark
fi
if [[ -d "$HOME/.local/share/icons/Flat-Remix-Blue-Dark" ]]; then
    setxf xsettings /Net/IconThemeName Flat-Remix-Blue-Dark
else
    echo 'Original Flat-Remix icon theme not bundled at expected path; preserving current icons.'
fi
printf '\nKali-Dark applied. This is theme only, not the complete Kali panel configuration.\n'
printf 'You can customize Xfce panels via Settings > Panel.\n'
