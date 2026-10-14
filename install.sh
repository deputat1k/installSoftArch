#!/usr/bin/env bash
# Arch Linux + GNOME / ASUS TUF F15 i5-12500H + Intel + RTX 3050 Laptop.
# Post-install apps, graphics, locale and desktop settings. Does not touch disks/bootloader.
set -Eeuo pipefail

AUTO=0; NO_NVIDIA=0; NO_GHELPER=0; NO_FLATPAK=0
for arg in "$@"; do
  case "$arg" in
    --yes) AUTO=1 ;;
    --no-nvidia) NO_NVIDIA=1 ;;
    --no-ghelper) NO_GHELPER=1 ;;
    --no-flatpak) NO_FLATPAK=1 ;;
    -h|--help)
      cat <<'HELP'
Usage: bash install.sh [--yes] [--no-nvidia] [--no-ghelper] [--no-flatpak]
  --yes           Allow pacman to confirm package transactions automatically.
  --no-nvidia     Skip NVIDIA driver packages (use if already managing GPU yourself).
  --no-ghelper    Skip G-Helper Linux AppImage installation.
  --no-flatpak    Skip Brave/Chrome Flatpaks.
Run as a regular user after login to a working Arch Linux GNOME session.
HELP
      exit 0 ;;
    *) printf 'Unknown option: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

[[ $EUID -ne 0 ]] || { echo 'Run as a normal user, NOT with sudo.' >&2; exit 1; }
[[ -r /etc/os-release ]] || { echo '/etc/os-release missing' >&2; exit 1; }
# shellcheck source=/dev/null
source /etc/os-release
[[ ${ID:-} == arch ]] || { echo 'Only Arch Linux is supported (not Ubuntu/Fedora).' >&2; exit 1; }
command -v pacman >/dev/null || { echo 'pacman missing' >&2; exit 1; }
command -v gsettings >/dev/null || { echo 'GNOME gsettings missing' >&2; exit 1; }
case "${XDG_CURRENT_DESKTOP:-}" in
  *GNOME*|*gnome*) ;;
  *) echo 'Log into GNOME first (not KDE/Xfce/TTY).' >&2; exit 1 ;;
esac
[[ -n ${DBUS_SESSION_BUS_ADDRESS:-} ]] || { echo 'No GNOME user D-Bus session.' >&2; exit 1; }

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/installSoftArch"
mkdir -p "$state_dir"
log_file="$state_dir/arch-gnome-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$log_file") 2>&1
log() { printf '\n==> %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
trap 'code=$?; printf "[ERROR] line %s, code %s. Log: %s\n" "$LINENO" "$code" "$log_file" >&2; exit "$code"' ERR

if [[ $AUTO -ne 1 ]]; then
  echo 'This changes installed packages, GNOME keyboard/shortcuts and system locale.'
  echo 'It does NOT partition/format disks, modify GRUB/EFI/fstab or force a reboot.'
  read -r -p 'Proceed? [y/N]: ' answer
  [[ $answer == [Yy] || $answer == [Yy][Ee][Ss] ]] || exit 0
fi
sudo -v

flags=()
[[ $AUTO == 1 ]] && flags+=(--noconfirm)

log 'Enable [multilib] (required for Steam and NVIDIA 32-bit libraries)'
if ! pacman-conf --repo-list | grep -qx multilib; then
  backup="/etc/pacman.conf.before-installSoftArch-$(date +%Y%m%d-%H%M%S)"
  sudo cp -a /etc/pacman.conf "$backup"
  sudo sed -i -E '/^[[:space:]]*#[[:space:]]*\[multilib\][[:space:]]*$/,/^[[:space:]]*#[[:space:]]*Include[[:space:]]*=[[:space:]]*\/etc\/pacman.d\/mirrorlist[[:space:]]*$/ s/^[[:space:]]*#[[:space:]]*//' /etc/pacman.conf
  if ! pacman-conf --repo-list | grep -qx multilib; then
    echo "Could not enable multilib. Restore/review $backup manually." >&2
    exit 1
  fi
fi
log 'Full Arch Linux update'
sudo pacman -Syu "${flags[@]}"

log 'Core tools, Intel graphics, Vulkan, gaming and original apps'
packages=(
  base-devel git curl wget jq unzip xdg-utils libnotify python
  pciutils usbutils linux-firmware intel-ucode sof-firmware
  bluez bluez-utils
  mesa lib32-mesa vulkan-intel lib32-vulkan-intel
  vulkan-icd-loader lib32-vulkan-icd-loader
  libva lib32-libva intel-media-driver libva-utils mesa-utils vulkan-tools
  firefox telegram-desktop steam obs-studio discord
  mangohud lib32-mangohud
  wine winetricks vlc mpv
  gnome-tweaks dconf-editor flatpak fuse2
)
# Abort on a missing official package instead of falsely claiming success.
sudo pacman -S --needed "${flags[@]}" "${packages[@]}"
if systemctl list-unit-files bluetooth.service --no-legend 2>/dev/null | grep -q '^bluetooth.service'; then
  sudo systemctl enable --now bluetooth.service || warn 'Bluetooth service could not start'
fi

if [[ $NO_NVIDIA == 0 ]] && lspci -nn | grep -qi NVIDIA; then
  log 'NVIDIA hybrid graphics: PRIME and 32-bit userspace'
  existing_modules=(nvidia nvidia-dkms nvidia-lts nvidia-open nvidia-open-dkms nvidia-open-lts)
  found=0
  for pkg in "${existing_modules[@]}"; do
    if pacman -Qq "$pkg" >/dev/null 2>&1; then
      log "Existing NVIDIA kernel package: $pkg (preserving it)"
      found=1
      break
    fi
  done
  if [[ $found == 0 ]]; then
    log 'Install NVIDIA open DKMS module for RTX 3050 (Ampere)'
    kernels=()
    for pair in 'linux:linux-headers' 'linux-lts:linux-lts-headers' 'linux-zen:linux-zen-headers' 'linux-hardened:linux-hardened-headers'; do
      kernel=${pair%%:*}; headers=${pair#*:}
      if pacman -Qq "$kernel" >/dev/null 2>&1; then kernels+=("$headers"); fi
    done
    if (("${#kernels[@]}" == 0)); then
      warn 'Unknown kernel: not installing NVIDIA kernel module automatically.'
    else
      sudo pacman -S --needed "${flags[@]}" "${kernels[@]}" dkms nvidia-open-dkms nvidia-utils
    fi
  fi
  # PRIME and 32-bit Vulkan, required for many Steam/Proton titles.
  if pacman -Qq nvidia-utils >/dev/null 2>&1; then
    sudo pacman -S --needed "${flags[@]}" nvidia-prime nvidia-settings lib32-nvidia-utils
  else
    warn 'nvidia-utils absent. Check driver installation before enabling 32-bit NVIDIA support.'
  fi
  warn 'NVIDIA changes need a reboot. Verify with nvidia-smi and prime-run glxinfo -B.'
else
  log 'NVIDIA driver step skipped (GPU not detected or --no-nvidia)'
fi

log 'US + Ukrainian locale and GNOME Alt+Shift layout switching'
for locale in en_US.UTF-8 uk_UA.UTF-8; do
  if grep -Eq "^[#[:space:]]*${locale}[[:space:]]+UTF-8[[:space:]]*$" /etc/locale.gen; then
    sudo sed -i -E "s/^[#[:space:]]*(${locale}[[:space:]]+UTF-8)[[:space:]]*$/\1/" /etc/locale.gen
  fi
done
sudo locale-gen
sudo localectl set-locale LANG=en_US.UTF-8
sudo timedatectl set-timezone Europe/Kyiv
if gsettings writable org.gnome.desktop.input-sources sources | grep -qx true; then
  gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'ua')]"
  gsettings set org.gnome.desktop.input-sources xkb-options "['grp:alt_shift_toggle']"
else
  warn 'GNOME keyboard sources are managed externally; change layout in Settings.'
fi

log 'Random wallpaper via Super+W; keep existing GNOME custom shortcuts'
mkdir -p "$HOME/.local/bin" "$HOME/Pictures/Wallpaper"
cat > "$HOME/.local/bin/random-wallpaper-gnome" <<'WALL'
#!/usr/bin/env bash
set -Eeuo pipefail
folder="$HOME/Pictures/Wallpaper"
mapfile -d '' -t files < <(find "$folder" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -print0)
if (("${#files[@]}" == 0)); then
  command -v notify-send >/dev/null && notify-send 'Wallpaper' 'Add photos to ~/Pictures/Wallpaper'
  exit 0
fi
chosen="${files[RANDOM % ${#files[@]}]}"
uri="$(python -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve().as_uri())' "$chosen")"
gsettings set org.gnome.desktop.background picture-uri "$uri"
gsettings set org.gnome.desktop.background picture-uri-dark "$uri"
command -v notify-send >/dev/null && notify-send 'Wallpaper changed' "$(basename "$chosen")" || true
WALL
chmod +x "$HOME/.local/bin/random-wallpaper-gnome"
python - "$HOME/.local/bin/random-wallpaper-gnome" <<'PY'
import ast
import subprocess
import sys

schema = 'org.gnome.settings-daemon.plugins.media-keys'
path = '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/random-wallpaper/'
custom = 'org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:' + path
cmd = sys.argv[1]
raw = subprocess.check_output(['gsettings', 'get', schema, 'custom-keybindings'], text=True).strip()
if raw.startswith('@as '):
    raw = raw[4:]
try:
    entries = ast.literal_eval(raw)
except (ValueError, SyntaxError) as exc:
    raise SystemExit(f'Cannot safely read existing shortcuts: {raw!r}; {exc}')
if not isinstance(entries, list) or not all(isinstance(x, str) for x in entries):
    raise SystemExit('Invalid GNOME shortcut list; preserving existing settings')
if path not in entries:
    entries.append(path)
    subprocess.run(['gsettings', 'set', schema, 'custom-keybindings', str(entries)], check=True)
for key, val in [('name', 'Random Wallpaper'), ('command', cmd), ('binding', '<Super>w')]:
    subprocess.run(['gsettings', 'set', custom, key, val], check=True)
PY

if [[ $NO_FLATPAK == 0 ]]; then
  log 'Brave and Google Chrome Flatpaks (community Flathub builds)'
  if flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo; then
    for app in com.brave.Browser com.google.Chrome; do
      if flatpak info --user "$app" >/dev/null 2>&1; then
        log "Already installed: $app"
      elif flatpak install --user --noninteractive -y flathub "$app"; then
        log "Installed: $app"
      else
        warn "Flatpak install failed: $app"
      fi
    done
  else
    warn 'Flathub unavailable: Brave/Chrome not installed'
  fi
fi

if [[ $NO_GHELPER == 0 ]]; then
  log 'G-Helper Linux for ASUS: download verified upstream AppImage and udev rules'
  temp_dir="$(mktemp -d)"
  if curl -fsSL --retry 2 --max-time 45 'https://api.github.com/repos/utajum/g-helper-linux/releases/latest' -o "$temp_dir/release.json"; then
    for asset_name in GHelper-x86_64.AppImage 90-ghelper.rules; do
      asset_url="$(jq -r --arg name "$asset_name" '.assets[] | select(.name==$name) | .browser_download_url' "$temp_dir/release.json" | head -n1)"
      digest="$(jq -r --arg name "$asset_name" '.assets[] | select(.name==$name) | .digest // empty' "$temp_dir/release.json" | head -n1)"
      [[ "$digest" == sha256:* && "$asset_url" == https://github.com/utajum/g-helper-linux/releases/download/* ]] || { warn "$asset_name: missing trusted release checksum/URL"; continue; }
      if ! curl -fL --retry 2 --max-time 300 "$asset_url" -o "$temp_dir/$asset_name"; then
        warn "Download failed: $asset_name"; continue
      fi
      if ! printf '%s  %s\n' "${digest#sha256:}" "$temp_dir/$asset_name" | sha256sum --check --status; then
        warn "SHA256 failed: $asset_name. Not installing."; continue
      fi
      if [[ "$asset_name" == GHelper-x86_64.AppImage ]]; then
        mkdir -p "$HOME/.local/opt/ghelper" "$HOME/.local/share/applications"
        install -m755 "$temp_dir/$asset_name" "$HOME/.local/opt/ghelper/GHelper-x86_64.AppImage"
        cat > "$HOME/.local/share/applications/ghelper-linux.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=G-Helper Linux
Exec=$HOME/.local/opt/ghelper/GHelper-x86_64.AppImage
Icon=utilities-system-monitor
Categories=System;Settings;
Terminal=false
DESKTOP
      else
        sudo install -m644 "$temp_dir/$asset_name" /etc/udev/rules.d/90-ghelper.rules
        sudo udevadm control --reload-rules
      fi
      log "Verified and installed: $asset_name"
    done
  else
    warn 'GitHub release API not available; skipping G-Helper'
  fi
  rm -rf -- "$temp_dir"
fi

if [[ -f "$(dirname "${BASH_SOURCE[0]}")/doctor.sh" ]]; then
  log 'Read-only system check'
  bash "$(dirname "${BASH_SOURCE[0]}")/doctor.sh" || warn 'Diagnostics flagged some items'
fi

log "Finished. Log: $log_file"
printf '%s\n' 'Reboot manually, then check NVIDIA, Wi-Fi, Bluetooth, sound and Steam.'
printf '%s\n' 'Steam: log in, then enable Compatibility / Proton Experimental as needed.'
printf '%s\n' 'No disk, GRUB, EFI, MUX, lid-power or automatic reboot changes were made.'
