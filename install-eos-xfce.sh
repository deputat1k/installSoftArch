#!/usr/bin/env bash
# EndeavourOS + Xfce setup for ASUS TUF F15 / Intel + NVIDIA
# Based on deputat1k/installSoftArch, reworked to avoid unsafe automation.
# Run as regular user INSIDE a running Xfce session AFTER installation.
set -Eeuo pipefail

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[!] %s\033[0m\n' "$*" >&2; }
die() { printf '\033[1;31m[ERROR] %s\033[0m\n' "$*" >&2; exit 1; }
ask() {
    local response
    read -r -p "$1 [y/N]: " response || return 1
    [[ "$response" =~ ^[Yy]([Ee][Ss])?$ ]]
}

[[ "$EUID" -ne 0 ]] || die 'Run without sudo (as your normal user).'
command -v pacman >/dev/null || die 'pacman not found. This script is for EndeavourOS/Arch only.'
command -v xfconf-query >/dev/null || die 'Xfce is missing. Choose Xfce during EndeavourOS installation.'
[[ "${XDG_CURRENT_DESKTOP:-}" == *XFCE* || "${XDG_CURRENT_DESKTOP:-}" == *Xfce* ]] || \
    die 'Log into an Xfce desktop session and then rerun this script.'
[[ -n "${DISPLAY:-}" ]] || die 'An X11 Xfce session is required for desktop configuration.'

log 'This setup does NOT format disks or change EFI/GRUB/Windows partitions.'
log 'Review every pacman/AUR confirmation before proceeding.'
sudo -v

# multilib (required for Steam and 32-bit graphics libraries)
if ! pacman-conf --repo-list | grep -qx multilib; then
    log 'Enabling multilib repository (Steam)'
    sudo cp -n /etc/pacman.conf /etc/pacman.conf.before-eos-xfce-setup
    sudo sed -i '/^#\[multilib\]$/,/^#Include = \/etc\/pacman.d\/mirrorlist$/ s/^#//' /etc/pacman.conf
    pacman-conf --repo-list | grep -qx multilib || die 'Could not enable multilib; inspect /etc/pacman.conf manually.'
fi
log 'Updating whole system (no partial upgrades)'
sudo pacman -Syu

# Only official repo packages. Skip missing names instead of failing the full transaction.
packages=(
    git base-devel curl wget jq unzip zip xdg-utils
    firefox telegram-desktop discord obs-studio
    steam lutris wine winetricks
    gamemode lib32-gamemode mangohud lib32-mangohud
    mesa lib32-mesa vulkan-intel lib32-vulkan-intel
    vulkan-icd-loader lib32-vulkan-icd-loader
    mesa-utils vulkan-tools
    xfce4-whiskermenu-plugin xfce4-clipman-plugin
    xfce4-screenshooter xfce4-taskmanager xfce4-power-manager
    xfce4-pulseaudio-plugin pavucontrol thunar-archive-plugin
    materia-gtk-theme papirus-icon-theme
    btop fastfetch gparted gvfs tumbler
    vlc mpv qbittorrent xarchiver
    cups system-config-printer avahi ipp-usb
    zram-generator
)

log 'Checking packages against enabled official repositories'
available=()
for pkg in "${packages[@]}"; do
    if pacman -Si "$pkg" >/dev/null 2>&1; then
        available+=("$pkg")
    else
        warn "Package unavailable: $pkg (skipping)"
    fi
done
if ((${#available[@]})); then
    log 'Installing software — inspect the package list and confirm'
    sudo pacman -S --needed "${available[@]}"
fi

# CUPS / network printer discovery
if systemctl list-unit-files cups.service --no-legend 2>/dev/null | grep -q '^cups.service'; then
    sudo systemctl enable --now cups.service
fi
if systemctl list-unit-files avahi-daemon.service --no-legend 2>/dev/null | grep -q '^avahi-daemon.service'; then
    sudo systemctl enable --now avahi-daemon.service
fi

# Preserve the language chosen in the installer; generate an extra Ukrainian locale.
if grep -q '^#uk_UA.UTF-8 UTF-8$' /etc/locale.gen; then
    log 'Generating Ukrainian UTF-8 locale (system UI language unchanged)'
    sudo sed -i 's/^#uk_UA.UTF-8 UTF-8$/uk_UA.UTF-8 UTF-8/' /etc/locale.gen
    sudo locale-gen
fi

# Only user desktop settings; safe to run again.
xfset() {
    local channel="$1" property="$2" type="$3" value="$4"
    if xfconf-query -c "$channel" -p "$property" >/dev/null 2>&1; then
        xfconf-query -c "$channel" -p "$property" -s "$value"
    else
        xfconf-query -c "$channel" -p "$property" -n -t "$type" -s "$value"
    fi
}

if ask 'Configure US+Ukrainian keyboard and Alt+Shift switching in Xfce?'; then
    log 'Configuring Xfce keyboard layouts'
    xfset keyboard-layout /Default/XkbDisable bool false
    xfset keyboard-layout /Default/XkbLayout string 'us,ua'
    xfset keyboard-layout /Default/XkbOptions string 'grp:alt_shift_toggle'
fi

if ask 'Apply Kali-inspired dark Xfce theme (Materia-dark + Papirus-Dark)?'; then
    log 'Applying dark theme (inspired by Kali; NOT the original Kali theme)'
    xfset xsettings /Net/ThemeName string Materia-dark
    xfset xsettings /Net/IconThemeName string Papirus-Dark
    if [[ -d /usr/share/themes/Materia-dark/xfwm4 ]]; then
        xfset xfwm4 /general/theme string Materia-dark
    fi
fi

log 'Creating a safe Xfce random-wallpaper helper'
mkdir -p "$HOME/.local/bin" "$HOME/Pictures/Wallpaper"
cat > "$HOME/.local/bin/random-wallpaper-xfce" <<'WALLPAPER'
#!/usr/bin/env bash
set -Eeuo pipefail
folder="$HOME/Pictures/Wallpaper"
[[ -d "$folder" ]] || exit 0
mapfile -d '' -t photos < <(find "$folder" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print0)
if ((${#photos[@]} == 0)); then
    command -v notify-send >/dev/null && notify-send 'Wallpaper' 'Place images in ~/Pictures/Wallpaper'
    exit 0
fi
photo="${photos[RANDOM % ${#photos[@]}]}"
changed=0
while IFS= read -r prop; do
    [[ "$prop" == */last-image || "$prop" == */image-path ]] || continue
    xfconf-query -c xfce4-desktop -p "$prop" -s "$photo"
    changed=1
done < <(xfconf-query -c xfce4-desktop -l)
if ((changed == 0)); then
    printf 'Xfce backdrop properties were not detected; set one wallpaper in Desktop Settings first.\n' >&2
    exit 1
fi
if command -v notify-send >/dev/null; then
    notify-send 'Wallpaper' "$(basename "$photo")"
fi
WALLPAPER
chmod +x "$HOME/.local/bin/random-wallpaper-xfce"

if ask 'Bind Super+W to random wallpapers (only if not already used)?'; then
    shortcut='/commands/custom/<Super>w'
    if xfconf-query -c xfce4-keyboard-shortcuts -p "$shortcut" >/dev/null 2>&1; then
        warn 'Super+W already has an assignment. Not overwriting it; change via Xfce Keyboard settings.'
    else
        xfconf-query -c xfce4-keyboard-shortcuts -p "$shortcut" -n -t string \
            -s "$HOME/.local/bin/random-wallpaper-xfce"
    fi
fi

# Only configure zram if an existing setup is NOT present.
if [[ ! -e /etc/systemd/zram-generator.conf ]] && ! swapon --noheadings --show=NAME | grep -q '^/dev/zram'; then
    if ask 'Configure compressed zram swap (up to 8 GiB; active after reboot)?'; then
        log 'Configuring zram (without replacing existing swap partition)'
        printf '[zram0]\nzram-size = min(ram / 2, 8192)\ncompression-algorithm = zstd\n' | \
            sudo tee /etc/systemd/zram-generator.conf >/dev/null
    fi
else
    warn 'Existing zram setup found; leaving it unchanged.'
fi

if mountpoint -q /mnt/games; then
    if [[ -w /mnt/games ]]; then
        log 'Second disk is mounted and writable: preparing user directories'
        mkdir -p /mnt/games/{SteamLibrary,Videos,Downloads,Files}
    else
        warn '/mnt/games is mounted but not user-writable; check filesystem ownership.'
    fi
else
    warn 'Second disk is NOT mounted at /mnt/games — not creating directories on the OS disk.'
fi

if command -v nvidia-inst >/dev/null; then
    log 'NVIDIA: showing a DRY RUN (no driver is changed by this script)'
    nvidia-inst --test --prime --32 || warn 'Review NVIDIA driver status separately.'
    printf '\nTo install/update ONLY IF NEEDED after checking the dry run:\n'
    printf '  sudo nvidia-inst --prime --32\n'
fi

if ask 'Optionally install Brave from AUR (review the AUR build before accepting)?'; then
    if command -v yay >/dev/null; then
        yay -S --needed brave-bin
    else
        warn 'yay is not installed; skipped Brave. You can install it manually later.'
    fi
fi

log 'Finished — no reboot triggered.'
cat <<'SUMMARY'
NEXT STEPS:
  1. Reboot if packages, graphics drivers, or zram settings need it.
  2. Confirm the second SSD is mounted: findmnt /mnt/games
  3. Steam > Settings > Storage > Add Drive > /mnt/games/SteamLibrary
  4. Steam > Settings > Compatibility: enable Proton for other titles.
  5. Example Steam per-game launch options: prime-run gamemoderun %command%
  6. For exact Kali theme, use Kali's official theme sources manually.
  7. Power settings: Xfce Settings > Power Manager; verify lid/sleep behavior.
This script intentionally does not touch partitions, fstab, bootloader, or GPU modes.
SUMMARY
