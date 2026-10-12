#!/usr/bin/env bash
# Read-only Kali Xfce appearance check
set -u
for setting in 'xsettings /Net/ThemeName' 'xsettings /Net/IconThemeName' 'xfwm4 /general/theme'; do
  read -r channel property <<< "$setting"
  printf '%s: ' "$property"
  xfconf-query -c "$channel" -p "$property" 2>/dev/null || echo 'missing'
done
[[ -d "$HOME/.local/share/themes/Kali-Dark" ]] && echo '[OK] Kali-Dark assets' || echo '[CHECK] Kali-Dark missing'
[[ -f "$HOME/.local/share/backgrounds/kali-actiniaria.svg" ]] && echo '[OK] wallpaper' || echo '[CHECK] wallpaper missing'
command -v xfce4-panel-profiles >/dev/null && echo '[OK] Panel Profiles' || echo '[CHECK] Panel Profiles missing'
echo 'Note: working panel applets require a real Xfce session check.'
