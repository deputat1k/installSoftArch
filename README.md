# XFCE — максимально близький вигляд Kali Linux на EndeavourOS

Ця гілка містить **лише візуальне налаштування Xfce**. Драйвери, браузери, Steam, G-Helper, українська розкладка, локаль та системні налаштування — у [`SYSTEM`](https://github.com/deputat1k/installSoftArch/tree/SYSTEM).

## Порядок запуску

1. Встанови EndeavourOS **Online → Xfce**, увійди у сесію **X11** і перевір мережу.
2. Один раз виконай `SYSTEM/install-system.sh` з гілки SYSTEM (за потреби — після перезавантаження для NVIDIA).
3. У новому терміналі:

```bash
git clone -b XFCE https://github.com/deputat1k/installSoftArch.git kali-xfce-look
cd kali-xfce-look
bash -n apply-kali-look.sh
bash apply-kali-look.sh
```

Можна запустити `bash install-eos-xfce.sh` замість останньої команди — це **сумісний ярлик** того ж установника теми. **Без `sudo` перед Bash.** Скрипт сам попросить пароль для Xfce-залежностей. Не використовує репозиторії Kali для пакетів Arch.

## Що робить скрипт автоматично

- Встановлює лише Xfce-плагіни та інструмент профілів панелей: Whisker, Genmon, CPU graph, Netload, звук, сповіщення, clipman, папки і т. д.
- **Створює резервну копію** поточної панелі `xfce4-panel-profiles save` та конфігурації `xfconf`; шлях до неї показує наприкінці.
- Клонує [офіційний kali-themes](https://gitlab.com/kalilinux/packages/kali-themes), копіює `Kali-Dark` та за наявності `Flat-Remix-Blue-Dark` до профілю користувача.
- Налаштовує Xfce GTK, декорації вікон, іконки.
- Збирає з **оригінальних файлів Kali** `xfce-panel-profiles/Kali` архів `.tar.bz2` і застосовує через `xfce4-panel-profiles load`. Якщо профіль чи один зі сторонніх плагінів несумісний — логує помилку, зберігає резервну копію; деякі панельні аплети можуть не працювати без Kali-залежностей.
- Переносить термінальну палітру `terminalrc` за наявності та зберігає попередню.
- Завантажує офіційне шпалери `kali-actiniaria.svg` з репозиторію Kali Wallpapers і застосовує до існуючих Xfce-каналів. Це **не обов'язково шпалери за замовчуванням твого старого Kali Live ISO**.

**Це максимально близька конфігурація, але не біт-у-біт Kali Live USB.** Версія Xfce, плагіни, Kali Panel Genmon, іконки, меню та LightDM можуть відрізнятися. Навіть успішний імпорт профілю не гарантує ідентичної роботи всіх віджетів.

## Що вручну перевірити після запуску

1. **Вийди із Xfce й увійди знову.** Якщо панель порожня/інша — `Settings → Panel → Panel Profiles` і спробуй профіль із резервної копії або імпортуй `Kali` з меню.
2. **Панель і меню:** правий клік по панелі → `Panel → Panel Preferences` (висота, автоприховування, розташування). `Panel → Add New Items`: перевір `Whisker Menu`, `Notification Area`, `Status Tray Plugin`, `PulseAudio`, `Clock`, `Power Manager`, `Workspace Switcher`. Деякі плагіни Kali/Genmon залежать від файлів Kali, яких немає в EndeavourOS — прибери зламані/порожні елементи.
3. **Іконки:** `Settings → Appearance → Icons` → `Flat-Remix-Blue-Dark` або `Papirus-Dark`; тема — `Kali-Dark`. `Settings → Window Manager → Style` → `Kali-Dark`.
4. **Шпалери:** `Settings → Desktop → Background` → `~/.local/share/backgrounds/kali-actiniaria.svg` (якщо автоматично не застосувалися). Можна вибрати інші з [офіційних шпалер](https://www.kali.org/wallpapers/).
5. **Термінал:** закрий усі відкриті вікна `xfce4-terminal`, відкрий заново. Якщо потрібні інші шрифти й прозорість — `Edit → Preferences → Appearance`.
6. **LightDM (екран входу):** свідомо не змінюється; тему greeter можна налаштувати окремо після перевірки сумісності. Не копіюй бездумно файли Kali `/etc/lightdm` у Arch.
7. **Клавіатура та автозапуск:** налаштовуються `SYSTEM`-скриптом, тут не змінюються.

## Як відкотити панель/оформлення

Після встановлення у терміналі написано **шлях до резервної копії**, наприклад:

```bash
ls -d ~/.local/share/installSoftArch/xfce-backups/*
xfce4-panel-profiles load ~/.local/share/installSoftArch/xfce-backups/YYYYMMDD-HHMMSS/panel-original.tar.bz2
```

Заміни `YYYYMMDD-HHMMSS` на справжню папку. Для кольорів/ікон: `Settings → Appearance`, для теми вікон `Settings → Window Manager`.

Щоб відновити старий xfconf (за потреби), вийди із Xfce, скопіюй з бекапу файли `xfce-perchannel-xml` у `~/.config/xfce4/xfconf/`, потім увійди знову. Не відновлюй конфігурацію поверх активної сесії Xfce — вона може одразу перезаписати її.

## Перевірка

```bash
xfconf-query -c xsettings -p /Net/ThemeName
xfconf-query -c xsettings -p /Net/IconThemeName
bash doctor.sh
```

Логи: `~/.local/state/installSoftArch/XFCE-*.log`.

**Тестування:** Bash-синтаксис перевірено; реальний EndeavourOS/Xfce та зовнішні GitLab-залежності в цьому середовищі **не запускалися**. Оформлення та панелі мають ручні елементи перевірки, перелічені вище. `main` не змінювали.