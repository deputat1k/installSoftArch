# EndeavourOS + Xfce — ASUS TUF Gaming F15 FX507ZC4

Переписана **локальна** версія `deputat1k/installSoftArch` для Xfce.
**Ніяких змін у GitHub-репозиторії користувача не робиться.**

## Безпека перед встановленням

1. Зроби backup даних на **обох SSD**. Форматування другого SSD знищить файли на ньому.
2. Переконайся, що Windows Recovery Key для BitLocker/Device Encryption збережено. Вимкни Windows Fast Startup.
3. Зменши C: до приблизно 150 GB **тільки якщо зайняте місце та майбутні оновлення дозволяють**. Решту залиш Unallocated.
4. Завантаж EndeavourOS USB у **UEFI**, вибери **Online → Xfce → GRUB → Manual partitioning**.
5. На **системному SSD** наявний EFI FAT32 признач `/boot/efi` і **НЕ форматуйте**. Windows NTFS/MSR/Recovery **не змінюй**. З Unallocated створи великий `ext4` `/` (форматувати тільки цей новий Linux-розділ).
6. **Другий SSD поки не чіпай.** Перед Install ретельно перевір список операцій. Якщо EFI/Windows має форматуватись — зупини інсталяцію.
7. Перевір запуск обох ОС через UEFI/GRUB перед форматуванням ігрового SSD.

Визначай диски через:
```bash
lsblk -e7 -o NAME,SIZE,MODEL,SERIAL,FSTYPE,LABEL,MOUNTPOINTS
sudo parted -l
```
Назви `/dev/nvme0n1` і `/dev/nvme1n1` можуть мінятись — НІКОЛИ не вгадуй за назвою.

## Форматування другого 1 TB SSD після встановлення

У EndeavourOS встанови GParted, якщо його ще нема:
```bash
sudo pacman -S gparted
# Далі відкрий GParted з меню Xfce (додаток попросить пароль адміністратора)
```

У **GParted** обери справа вгорі за моделлю та розміром **саме другий SSD**, а не Windows/Linux системний.

**Ця операція видалить УСІ дані на обраному SSD.**

- `Device > Create Partition Table > gpt` (якщо розмітка вже GPT і ти свідомо хочеш очистити диск, також можна видалити тільки його існуючі розділи).
- Створи один ext4 на весь простір; Label: `LinuxGames`.
- Натисни зелену галочку `Apply`, перевіривши вибір диска.
- Подивись **фактичний UUID** нового ext4: `lsblk -f` або `sudo blkid`.

Створи точку монтування:
```bash
sudo mkdir -p /mnt/games
sudoedit /etc/fstab
```
Додай **один рядок із реальним UUID**, без `<...>`:
```fstab
UUID=YOUR-REAL-EXT4-UUID /mnt/games ext4 defaults,nofail,x-systemd.device-timeout=10s 0 2
```
Застосуй і **перевір**, що підключився саме потрібний розділ:
```bash
sudo systemctl daemon-reload
sudo mount -a
findmnt /mnt/games
lsblk -f
```
Лише коли `findmnt` показує правильний SSD, зроби корінь точки монтування власністю свого звичайного користувача:
```bash
sudo chown "$USER:$(id -gn)" /mnt/games
mkdir -p /mnt/games/{SteamLibrary,Videos,Downloads,Files}
```
Не виконуй `chown` до підтвердження, що це реальний змонтований ext4-диск.

## NVIDIA (після встановлення ОС)

Перед встановленням перевір:
```bash
lspci -k | grep -A4 -Ei 'VGA|3D|Display'
pacman -Q | grep -E '^(nvidia|lib32-nvidia)' || true
nvidia-smi
```
EndeavourOS може вже поставити драйвер. Не запускай повторну інсталяцію автоматично.
Якщо драйвера немає або він неповний, перевір тест:
```bash
nvidia-inst --test --prime --32
```
Переглянь висновок; після підтвердження потрібних змін:
```bash
sudo nvidia-inst --prime --32
```
Перезавантажся. Перевір:
```bash
nvidia-smi
prime-run glxinfo -B
```
`--32` потрібен для 32-бітних бібліотек Steam/Proton. Не встановлюй одночасно декілька менеджерів Optimus/GPU. Для першого запуску обирай Hybrid/Optimus режим.

## Запуск твого скрипта

Коли EndeavourOS + Xfce завантажиться і матиме інтернет, скопіюй на ноутбук `install-eos-xfce.sh` (з цього архіву), далі:
```bash
cd ~/Downloads
chmod +x install-eos-xfce.sh
bash -n install-eos-xfce.sh
./install-eos-xfce.sh
```
Шлях `~/Downloads` — приклад; якщо поклав в іншу директорію, `cd` туди. Виконувати **без sudo**. Під час `pacman` / `yay` переглядай підтвердження. Скрипт **не переформатує жоден диск, не пише в fstab і не змінює GRUB/EFI**.

Після нього для **оригінальної теми Kali** можеш (за бажанням) запустити:
```bash
chmod +x apply-kali-look.sh
./apply-kali-look.sh
```
Цей другий скрипт копіює статичні теми з офіційного GitLab Kali тільки в домашню директорію (без Kali APT/пакетних репозиторіїв). Якщо GitLab або структура проєкту зміниться, він чесно повідомить про проблему. Іконки/панелі можуть вимагати ручної настройки.

## Steam + Proton

Steam (з pacman) > Settings > Storage > Add Drive/Library > `/mnt/games/SteamLibrary`.
Steam > Settings > Compatibility > увімкнути Steam Play для інших ігор та вибрати Proton Experimental за потреби. Для кожної гри Properties > Compatibility можна вибирати версію Proton окремо.

Якщо гра використовує Intel замість RTX 3050, додай до **Launch Options** гри:
```text
prime-run gamemoderun %command%
```
Перевір GPU через `nvidia-smi` під час запущеної гри.

**Не всі Windows-ігри запускаються в Proton** (античит, DRM, лончери). Перевір сумісність на ProtonDB та офіційних джерелах гри.

## Енергозбереження ASUS

- Xfce Settings > Power Manager: увімкни вимкнення/затемнення екрана від батареї, розумний sleep і поведінку кришки; не вимикай усе глобально.
- Спочатку використовуй звичайний графічний стек Intel + NVIDIA PRIME, GPU Hybrid у BIOS.
- Почни лише з **одного** керування профілями (наприклад, power-profiles-daemon). **Не запускай одночасно TLP, tuned/ppd та asusctl із конкуруючими профілями**. Якщо потрібен `asusctl`, читай актуальні https://asus-linux.org/guides/arch-guide/ і перевір підтримку твоєї TUF-моделі.
- Для обмеження зарядки перевір існування `/sys/class/power_supply/BAT*/charge_control_end_threshold` і документацію Asusctl. Не записуй випадкові значення в sysfs.
- Грати на RTX 3050 краще від блока живлення, режим Balanced/Performance залежно від шуму/температури.

## Зміни відносно оригінального `installSoftArch/install.sh`

**Збережено/оновлено**:
- повне оновлення pacman та multilib;
- Firefox, Telegram, Discord, OBS, Steam;
- Brave як **явне необов'язкове** встановлення через `yay` з перевіркою PKGBUILD;
- українська розкладка та Alt+Shift через `xfconf-query`, а не `gsettings` GNOME;
- випадкові шпалери та Super+W для Xfce;
- Vulkan, Intel Mesa, 32-бітні бібліотеки, Steam/Proton;
- підтримка принтера CUPS/Avahi;
- нові ігрові утиліти: GameMode, MangoHud, Lutris, Wine, winetricks;
- інструменти: btop, fastfetch, GParted, VLC/MPV, qBittorrent, Xarchiver, Xfce Whisker Menu;
- zram тільки з дозволу та без перезапису наявного конфіга.

**Прибрано / не автоматизовано**:
- GNOME-specific `gsettings`, autostart Proton із таймером і штучним прапорцем `done`;
- небезпечний `curl | sudo bash` для G-Helper Linux;
- примусовий 60-секундний GRUB timeout, модифікація параметрів ядра без перевірки та безумовний `grub-mkconfig`;
- примусове вимкнення idle-suspend/затемнення (погано для автономності);
- глобальне редагування `systemd-logind.conf` під кришку (Xfce Power Manager має власну поведінку);
- пакетні операції повністю без підтвердження `--noconfirm`;
- автоматичне перезавантаження;
- автоматичне переформатування SSD, редагування EFI/GRUB і fstab.

## Після перевірки

- Перевір, що завантажуються **обидві** ОС.
- Перевір `findmnt /mnt/games`, `nvidia-smi`, Wi‑Fi, Bluetooth, принтер, sleep, заряд батареї та звук.
- Встанови Steam-бібліотеку на другому SSD і спробуй кілька своїх ігор перед масовим завантаженням.
- Скрипт перевірено на синтаксис `bash -n`, **не тестовано реально на твоєму ноутбуці**.

---

## АВТОМАТИЧНЕ ВСТАНОВЛЕННЯ НА ENDEAVOUROS XFCE (оновлено)

Запускай лише **після** встановлення та входу в графічний Xfce **X11**, із підключеним інтернетом. Не через sudo. Перед запуском переглянь код у репозиторії.

**Одна команда** — клонувати гілку XFCE і виконати автоматичне налаштування:

```bash
bash -c 'set -e; command -v git >/dev/null || sudo pacman -S --needed git; dir="$(mktemp -d)"; git clone --depth 1 --branch XFCE https://github.com/deputat1k/installSoftArch.git "$dir/installSoftArch"; cd "$dir/installSoftArch"; bash install-eos-xfce.sh --yes --dev'
```

Якщо не потрібні інструменти бекенду, прибери `--dev`. Без `--yes` pacman показуватиме запити на підтвердження. Під час запуску може знадобитися пароль sudo. `--yes` використовує pacman `--noconfirm`, тому перед запуском важливо ознайомитися з пакетами; не запускай, якщо є конфлікти пакетів або невирішені оновлення.

**Що встановлюється:** Firefox, Telegram, Discord, OBS, Steam, Lutris, Wine/Winetricks, GameMode, MangoHud, Vulkan/Mesa, Xfce-утиліти, CUPS, VLC, MPV, qBittorrent, btop, fastfetch, Python, Node.js, npm. За `--dev` додаються Java JDK, Maven, PHP, Composer, .NET SDK, Docker CLI/Engine та Compose (Docker service спеціально не вмикається).

**Що налаштовується:** multilib, повне оновлення системи, англійська/українська Alt+Shift, Super+W для шпалер (якщо не зайнята), zram за відсутності іншої конфігурації, служби друку. `apply-kali-look.sh` запускається **автоматично** і намагається встановити оригінальну тему Kali-Dark та іконки, а якщо GitLab/структура теми недоступні — застосовує Materia/Papirus як запасну тему. **Це не повний клон панелей і шпалер Kali.**

Після установки запускається `doctor.sh` і звітує про стан частини компонентів. Логи: `~/.local/state/eos-xfce-setup/`. Для ручної діагностики: `bash doctor.sh`.

**Не робить автоматично:** встановлення драйвера NVIDIA, форматування та монтування SSD, редагування EFI/GRUB/fstab, створення Steam-бібліотеки в клієнті Steam, зміну режиму MUX/GPU, повне копіювання панелей Kali. Ці речі потребують окремої перевірки. Не встановлює AUR/Brave без перегляду PKGBUILD; Brave навмисно виключений з автоматичного режиму.

**Після виконання:** перезавантажся, перевір `nvidia-smi`, `findmnt /mnt/games` та тему через Xfce Settings. На реальному ASUS FX507ZC4 скрипт ще не перевірений; безумовну гарантію встановлення без помилок дати неможливо.
