#!/usr/bin/env bash
# Kali-Dark theme from official upstream; user-level assets only.
set -Eeuo pipefail
[[ $EUID -ne 0 ]] || { echo "Run as regular user." >&2; exit 1; }
command -v git >/dev/null || { echo "Install git first." >&2; exit 1; }
command -v xfconf-query >/dev/null || { echo "Install Xfce first." >&2; exit 1; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git clone --quiet --depth=1 --branch kali/master \
  https://gitlab.com/kalilinux/packages/kali-themes.git "$tmp/kali-themes"
src="$tmp/kali-themes/share/themes/Kali-Dark"
[[ -d "$src" ]] || { echo "Upstream Kali-Dark path changed; leaving system unchanged." >&2; exit 1; }
mkdir -p "$HOME/.local/share/themes" "$HOME/.local/share/icons"
if [[ ! -e "$HOME/.local/share/themes/Kali-Dark" ]]; then
  cp -a "$src" "$HOME/.local/share/themes/Kali-Dark"
fi
icons="$tmp/kali-themes/share/icons/Flat-Remix-Blue-Dark"
if [[ -d "$icons" && ! -e "$HOME/.local/share/icons/Flat-Remix-Blue-Dark" ]]; then
  cp -a "$icons" "$HOME/.local/share/icons/Flat-Remix-Blue-Dark"
fi
xfset() {
  local channel="$1" key="$2" val="$3"
  if xfconf-query -c "$channel" -p "$key" >/dev/null 2>&1; then
    xfconf-query -c "$channel" -p "$key" -s "$val"
  else
    xfconf-query -c "$channel" -p "$key" -n -t string -s "$val"
  fi
}
xfset xsettings /Net/ThemeName Kali-Dark
if [[ -d "$HOME/.local/share/themes/Kali-Dark/xfwm4" ]]; then
  xfset xfwm4 /general/theme Kali-Dark
fi
if [[ -d "$HOME/.local/share/icons/Flat-Remix-Blue-Dark" ]]; then
  xfset xsettings /Net/IconThemeName Flat-Remix-Blue-Dark
else
  xfset xsettings /Net/IconThemeName Papirus-Dark
fi
echo "Kali-Dark applied. Panel layout and some icon dependencies may require manual changes."
