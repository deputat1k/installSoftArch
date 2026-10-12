# SYSTEM — EndeavourOS + Xfce / ASUS TUF F15 FX507ZC4

Ця гілка відтворює **корисний функціонал оригінального `main/install.sh`**, але без команд GNOME, небезпечного `curl | sudo bash` і без бекенд-стеку. **Вона не відповідає за оформлення Kali**: за ним переходь на гілку [`XFCE`](../XFCE) і запускай `apply-kali-look.sh`.

## Запуск

Після встановлення EndeavourOS з **Xfce X11** та підключення інтернету:

```bash
git clone -b SYSTEM https://github.com/deputat1k/installSoftArch.git
cd installSoftArch
bash -n install-system.sh
bash install-system.sh --yes
```

Запускай від звичайного користувача, **без `sudo` перед Bash**. Скрипт сам просить пароль `sudo`; `--yes` відключає підтвердження `pacman` — переглянь скрипт до запуску. Можна без `--yes`, тоді `pacman` запитуватиме підтвердження. Не запускай під час інших операцій `pacman`.

### Що робить

- Повне оновлення `pacman -Syu`, вмикає `multilib`.
- Програми першого скрипта: **Firefox, Brave, Telegram, Steam, OBS, Discord**. Brave через Flatpak/Flathub, не AUR. Google Chrome, Laravel, Python, Java, PHP, Docker **не включені як окремий dev-стек**; Python може вже бути залежністю Arch.
- **Intel 12th gen:** Mesa, lib32 Mesa, Intel Vulkan, медіадрайвер, VA-API і Steam-залежні 32-бітні бібліотеки. Пакет `linux-firmware` надає широкий набір firmware.
- **RTX 3050:** якщо `nvidia-smi` уже працює, не перевстановлює драйвер. Якщо ні, намагається `nvidia-inst --test --prime --32`, а тоді (лише якщо тест успішний) `sudo nvidia-inst --prime --32`. Перезавантаження потрібне. Якщо `nvidia-inst` немає або виникає конфлікт — повідомляє, не підставляє випадкові модулі. Опція `--skip-nvidia` вимикає цей крок.
- Створює `uk_UA.UTF-8` і `en_US.UTF-8`, встановлює **англійську мову інтерфейсу** та часовий пояс `Europe/Kyiv`. Xfce: клавіатура `us,ua` з `Alt+Shift`.
- `~/Pictures/Wallpaper`, перемикання випадкових шпалер на `Super+W` (коли клавіші вільні), служби друку CUPS/Avahi.
- **G-Helper Linux:** завантажує останній *release AppImage* і офіційні udev-правила з `utajum/g-helper-linux`, порівнює SHA256 із контрольними сумами GitHub Release, додає пункт меню Xfce. **Не запускає мережевий інсталяційний скрипт як root.** Для функцій вентилятора/MUX потрібна підтримка саме цієї моделі. Опція `--skip-ghelper` вимикає встановлення.

### Свідомо відсутнє

- **60-секундний GRUB timeout, правки ядра/EFI, автоматичне перезавантаження.** NVIDIA DRM mode setting контролюється сучасними драйверами / середовищем і не повинен без перевірки переписувати GRUB.
- **Примусове вимкнення всіх таймерів сну та редагування `logind.conf`.** Налаштуй Xfce → Power Manager після перевірки сну на ноутбуці. Це безпечніше, ніж прибирати захист від перегріву/розрядки батареї.
- Автоматичний запуск `steam://install/1493710`: старий скрипт позначав його виконаним навіть без успішного завантаження. Proton Experimental вибирай через Steam після входу в обліковий запис.
- Диски, `fstab`, GRUB, EFI, конфігурація dual boot, RGB/режим MUX не змінюються.

### Перевірка

```bash
nvidia-smi
prime-run glxinfo -B
flatpak list --app
timedatectl
localectl
lsmod | grep -E 'asus_wmi|nvidia'
```

G-Helper у меню Xfce як **G-Helper Linux** (AppImage у `~/.local/opt/ghelper`). Якщо драйвер не працює — **не припускай, що все успішно**: перевір лог `~/.local/state/installSoftArch/SYSTEM-*.log`.

**Обмеження:** скрипт пройшов перевірку синтаксису Bash; запуск на FX507ZC4 не перевірений. Для Wi-Fi, Bluetooth, камери та звуку необхідна окрема перевірка в реальній системі: встановлення пакетів не гарантує сумісності кожного пристрою.