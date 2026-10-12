#!/usr/bin/env bash
# Read-only post-install diagnostic. Never edits system configuration.
set -u
ok=0; warning=0
good() { printf '[OK] %s\n' "$*"; ok=$((ok+1)); }
note() { printf '[CHECK] %s\n' "$*"; warning=$((warning+1)); }
for cmd in git steam lutris gamemoderun mangohud xfconf-query; do
  command -v "$cmd" >/dev/null && good "$cmd installed" || note "$cmd missing (or no binary exposed)"
done
theme="$(xfconf-query -c xsettings -p /Net/ThemeName 2>/dev/null || true)"
case "$theme" in Kali-Dark|Materia-dark) good "Theme $theme" ;; *) note "Theme not applied ($theme)" ;; esac
layout="$(xfconf-query -c keyboard-layout -p /Default/XkbLayout 2>/dev/null || true)"
[[ "$layout" == us,ua ]] && good "Keyboard us,ua" || note "Keyboard layout: $layout"
if lspci 2>/dev/null | grep -iq NVIDIA; then
  if command -v nvidia-smi >/dev/null && nvidia-smi >/dev/null 2>&1; then
    good "NVIDIA driver responding"
  else
    note "NVIDIA detected; nvidia-smi not working (manual driver verification needed)"
  fi
fi
if mountpoint -q /mnt/games; then good "/mnt/games mounted"; else note "/mnt/games not mounted; Steam storage setup remains manual"; fi
if swapon --noheadings --show=NAME 2>/dev/null | grep -q '^/dev/zram'; then
  good "zram active"
elif [[ -f /etc/systemd/zram-generator.conf ]]; then
  note "zram configured; reboot to activate"
else
  note "zram not configured"
fi
printf '\nDiagnostics: %s OK, %s items to check. No changes made.\n' "$ok" "$warning"
exit 0
