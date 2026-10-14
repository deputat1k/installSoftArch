#!/usr/bin/env bash
# Read-only diagnostics for Arch + GNOME setup.
set -u
ok=0; warn_count=0
okmsg() { printf '[OK] %s\n' "$1"; ok=$((ok+1)); }
warnmsg() { printf '[CHECK] %s\n' "$1"; warn_count=$((warn_count+1)); }
for cmd in gsettings steam gamemoderun mangohud glxinfo vulkaninfo; do
  if command -v "$cmd" >/dev/null 2>&1; then okmsg "$cmd"; else warnmsg "$cmd unavailable"; fi
done
if lspci 2>/dev/null | grep -qi NVIDIA; then
  if command -v nvidia-smi >/dev/null && nvidia-smi >/dev/null 2>&1; then
    okmsg 'NVIDIA responds to nvidia-smi'
  else
    warnmsg 'NVIDIA detected, but nvidia-smi not ready. Reboot, then review the driver.'
  fi
  if command -v prime-run >/dev/null; then okmsg 'prime-run'; else warnmsg 'prime-run missing'; fi
fi
if gsettings get org.gnome.desktop.input-sources sources 2>/dev/null | grep -q "'ua'"; then
  okmsg 'Ukrainian GNOME layout configured'
else warnmsg 'Ukrainian GNOME layout not detected'; fi
if [[ -x "$HOME/.local/opt/ghelper/GHelper-x86_64.AppImage" ]]; then
  okmsg 'G-Helper AppImage installed'
else warnmsg 'G-Helper not installed'; fi
printf '\nDiagnostics: %s OK, %s items to review.\n' "$ok" "$warn_count"