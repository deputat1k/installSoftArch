#!/usr/bin/env bash
# Kali look only: themes, panel, wallpaper. No system driver/software bootstrap.
set -Eeuo pipefail
[[ $EUID != 0 ]] || { echo "Run without sudo"; exit 1; }
command -v xfconf-query >/dev/null || { echo "Please install and log into Xfce first"; exit 1; }
case "${XDG_CURRENT_DESKTOP:-}" in *XFCE*|*Xfce*|*xfce*) ;; *) echo "Run from Xfce"; exit 1;; esac
[[ -n "${DISPLAY:-}" ]] || { echo "X11 session required"; exit 1; }
logdir="$HOME/.local/state/installSoftArch"
backup="$HOME/.local/share/installSoftArch/xfce-backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup" "$logdir"
log="$logdir/XFCE-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$log") 2>&1
trap 'rc=$?; echo "Theme setup error line $LINENO ($rc). Log: $log"; exit "$rc"' ERR
sudo -v
pkgs=(git curl xfce4-panel-profiles xfce4-whiskermenu-plugin xfce4-genmon-plugin
xfce4-cpugraph-plugin xfce4-netload-plugin xfce4-pulseaudio-plugin
xfce4-clipman-plugin xfce4-notifyd xfce4-terminal xfce4-screenshooter
xfce4-power-manager papirus-icon-theme librsvg)
available=()
for p in "${pkgs[@]}"; do pacman -Si "$p" >/dev/null 2>&1 && available+=("$p") || echo "WARN unavailable $p"; done
sudo pacman -Syu --needed --noconfirm "${available[@]}"

panel_ok=0
if xfce4-panel-profiles save "$backup/panel-original.tar.bz2"; then panel_ok=1
else echo "WARN panel backup failed; preserving panel"; fi
if [[ -d "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml" ]]; then
  cp -a "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml" "$backup/"
fi
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git clone --depth 1 --branch kali/master \
  https://gitlab.com/kalilinux/packages/kali-themes.git "$tmp/kali-themes"
src="$tmp/kali-themes/share/themes/Kali-Dark"
[[ -d "$src" ]] || { echo "Kali-Dark not in upstream repo"; exit 1; }
mkdir -p "$HOME/.local/share/themes" "$HOME/.local/share/icons" "$HOME/.local/share/backgrounds"
if [[ -d "$HOME/.local/share/themes/Kali-Dark" ]]; then
  cp -a "$HOME/.local/share/themes/Kali-Dark" "$backup/Kali-Dark-old"
  rm -rf "$HOME/.local/share/themes/Kali-Dark"
fi
cp -a "$src" "$HOME/.local/share/themes/Kali-Dark"
icons="$tmp/kali-themes/share/icons/Flat-Remix-Blue-Dark"
icon_theme="Papirus-Dark"
if [[ -d "$icons" ]]; then
  if [[ -d "$HOME/.local/share/icons/Flat-Remix-Blue-Dark" ]]; then
    cp -a "$HOME/.local/share/icons/Flat-Remix-Blue-Dark" "$backup/Flat-Remix-old"
    rm -rf "$HOME/.local/share/icons/Flat-Remix-Blue-Dark"
  fi
  cp -a "$icons" "$HOME/.local/share/icons/Flat-Remix-Blue-Dark"
  icon_theme=Flat-Remix-Blue-Dark
fi
setxf() {
 if xfconf-query -c "$1" -p "$2" >/dev/null 2>&1; then
  xfconf-query -c "$1" -p "$2" -s "$3"
 else xfconf-query -c "$1" -p "$2" -n -t string -s "$3"; fi
}
setxf xsettings /Net/ThemeName Kali-Dark
setxf xsettings /Net/IconThemeName "$icon_theme"
if [[ -d "$HOME/.local/share/themes/Kali-Dark/xfwm4" ]]; then
  setxf xfwm4 /general/theme Kali-Dark
fi
profile="$tmp/kali-themes/xfce-panel-profiles/Kali"
if [[ $panel_ok == 1 && -d "$profile" && -f "$profile/config.txt" ]]; then
  tar -cjf "$tmp/Kali-panel.tar.bz2" -C "$profile" .
  xfce4-panel-profiles load "$tmp/Kali-panel.tar.bz2" ||
    echo "WARN Kali panel import failed, restore backup: $backup/panel-original.tar.bz2"
else echo "WARN Kali panel profile incompatible/missing: see README"; fi
terminal="$tmp/kali-themes/etc/xdg/xfce4/terminal/terminalrc"
if [[ -f "$terminal" ]]; then
  mkdir -p "$HOME/.config/xfce4/terminal"
  if [[ -f "$HOME/.config/xfce4/terminal/terminalrc" ]]; then
   cp "$HOME/.config/xfce4/terminal/terminalrc" "$backup/terminalrc"
  fi
  cp "$terminal" "$HOME/.config/xfce4/terminal/terminalrc"
fi
wall="$HOME/.local/share/backgrounds/kali-actiniaria.svg"
if curl -fsSL --max-time 90 'https://gitlab.com/kalilinux/packages/kali-wallpapers/-/raw/kali/master/src/kali-actiniaria.svg' -o "$wall" &&
 head -c 256 "$wall" | grep -qi '<svg\|<?xml'; then
 while IFS= read -r prop; do
  case "$prop" in */last-image|*/image-path) xfconf-query -c xfce4-desktop -p "$prop" -s "$wall" || true;; esac
 done < <(xfconf-query -c xfce4-desktop -l)
else rm -f "$wall"; echo "WARN Kali wallpaper failed to download; set it manually"; fi
echo "Theme installed; actual panel/wallpaper dependent on Kali upstream layout."
echo "Backup: $backup"
echo "Log: $log"
echo "Log out and back in. Review README.md for manual panel plugin configuration."
