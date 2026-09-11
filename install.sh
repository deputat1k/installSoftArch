#!/bin/bash

# ============================================================
# ARCH LINUX GNOME - PERSONAL SETUP SCRIPT
# ============================================================
#
# Run this script as your normal user, NOT as root.
#
# Current setup:
#   - Update Arch Linux
#   - Enable multilib for Steam / 32-bit libraries
#   - Install NVIDIA drivers for RTX 3050
#   - Install Intel graphics / Vulkan support
#   - Enable Ukrainian locale while keeping system language English
#   - Add English + Ukrainian keyboard layouts
#   - Set Alt+Shift as layout switch
#   - Set GRUB timeout to 60 seconds
#   - Install Firefox, Brave, Telegram, Steam, OBS Studio, Discord
#   - Install G-Helper Linux
#   - Disable automatic screen blanking
#   - Disable automatic idle suspend
#   - Suspend when laptop lid is closed
#   - Create ~/Pictures/Wallpaper
#   - Create random wallpaper script
#   - Configure Super+W for random wallpaper
#   - Reboot automatically at the very end
#
# ============================================================

set -euo pipefail


# ============================================================
# OUTPUT HELPERS
# ============================================================

print_step() {
    echo
    echo "============================================================"
    echo " $1"
    echo "============================================================"
}

print_info() {
    echo "[INFO] $1"
}

print_success() {
    echo "[ OK ] $1"
}


# ============================================================
# SAFETY CHECKS
# ============================================================

if [ "$EUID" -eq 0 ]; then
    echo
    echo "Do NOT run this script as root."
    echo
    echo "Run it as your normal user:"
    echo "    ./install.sh"
    echo
    exit 1
fi


# ============================================================
# SUDO
# ============================================================

print_step "Checking sudo access"

sudo -v

print_success "Sudo access confirmed."


# ============================================================
# UPDATE SYSTEM
# ============================================================

print_step "Updating Arch Linux"

sudo pacman -Syu --noconfirm

print_success "System updated."


# ============================================================
# ENABLE MULTILIB
# ============================================================
#
# Required for Steam and other 32-bit applications/libraries.
#
# Desired configuration:
#   [multilib]
#   Include = /etc/pacman.d/mirrorlist
#
# ============================================================

print_step "Enabling multilib repository"

if grep -q '^\[multilib\]' /etc/pacman.conf; then
    print_info "Multilib is already enabled."
else
    sudo sed -i \
        '/^#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#//' \
        /etc/pacman.conf
    print_success "Multilib enabled."
fi


# ============================================================
# REFRESH PACKAGE DATABASE
# ============================================================

print_step "Refreshing package databases"

sudo pacman -Sy --noconfirm

print_success "Package databases refreshed."


# ============================================================
# CORE DEPENDENCIES
# ============================================================

print_step "Installing core dependencies"

sudo pacman -S --needed --noconfirm \
    base-devel \
    git \
    curl \
    wget \
    unzip \
    xdg-utils \
    jq

print_success "Core dependencies installed."


# ============================================================
# GRAPHICS DRIVERS
# ============================================================
#
# Laptop hardware:
#   - Intel Core i5-12500H
#   - NVIDIA RTX 3050
#
# NVIDIA:
#   nvidia-open
#   nvidia-utils
#   lib32-nvidia-utils
#   nvidia-prime
#
# Intel / Mesa / Vulkan:
#   mesa
#   lib32-mesa
#   vulkan-intel
#   lib32-vulkan-intel
#   vulkan-icd-loader
#   lib32-vulkan-icd-loader
#
# ============================================================

print_step "Installing graphics drivers"

sudo pacman -S --needed --noconfirm \
    nvidia-open \
    nvidia-utils \
    lib32-nvidia-utils \
    nvidia-prime \
    mesa \
    lib32-mesa \
    vulkan-intel \
    lib32-vulkan-intel \
    vulkan-icd-loader \
    lib32-vulkan-icd-loader \
    libva \
    lib32-libva

print_success "Graphics drivers installed."


# ============================================================
# NVIDIA DRM MODESETTING
# ============================================================

print_step "Configuring NVIDIA DRM modesetting"

if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
    if ! grep -q 'nvidia_drm.modeset=1' /etc/default/grub; then
        sudo sed -i \
            's/^GRUB_CMDLINE_LINUX_DEFAULT="\([^"]*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia_drm.modeset=1"/' \
            /etc/default/grub
    fi
else
    echo 'GRUB_CMDLINE_LINUX_DEFAULT="nvidia_drm.modeset=1"' \
        | sudo tee -a /etc/default/grub > /dev/null
fi

print_success "NVIDIA DRM modesetting configured."


# ============================================================
# LOCALES
# ============================================================

print_step "Configuring locales"

if grep -q '^#uk_UA.UTF-8 UTF-8' /etc/locale.gen; then
    sudo sed -i \
        's/^#uk_UA.UTF-8 UTF-8/uk_UA.UTF-8 UTF-8/' \
        /etc/locale.gen
fi

sudo locale-gen

# Keep the graphical interface in English.
sudo localectl set-locale LANG=en_US.UTF-8

print_success "uk_UA.UTF-8 enabled."
print_success "System language remains English."


# ============================================================
# KEYBOARD LAYOUTS
# ============================================================

print_step "Configuring keyboard layouts"

gsettings set \
    org.gnome.desktop.input-sources sources \
    "[('xkb', 'us'), ('xkb', 'ua')]"

gsettings set \
    org.gnome.desktop.input-sources xkb-options \
    "['grp:alt_shift_toggle']"

print_success "English + Ukrainian layouts configured."
print_success "Alt+Shift switching configured."


# ============================================================
# GRUB TIMEOUT
# ============================================================

print_step "Configuring GRUB timeout"

if grep -q '^GRUB_TIMEOUT=' /etc/default/grub; then
    sudo sed -i \
        's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=60/' \
        /etc/default/grub
else
    echo 'GRUB_TIMEOUT=60' \
        | sudo tee -a /etc/default/grub > /dev/null
fi

print_success "GRUB timeout set to 60 seconds."


# ============================================================
# REBUILD GRUB
# ============================================================

print_step "Rebuilding GRUB configuration"

sudo grub-mkconfig -o /boot/grub/grub.cfg

print_success "GRUB configuration rebuilt."


# ============================================================
# OFFICIAL APPLICATIONS
# ============================================================

print_step "Installing official applications"

sudo pacman -S --needed --noconfirm \
    firefox \
    telegram-desktop \
    steam \
    obs-studio \
    discord

print_success "Firefox installed."
print_success "Telegram Desktop installed."
print_success "Steam installed."
print_success "OBS Studio installed."
print_success "Discord installed."


# ============================================================
# AUR PACKAGE INSTALLER
# ============================================================
#
# We install only the AUR packages we currently need and do not
# add an AUR helper such as yay to the system.
#
# ============================================================

install_aur_package() {
    local package="$1"
    local aur_dir

    print_step "Installing AUR package: $package"

    aur_dir="$(mktemp -d)"

    git clone \
        "https://aur.archlinux.org/${package}.git" \
        "$aur_dir/$package"

    cd "$aur_dir/$package"

    makepkg -si --noconfirm

    cd "$HOME"

    rm -rf "$aur_dir"

    print_success "$package installed."
}


# ============================================================
# BRAVE BROWSER
# ============================================================

install_aur_package "brave-bin"


# ============================================================
# G-HELPER LINUX
# ============================================================
#
# Linux port for ASUS/TUF/ROG hardware.
# ============================================================

print_step "Installing G-Helper Linux"

curl -fsSL \
    https://raw.githubusercontent.com/utajum/g-helper-linux/master/install/install.sh \
    | sudo bash

print_success "G-Helper Linux installed."


# ============================================================
# SCREEN BLANKING / IDLE SUSPEND
# ============================================================
#
# No automatic screen blanking and no automatic suspend caused
# by inactivity.
#
# Closing the lid is configured separately below and WILL suspend.
#
# ============================================================

print_step "Disabling automatic screen blanking and idle suspend"

# Never blank the screen because of inactivity.
gsettings set \
    org.gnome.desktop.session \
    idle-delay \
    0

# Prevent GNOME from dimming the screen before blanking.
gsettings set \
    org.gnome.settings-daemon.plugins.power \
    idle-dim \
    false

# Never automatically suspend because of inactivity.
gsettings set \
    org.gnome.settings-daemon.plugins.power \
    sleep-inactive-ac-type \
    'nothing'

gsettings set \
    org.gnome.settings-daemon.plugins.power \
    sleep-inactive-battery-type \
    'nothing'

gsettings set \
    org.gnome.settings-daemon.plugins.power \
    sleep-inactive-ac-timeout \
    0

gsettings set \
    org.gnome.settings-daemon.plugins.power \
    sleep-inactive-battery-timeout \
    0

print_success "Automatic screen blanking disabled."
print_success "Automatic idle suspend disabled."


# ============================================================
# LAPTOP LID -> SUSPEND
# ============================================================
#
# systemd-logind handles lid events at the system level.
#
# ============================================================

print_step "Configuring laptop lid suspend"

LOGIND_FILE="/etc/systemd/logind.conf"

set_logind_option() {
    local option="$1"
    local value="$2"

    if grep -Eq "^[#[:space:]]*${option}=" "$LOGIND_FILE"; then
        sudo sed -i \
            -E "s|^[#[:space:]]*${option}=.*|${option}=${value}|" \
            "$LOGIND_FILE"
    else
        echo "${option}=${value}" \
            | sudo tee -a "$LOGIND_FILE" > /dev/null
    fi
}

set_logind_option "HandleLidSwitch" "suspend"
set_logind_option "HandleLidSwitchExternalPower" "suspend"
set_logind_option "HandleLidSwitchDocked" "suspend"

print_success "Laptop lid -> suspend configured."


# ============================================================
# WALLPAPER DIRECTORY
# ============================================================

print_step "Creating wallpaper directory"

WALLPAPER_DIR="$HOME/Pictures/Wallpaper"

mkdir -p "$WALLPAPER_DIR"
mkdir -p "$HOME/.local/bin"

print_success "Created $WALLPAPER_DIR"


# ============================================================
# RANDOM WALLPAPER SCRIPT
# ============================================================

print_step "Creating random wallpaper script"

WALLPAPER_SCRIPT="$HOME/.local/bin/random-wallpaper"

cat > "$WALLPAPER_SCRIPT" <<'EOF'
#!/bin/bash

WALLPAPER_DIR="$HOME/Pictures/Wallpaper"

mapfile -t WALLPAPERS < <(
    find "$WALLPAPER_DIR" -maxdepth 1 -type f \
        \( \
            -iname "*.png" \
            -o -iname "*.jpg" \
            -o -iname "*.jpeg" \
            -o -iname "*.webp" \
        \) \
        | sort
)

if [ "${#WALLPAPERS[@]}" -eq 0 ]; then
    notify-send \
        "Wallpaper" \
        "No wallpapers found in ~/Pictures/Wallpaper"
    exit 0
fi

RANDOM_WALLPAPER="${WALLPAPERS[$RANDOM % ${#WALLPAPERS[@]}]}"
WALLPAPER_URI="file://$RANDOM_WALLPAPER"

gsettings set \
    org.gnome.desktop.background \
    picture-uri \
    "$WALLPAPER_URI"

gsettings set \
    org.gnome.desktop.background \
    picture-uri-dark \
    "$WALLPAPER_URI"

notify-send \
    "Wallpaper changed" \
    "$(basename "$RANDOM_WALLPAPER")"
EOF

chmod +x "$WALLPAPER_SCRIPT"

print_success "Random wallpaper script created."


# ============================================================
# SUPER + W
# ============================================================
#
# Configure one shortcut only: Super+W
# ============================================================

print_step "Configuring Super+W wallpaper shortcut"

CUSTOM_KEYBINDING_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/random-wallpaper/"

# Note: this intentionally manages only our own custom keybinding.
gsettings set \
    org.gnome.settings-daemon.plugins.media-keys \
    custom-keybindings \
    "['$CUSTOM_KEYBINDING_PATH']"

gsettings set \
    "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$CUSTOM_KEYBINDING_PATH" \
    name \
    "Random Wallpaper"

gsettings set \
    "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$CUSTOM_KEYBINDING_PATH" \
    command \
    "$WALLPAPER_SCRIPT"

gsettings set \
    "org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$CUSTOM_KEYBINDING_PATH" \
    binding \
    "<Super>w"

print_success "Super+W configured."


# ============================================================
# FINAL MESSAGE
# ============================================================

print_step "SETUP COMPLETED"

echo
echo "Installed:"
echo "  - NVIDIA RTX 3050 driver"
echo "  - Intel graphics/Vulkan support"
echo "  - Firefox"
echo "  - Brave"
echo "  - Telegram Desktop"
echo "  - Steam + multilib"
echo "  - OBS Studio"
echo "  - Discord"
echo "  - G-Helper Linux"
echo
echo "Configured:"
echo "  - English + Ukrainian layouts"
echo "  - Alt+Shift switching"
echo "  - Ukrainian locale"
echo "  - GRUB timeout: 60 seconds"
echo "  - No automatic idle screen blanking"
echo "  - No automatic idle suspend"
echo "  - Lid close -> suspend"
echo "  - ~/Pictures/Wallpaper"
echo "  - Super+W -> random wallpaper"
echo
echo "============================================================"
echo
echo "Everything is ready."
echo "The computer will reboot automatically in 10 seconds."
echo

sleep 10

sudo reboot
