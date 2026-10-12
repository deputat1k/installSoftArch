#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID != 0 ]] || { echo "Run as a normal user, not sudo"; exit 1; }
command -v xfconf-query >/dev/null || { echo "Install/login to Xfce first"; exit 1; }
case "${XDG_CURRENT_DESKTOP:-}" in *XFCE*|*Xfce*|*xfce*) ;; *) echo "Please log into Xfce"; exit 1;; esac
args=("$@")
AUTO=0; SKIP_NVIDIA=0; SKIP_GHELPER=0
for a in "${args[@]}"; do case "$a" in --yes) AUTO=1;; --skip-nvidia) SKIP_NVIDIA=1;; --skip-ghelper) SKIP_GHELPER=1;; *) echo "Unknown option $a"; exit 2;; esac; done
mkdir -p "$HOME/.local/state/installSoftArch"
logfile="$HOME/.local/state/installSoftArch/SYSTEM-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$logfile") 2>&1
trap 'rc=$?; echo "ERROR line $LINENO ($rc). Log: $logfile"; exit "$rc"' ERR
echo "This script will NOT change disks, GRUB, EFI, or Windows."
sudo -v
flags=(); [[ $AUTO == 1 ]] && flags+=(--noconfirm)
if ! pacman-conf --repo-list | grep -qx multilib; then
  sudo cp -n /etc/pacman.conf /etc/pacman.conf.before-installSoftArch
  sudo sed -i '/^#\[multilib\]$/,/^#Include = \/etc\/pacman.d\/mirrorlist$/ s/^#//' /etc/pacman.conf
  pacman-conf --repo-list | grep -qx multilib || { echo "Could not enable multilib; fix pacman.conf first"; exit 1; }
fi
sudo pacman -Syu "${flags[@]}"
packages=(base-devel git curl wget jq unzip zip xdg-utils libnotify pciutils
firefox telegram-desktop steam obs-studio discord
mesa lib32-mesa vulkan-intel lib32-vulkan-intel vulkan-icd-loader lib32-vulkan-icd-loader
libva lib32-libva intel-media-driver nvidia-prime mesa-utils vulkan-tools
linux-firmware cups avahi ipp-usb system-config-printer flatpak fuse2)
available=()
for p in "${packages[@]}"; do
  if pacman -Si "$p" >/dev/null 2>&1; then available+=("$p"); else echo "SKIP unavailable: $p"; fi
done
sudo pacman -S --needed "${flags[@]}" "${available[@]}"

# Brave from Flathub instead of running an AUR build unattended
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo &&
 flatpak install --user -y --noninteractive flathub com.brave.Browser || echo "WARNING: Brave not installed"

for lang in en_US.UTF-8 uk_UA.UTF-8; do
  sudo sed -i "s/^#${lang} UTF-8$/${lang} UTF-8/" /etc/locale.gen
done
sudo locale-gen
sudo localectl set-locale LANG=en_US.UTF-8
sudo timedatectl set-timezone Europe/Kyiv
setxf() {
  if xfconf-query -c "$1" -p "$2" >/dev/null 2>&1; then
    xfconf-query -c "$1" -p "$2" -s "$4"
  else
    xfconf-query -c "$1" -p "$2" -n -t "$3" -s "$4"
  fi
}
setxf keyboard-layout /Default/XkbDisable bool false
setxf keyboard-layout /Default/XkbLayout string 'us,ua'
setxf keyboard-layout /Default/XkbOptions string 'grp:alt_shift_toggle'

mkdir -p "$HOME/Pictures/Wallpaper" "$HOME/.local/bin"
cat > "$HOME/.local/bin/random-wallpaper-xfce" <<'WALL'
#!/usr/bin/env bash
set -Eeuo pipefail
folder="$HOME/Pictures/Wallpaper"
mapfile -d '' -t photos < <(find "$folder" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print0)
if (("${#photos[@]}" == 0)); then echo "Add wallpapers to $folder"; exit 0; fi
photo="${photos[RANDOM % ${#photos[@]}]}"
while read -r prop; do
  case "$prop" in */last-image|*/image-path) xfconf-query -c xfce4-desktop -p "$prop" -s "$photo";; esac
done < <(xfconf-query -c xfce4-desktop -l)
WALL
chmod +x "$HOME/.local/bin/random-wallpaper-xfce"
key='/commands/custom/<Super>w'
if ! xfconf-query -c xfce4-keyboard-shortcuts -p "$key" >/dev/null 2>&1; then
  xfconf-query -c xfce4-keyboard-shortcuts -p "$key" -n -t string -s "$HOME/.local/bin/random-wallpaper-xfce"
fi
for svc in cups.service avahi-daemon.service; do
 if systemctl list-unit-files "$svc" --no-legend 2>/dev/null | grep -q "^$svc"; then
   sudo systemctl enable --now "$svc" || echo "WARNING service $svc failed"
 fi
done
if [[ $SKIP_NVIDIA == 0 ]] && lspci | grep -qi NVIDIA; then
 if command -v nvidia-smi >/dev/null && nvidia-smi >/dev/null 2>&1; then
  echo "NVIDIA already works"
  sudo pacman -S --needed "${flags[@]}" lib32-nvidia-utils || echo "WARNING 32-bit NVIDIA support missing"
 elif command -v nvidia-inst >/dev/null; then
  if nvidia-inst --test --prime --32; then
   sudo nvidia-inst --prime --32 || echo "WARNING NVIDIA install failed; review output"
  else echo "WARNING NVIDIA test failed; not changing driver"; fi
 else echo "WARNING nvidia-inst missing; check NVIDIA manually"; fi
fi
if [[ $SKIP_GHELPER == 0 ]]; then
  echo "Installing G-Helper from latest GitHub release; SHA256 verification required"
  meta="$(mktemp)"; asset="$(mktemp)"; rules="$(mktemp)"
  if curl -fsSL --max-time 60 https://api.github.com/repos/utajum/g-helper-linux/releases/latest -o "$meta"; then
    url="$(jq -r '.assets[] | select(.name=="GHelper-x86_64.AppImage") | .browser_download_url' "$meta" | head -1)"
    sha="$(jq -r '.assets[] | select(.name=="GHelper-x86_64.AppImage") | .digest // empty' "$meta" | head -1)"
    rulesurl="$(jq -r '.assets[] | select(.name=="90-ghelper.rules") | .browser_download_url' "$meta" | head -1)"
    rulessha="$(jq -r '.assets[] | select(.name=="90-ghelper.rules") | .digest // empty' "$meta" | head -1)"
    if [[ "$sha" == sha256:* && -n "$url" ]] && curl -fsSL --max-time 300 "$url" -o "$asset" && printf '%s  %s\n' "${sha#sha256:}" "$asset" | sha256sum -c -; then
      mkdir -p "$HOME/.local/opt/ghelper" "$HOME/.local/share/applications"
      install -m755 "$asset" "$HOME/.local/opt/ghelper/GHelper-x86_64.AppImage"
      cat > "$HOME/.local/share/applications/ghelper-linux.desktop" <<ENTRY
[Desktop Entry]
Type=Application
Name=G-Helper Linux
Exec=$HOME/.local/opt/ghelper/GHelper-x86_64.AppImage
Icon=utilities-system-monitor
Categories=System;Settings;
Terminal=false
ENTRY
      if [[ "$rulessha" == sha256:* && -n "$rulesurl" ]] &&
        curl -fsSL --max-time 90 "$rulesurl" -o "$rules" &&
        printf '%s  %s\n' "${rulessha#sha256:}" "$rules" | sha256sum -c -; then
          sudo install -m644 "$rules" /etc/udev/rules.d/90-ghelper.rules
          sudo udevadm control --reload-rules
      else echo "WARNING G-Helper rules not verified/installed"; fi
    else echo "WARNING G-Helper AppImage verification/download failed"; fi
  else echo "WARNING G-Helper release unavailable"; fi
  rm -f "$meta" "$asset" "$rules"
fi
echo "Finished. Check NVIDIA after reboot: nvidia-smi"
echo "Choose Proton Experimental from Steam after account login."
echo "Log: $logfile"
