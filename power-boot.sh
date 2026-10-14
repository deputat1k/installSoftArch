#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -ne 0 ]] || { echo "Run as normal user" >&2; exit 1; }
command -v gsettings >/dev/null || { echo "GNOME is required" >&2; exit 1; }
sudo -v

# Stay awake while laptop is open, even on battery.
gsettings set org.gnome.desktop.session idle-delay 0
gsettings set org.gnome.settings-daemon.plugins.power idle-dim false
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0

# Ordinary suspend on lid close. Apply after reboot; GNOME may inhibit in edge cases.
sudo install -d -m755 /etc/systemd/logind.conf.d
printf '[Login]\nHandleLidSwitch=suspend\nHandleLidSwitchExternalPower=suspend\nHandleLidSwitchDocked=suspend\n' |
  sudo tee /etc/systemd/logind.conf.d/90-installSoftArch-lid.conf >/dev/null

# Keep GRUB for recovery, but boot Arch without showing the menu.
if [[ -f /etc/default/grub && -f /boot/grub/grub.cfg ]] &&
   command -v grub-mkconfig >/dev/null 2>&1; then
  backup="/etc/default/grub.installSoftArch-backup-$(date +%Y%m%d-%H%M%S)"
  sudo cp -a /etc/default/grub "$backup"
  sudo sed -i -E     -e 's/^#?GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/'     -e 's/^#?GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/'     /etc/default/grub
  grep -q '^GRUB_TIMEOUT_STYLE=' /etc/default/grub ||
    printf 'GRUB_TIMEOUT_STYLE=hidden\n' | sudo tee -a /etc/default/grub >/dev/null
  grep -q '^GRUB_TIMEOUT=' /etc/default/grub ||
    printf 'GRUB_TIMEOUT=1\n' | sudo tee -a /etc/default/grub >/dev/null
  if ! sudo grub-mkconfig -o /boot/grub/grub.cfg; then
    sudo cp -a "$backup" /etc/default/grub
    sudo grub-mkconfig -o /boot/grub/grub.cfg || true
    echo "GRUB regenerate failed. Inspect config before reboot." >&2
    exit 1
  fi
  echo "GRUB now hidden (1 second). Esc or Shift during boot opens the menu."
else
  echo "GRUB was not detected; skipping bootloader settings."
fi

echo "Automatic idle sleep disabled; closing the lid requests suspend."
echo "Reboot to activate lid/GRUB settings, then test waking from sleep."
