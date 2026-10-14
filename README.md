# Arch Linux + GNOME — installSoftArch

Оновлена конфігурація для **ASUS TUF Gaming F15 FX507ZC4**, **Intel Core i5-12500H**, **Intel iGPU + NVIDIA RTX 3050 Laptop**. Гілка `ARCH-GNOME` відокремлена від оригінального `main`.

## Запуск

**Лише після** встановлення Arch Linux із GNOME, підключення до інтернету й входу у власний графічний обліковий запис. Для всього потрібен **один запуск `setup.sh`** (не `install.sh` окремо); запускати **без** `sudo`:

```bash
git clone -b ARCH-GNOME https://github.com/deputat1k/installSoftArch.git
cd installSoftArch
bash -n setup.sh install.sh power-boot.sh doctor.sh
bash setup.sh
```

Для автоматичного підтвердження пакетних операцій: `bash setup.sh --yes`. Пароль sudo усе одно знадобиться, пакетні конфлікти можуть зупинити встановлення. **Першого разу рекомендуємо звичайний запуск без `--yes`**, щоб побачити, які пакети додаватимуться.

Опції: `--no-nvidia`, `--no-ghelper`, `--no-flatpak`, `--yes`, `--help`. Після завершення перезавантажся самостійно, перевір графіку та периферію. Лог: `~/.local/state/installSoftArch/arch-gnome-*.log`.

## Що робить по порядку

1. Перевіряє Arch Linux, GNOME, звичайного користувача, D-Bus і `sudo`.
2. Вмикає `multilib` для Steam та 32-бітних бібліотек, резервує `pacman.conf`.
3. Повністю оновлює систему (`pacman -Syu`).
4. Ставить базові утиліти, Linux firmware, `intel-ucode`, `sof-firmware` і Bluetooth.
5. Ставить Intel Mesa/Vulkan, VA-API, 32-бітні бібліотеки для ігор.
6. Ставить Firefox, Telegram, Discord, OBS, Steam.
7. Додає MangoHud, Wine, Winetricks, VLC, MPV, GNOME Tweaks. Не встановлює Lutris та GameMode.
8. Визначає NVIDIA: якщо модуль уже встановлений, зберігає його; інакше встановлює `nvidia-open-dkms` і заголовки для встановлених стандартних ядер Arch. Додає PRIME та 32-бітні бібліотеки NVIDIA.
9. Налаштовує `en_US.UTF-8`, додає `uk_UA.UTF-8`, часовий пояс `Europe/Kyiv`.
10. Додає `US/UA` розкладки GNOME й `Alt+Shift`.
11. Створює `~/Pictures/Wallpaper` і зміну шпалер через `Super+W`, не очищаючи інші власні комбінації.
12. Встановлює Brave та Google Chrome із Flathub (неофіційні пакування для Chrome).
13. Встановлює G-Helper Linux AppImage та udev rules із **перевіркою SHA256 за GitHub release**, але не перемикає режими GPU.
14. Запускає `doctor.sh` і зберігає лог.
15. Якщо запускати через `setup.sh`, додатково приховує меню GRUB (не видаляючи GRUB), вимикає автоматичний сон і гасіння екрана, налаштовує сон при закритті кришки. Скрипт `power-boot.sh` виконується автоматично.

## NVIDIA та Steam

RTX 3050 Laptop належить до Ampere, для неї сучасні драйвери Arch підтримують `nvidia-open-dkms`. **Є відомі проблеми зі стабільністю open kernel modules на деяких ноутбуках Ampere** — якщо з'являться зависання, діагностуй драйвер, не перемикай сліпо пакети. Зі старим/нестандартним ядром установлення драйвера може бути пропущене; перевір лог. Скрипт не змінює GRUB, DRM parameters, initramfs вручну: для сучасного `nvidia-utils` режим KMS увімкнено за замовчуванням. Посилання: [ArchWiki NVIDIA](https://wiki.archlinux.org/title/NVIDIA), [PRIME](https://wiki.archlinux.org/title/PRIME).

Після перезавантаження:

```bash
nvidia-smi
prime-run glxinfo -B
vulkaninfo --summary
bash doctor.sh
```

У Steam ввійди в обліковий запис → **Settings → Compatibility** → увімкни Proton для потрібних ігор; **Proton Experimental встановлюється через Steam**, скрипт не запускає автоматичний Steam login. Для примусового використання NVIDIA в окремій грі: `prime-run %command%` в Steam Launch Options. Не всі ігри/античит сумісні.

## G-Helper Linux

[Оригінальний проєкт](https://github.com/utajum/g-helper-linux). Використовується перевірений AppImage із релізу, з ярликом у GNOME. У деяких версіях і моделях ASUS функції RGB, вентиляторів, GPU MUX і ліміту заряду можуть відрізнятися; потрібні модулі `asus_wmi`/`asus_nb_wmi` та підтримка firmware. **Не встановлюй паралельно інші сервіси, які керують тим самим вентилятором, профілем живлення чи MUX**. Скрипт не чіпає ці налаштування.

## Що навмисно змінилося порівняно з `main`

- Немає безумовного встановлення `nvidia-open` без перевірки наявних модулів чи інших ядер.
- Немає ручної зміни GRUB на `nvidia_drm.modeset=1` і 60 секунд очікування GRUB.
- Немає `curl | sudo bash` для G-Helper, неперевірених AUR PKGBUILD та автоматичного перезавантаження.
- Сам `install.sh` не чіпає сон або GRUB, але `setup.sh` викликає `power-boot.sh`: вимикає idle-сон/затемнення (також на батареї), встановлює suspend при закритті кришки та приховує меню GRUB із затримкою 1 секунду. Перевір пробудження самостійно — чорний екран NVIDIA не гарантуємо усунути.
- Brave і Chrome ставляться через Flathub, а не AUR; Google Chrome на Flathub — **пакунок спільноти, не офіційне постачання від Google**.
- Proton Experimental запускається через Steam за входу, без одноразового автозапуску, який міг хибно звітувати про успіх.
- Не містить Java, PHP, Docker та іншого бекенд-софту.

## Обмеження

**Скрипт перевірений на Bash-синтаксис, але не перевірявся запуском на твоєму ноутбуку.** Пакетний конфлікт, оновлення Arch, поведінка драйвера NVIDIA, відсутність GitHub/Flathub або особливості GNOME можуть вимагати ручного втручання. Друк, Wi-Fi, Bluetooth, камера, мікрофон і сон треба перевірити після встановлення. На GNOME із Wayland перемикання Alt+Shift може залежати від налаштувань GNOME.

**Не редагує** диски, розділи, `fstab`, EFI, GRUB, MUX, BIOS чи завантажувач; не перевстановлює ОС.