# Power and boot setup

Use `bash setup.sh` after installing Arch with GNOME. This first runs `install.sh` to install and update Arch packages and graphics drivers, then `power-boot.sh` to hide the GRUB menu, keep GNOME awake during inactivity, and request suspend on lid close. Do not run as root. Reboot manually after successful setup.

Before testing lid close, save all work. Test `systemctl suspend` first. If wake fails, use logs to diagnose BIOS, kernel and NVIDIA. Sleep/resume cannot be guaranteed without hardware testing.

GRUB stays installed and can be shown with Esc during startup. The script backs up `/etc/default/grub` and uses a one-second hidden timeout.
