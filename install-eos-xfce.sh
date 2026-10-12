#!/usr/bin/env bash
# EndeavourOS + Xfce desktop/gaming bootstrap. No disk/bootloader operations.
set -Eeuo pipefail
AUTO=0
DEV=0
NVIDIA_AUTO=0
for arg in "$@"; do
  case "$arg" in
    --yes) AUTO=1 ;;
    --dev) DEV=1 ;;
    --nvidia) NVIDIA_AUTO=1 ;;
    --help|-h) echo "Usage: bash install-eos-xfce.sh [--yes] [--dev] [--nvidia]"; exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done
[[ $EUID -ne 0 ]] || { echo "Run as a normal user, not via sudo." >&2; exit 1; }
command -v pacman >/dev/null || { echo "pacman not found" >&2; exit 1; }
command -v xfconf-query >/dev/null || { echo "Xfce is not installed" >&2; exit 1; }
case "${XDG_CURRENT_DESKTOP:-}" in *XFCE*|*Xfce*|*xfce*) ;; *)
 echo "Log in to Xfce first." >&2; exit 1 ;; esac
[[ -n "${DISPLAY:-}" ]] || { echo "Start an X11 Xfce session first." >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$HOME/.local/state/eos-xfce-setup"
LOG_FILE="$HOME/.local/state/eos-xfce-setup/setup-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1
log() { printf '\n==> %s\n' "$*"; }
warn() { printf '[WARNING] %s\n' "$*" >&2; }
trap 'rc=$?; printf "[ERROR] line %s, exit %s. Log: %s\n" "$LINENO" "$rc" "$LOG_FILE" >&2; exit "$rc"' ERR
log "Setup started; log: $LOG_FILE"
log "EFI, GRUB, Windows, fstab, disk partitioning and GPU BIOS modes are NEVER changed."
sudo -v
pacman_flags=()
[[ $AUTO == 1 ]] && pacman_flags+=(--noconfirm)

if ! pacman-conf --repo-list | grep -qx multilib; then
  log "Enable [multilib] for Steam / Proton"
  sudo cp -n /etc/pacman.conf /etc/pacman.conf.before-eos-xfce-setup
  sudo sed -i -E '/^[[:space:]]*#[[:space:]]*\[multilib\][[:space:]]*$/,/^[[:space:]]*#[[:space:]]*Include[[:space:]]*=[[:space:]]*\/etc\/pacman.d\/mirrorlist[[:space:]]*$/ s/^[[:space:]]*#[[:space:]]*//' /etc/pacman.conf
  pacman-conf --repo-list | grep -qx multilib || {
    echo "Cannot enable multilib automatically; inspect /etc/pacman.conf." >&2; exit 1;
  }
fi

log "Full system update"
sudo pacman -Syu "${pacman_flags[@]}"

packages=(
  git base-devel curl wget jq unzip zip xdg-utils
  firefox telegram-desktop discord obs-studio
  steam lutris wine winetricks gamemode lib32-gamemode
  mangohud lib32-mangohud mesa lib32-mesa
  vulkan-intel lib32-vulkan-intel vulkan-icd-loader lib32-vulkan-icd-loader
  nvidia-prime mesa-utils vulkan-tools
  xfce4-whiskermenu-plugin xfce4-clipman-plugin xfce4-screenshooter
  xfce4-taskmanager xfce4-power-manager xfce4-pulseaudio-plugin
  pavucontrol thunar-archive-plugin
  materia-gtk-theme papirus-icon-theme
  btop fastfetch gparted gvfs tumbler
  vlc mpv qbittorrent xarchiver
  cups system-config-printer avahi ipp-usb zram-generator
  python python-pip nodejs npm flatpak
)
if [[ $DEV == 1 ]]; then
  packages+=(jdk-openjdk maven php composer dotnet-sdk docker docker-compose)
fi
available=()
for pkg in "${packages[@]}"; do
  if pacman -Si "$pkg" >/dev/null 2>&1; then
    available+=("$pkg")
  else
    warn "Not found in enabled official repos; skipping: $pkg"
  fi
done
if ((${#available[@]})); then
  log "Installing ${#available[@]} packages"
  sudo pacman -S --needed "${pacman_flags[@]}" "${available[@]}"
fi

# Google Chrome and Brave, as Flatpaks: no unattended AUR PKGBUILD execution.
# Chrome on Flathub is community packaged (not Google-verified).
log "Installing Chrome and Brave via Flathub (per-user)"
if command -v flatpak >/dev/null; then
  if flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo; then
    for app in com.google.Chrome com.brave.Browser; do
      if flatpak info "$app" >/dev/null 2>&1; then
        log "$app already installed"
      elif flatpak install --user -y --noninteractive flathub "$app"; then
        log "$app installed"
      else
        warn "Failed to install $app; see log"
      fi
    done
  else
    warn "Could not add Flathub: Chrome and Brave skipped"
  fi
else
  warn "Flatpak unavailable: Chrome and Brave skipped"
fi

for svc in cups.service avahi-daemon.service; do
  if systemctl list-unit-files "$svc" --no-legend 2>/dev/null | grep -q "^$svc"; then
    sudo systemctl enable --now "$svc" || warn "Could not enable $svc"
  fi
done
if grep -Eq '^#[[:space:]]*uk_UA.UTF-8[[:space:]]+UTF-8$' /etc/locale.gen; then
  sudo sed -i -E 's/^#[[:space:]]*(uk_UA.UTF-8[[:space:]]+UTF-8)$/\1/' /etc/locale.gen
  sudo locale-gen
fi

xfset() {
  local channel="$1" prop="$2" type="$3" value="$4"
  if xfconf-query -c "$channel" -p "$prop" >/dev/null 2>&1; then
    xfconf-query -c "$channel" -p "$prop" -s "$value"
  else
    xfconf-query -c "$channel" -p "$prop" -n -t "$type" -s "$value"
  fi
}
log "Xfce keyboard: US + Ukrainian via Alt+Shift"
xfset keyboard-layout /Default/XkbDisable bool false || warn "Layout config failed"
xfset keyboard-layout /Default/XkbLayout string us,ua || warn "Layout config failed"
xfset keyboard-layout /Default/XkbOptions string grp:alt_shift_toggle || warn "Layout switch config failed"

log "Random wallpaper helper and Super+W (does not overwrite existing shortcut)"
mkdir -p "$HOME/.local/bin" "$HOME/Pictures/Wallpaper"
cat > "$HOME/.local/bin/random-wallpaper-xfce" <<'WALLPAPER'
#!/usr/bin/env bash
set -Eeuo pipefail
folder="$HOME/Pictures/Wallpaper"
mapfile -d '' -t photos < <(find "$folder" -maxdepth 1 -type f \
  \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -print0)
(("${#photos[@]}" > 0)) || { echo "Put wallpapers in $folder"; exit 1; }
photo="${photos[RANDOM % ${#photos[@]}]}"
changed=0
while IFS= read -r prop; do
  case "$prop" in
    */last-image|*/image-path)
      xfconf-query -c xfce4-desktop -p "$prop" -s "$photo" && changed=1 ;;
  esac
done < <(xfconf-query -c xfce4-desktop -l)
((changed == 1)) || { echo "Set first wallpaper via Desktop Settings."; exit 1; }
WALLPAPER
chmod +x "$HOME/.local/bin/random-wallpaper-xfce"
shortcut='/commands/custom/<Super>w'
if ! xfconf-query -c xfce4-keyboard-shortcuts -p "$shortcut" >/dev/null 2>&1; then
  xfconf-query -c xfce4-keyboard-shortcuts -p "$shortcut" -n -t string \
    -s "$HOME/.local/bin/random-wallpaper-xfce" || warn "Shortcut could not be set"
else
  warn "Super+W already assigned; left unchanged"
fi

if [[ ! -e /etc/systemd/zram-generator.conf ]] && \
   [[ ! -d /etc/systemd/zram-generator.conf.d ]] && \
   ! swapon --noheadings --show=NAME | grep -q '^/dev/zram'; then
  log "Configuring zram swap for next reboot"
  printf '[zram0]\nzram-size = min(ram / 2, 8192)\ncompression-algorithm = zstd\n' |
    sudo tee /etc/systemd/zram-generator.conf >/dev/null
else
  log "Existing zram configuration kept"
fi

if mountpoint -q /mnt/games; then
  if [[ -w /mnt/games ]]; then
    mkdir -p /mnt/games/{SteamLibrary,Videos,Downloads,Files}
  else
    warn "/mnt/games is not writable"
  fi
else
  warn "/mnt/games not mounted: no directories are created on the system disk"
fi

log "Kali visual theme"
if [[ -f "$SCRIPT_DIR/apply-kali-look.sh" ]] &&
   bash "$SCRIPT_DIR/apply-kali-look.sh" --yes; then
  log "Kali visual assets applied"
else
  warn "Kali theme not available; applying Materia/Papirus fallback"
  xfset xsettings /Net/ThemeName string Materia-dark || true
  xfset xsettings /Net/IconThemeName string Papirus-Dark || true
  if [[ -d /usr/share/themes/Materia-dark/xfwm4 ]]; then
    xfset xfwm4 /general/theme string Materia-dark || true
  fi
fi

if command -v lspci >/dev/null && lspci | grep -iq NVIDIA; then
  if command -v nvidia-smi >/dev/null && nvidia-smi >/dev/null 2>&1; then
    log "NVIDIA driver OK"
  else
    warn "NVIDIA detected but nvidia-smi failed."
    if command -v nvidia-inst >/dev/null; then
      if [[ "$NVIDIA_AUTO" -eq 1 ]]; then
        log "Requested NVIDIA installation: checking plan before applying"
        if nvidia-inst --test --prime --32; then
          log "Installing NVIDIA drivers via official EndeavourOS nvidia-inst"
          if sudo nvidia-inst --prime --32; then
            log "NVIDIA driver setup finished; reboot and verify with nvidia-smi"
          else
            warn "NVIDIA installation failed; see nvidia-inst output"
          fi
        else
          warn "NVIDIA dry-run failed: driver NOT changed"
        fi
      else
        warn "NVIDIA driver NOT installed automatically. Use --nvidia only after checking installer GPU support."
        nvidia-inst --test --prime --32 || true
      fi
    else
      warn "nvidia-inst missing: use EndeavourOS NVIDIA documentation; no blind driver installation"
    fi
  fi
fi
if [[ -f "$SCRIPT_DIR/doctor.sh" ]]; then
  bash "$SCRIPT_DIR/doctor.sh" || warn "Some diagnostics need attention"
fi
log "Finished. Log: $LOG_FILE"
echo "Log out / reboot before judging theme and zram."
echo "Steam library: add /mnt/games/SteamLibrary from Steam > Settings > Storage."
echo "For RTX 3050 games: prime-run gamemoderun %command%"
echo "No changes to partitions, Windows, GRUB, fstab. Nvidia modules changed only if --nvidia requested and needed."
