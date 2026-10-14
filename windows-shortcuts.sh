#!/usr/bin/env bash
# Windows-style keyboard shortcuts for GNOME / Wayland. Run as user.
set -Eeuo pipefail
[[ $EUID -ne 0 ]] || { echo 'Do not use sudo to start this script' >&2; exit 1; }
[[ ${XDG_CURRENT_DESKTOP:-} == *GNOME* ]] || { echo 'Start this inside GNOME' >&2; exit 1; }
for cmd in gsettings dconf python3; do command -v "$cmd" >/dev/null || { echo "Missing $cmd" >&2; exit 1; }; done
backup="$HOME/.local/share/installSoftArch/tweaks-backups/shortcuts-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"
dconf dump /org/gnome/desktop/wm/keybindings/ > "$backup/wm.dconf"
dconf dump /org/gnome/shell/keybindings/ > "$backup/shell.dconf"
dconf dump /org/gnome/mutter/keybindings/ > "$backup/mutter.dconf"
dconf dump /org/gnome/settings-daemon/plugins/media-keys/ > "$backup/media.dconf"
echo "$backup" > "$HOME/.local/share/installSoftArch/tweaks-backups/latest-shortcuts.txt"
python3 - <<'PY'
import subprocess,ast,re
def execv(*args):
    return subprocess.run(args,check=True,text=True,capture_output=True).stdout.strip()
def parse(v):
    if v.startswith('@as '):v=v[4:]
    return ast.literal_eval(v)
s='org.gnome.shell.keybindings'
w='org.gnome.desktop.wm.keybindings'
m='org.gnome.mutter.keybindings'
p='org.gnome.settings-daemon.plugins.media-keys'
mapping=[
(s,'show-screenshot-ui','<Super><Shift>s'),
(p,'home','<Super>e'),
(p,'control-center','<Super>i'),
(w,'panel-run-dialog','<Super>r'),
(s,'toggle-overview','<Super>s'),
(s,'toggle-quick-settings','<Super>a'),
(s,'toggle-message-tray','<Super>n'),
(w,'show-desktop','<Super>d'),
(p,'screensaver','<Super>l'),
(w,'maximize','<Super>Up'),
(w,'unmaximize','<Super>Down'),
(m,'toggle-tiled-left','<Super>Left'),
(m,'toggle-tiled-right','<Super>Right'),
(w,'switch-to-workspace-left','<Super><Control>Left'),
(w,'switch-to-workspace-right','<Super><Control>Right'),
(s,'toggle-overview','<Super>Tab'),
]
def norm(a):
    mods=tuple(sorted(x.lower() for x in re.findall(r'<([^>]+)>',a)))
    return mods,re.sub('<[^>]+>','',a).lower()
existing={}
for schema in (s,w,m,p,'org.gnome.mutter.wayland.keybindings'):
    try: keys=execv('gsettings','list-keys',schema).splitlines()
    except subprocess.CalledProcessError: continue
    for key in keys:
        try:
            value=parse(execv('gsettings','get',schema,key))
            if isinstance(value,list) and all(isinstance(x,str) for x in value):
                existing[(schema,key)]=value
        except (ValueError,SyntaxError,subprocess.CalledProcessError):pass
requested={}
for schema,key,accel in mapping:
    if (schema,key) not in existing:
        print('[SKIP] unsupported',key);continue
    requested.setdefault((schema,key),[]).append(accel)
targets={norm(a) for v in requested.values() for a in v}
for (schema,key),values in existing.items():
    if not execv('gsettings','writable',schema,key)=='true':continue
    filtered=[a for a in values if norm(a) not in targets or norm(a) in {norm(x) for x in requested.get((schema,key),[])}]
    if (schema,key) in requested:
        for a in requested[schema,key]:
            if norm(a) not in {norm(x) for x in filtered}:filtered.append(a)
    if filtered!=values:
        execv('gsettings','set',schema,key,str(filtered))
for (schema,key),values in requested.items():
    got=parse(execv('gsettings','get',schema,key))
    ok=all(norm(v) in {norm(x) for x in got} for v in values)
    print('[OK]' if ok else '[CHECK]',key,', '.join(values))
print('Super+W preserved for wallpaper rotation.')
PY
if command -v gnome-system-monitor >/dev/null 2>&1; then
  python3 - <<'PY'
import ast,subprocess
s='org.gnome.settings-daemon.plugins.media-keys'
path='/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/windows-task-manager/'
raw=subprocess.check_output(['gsettings','get',s,'custom-keybindings'],text=True).strip().removeprefix('@as ')
items=ast.literal_eval(raw)
if path not in items:items.append(path)
subprocess.run(['gsettings','set',s,'custom-keybindings',str(items)],check=True)
dest='org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:'+path
for k,v in (('name','Task Manager'),('command','gnome-system-monitor'),('binding','<Control><Shift>Escape')):
    subprocess.run(['gsettings','set',dest,k,v],check=True)
print('[OK] Ctrl+Shift+Esc')
PY
else
  echo '[INFO] Install gnome-system-monitor to enable Ctrl+Shift+Esc'
fi
echo "Backed up shortcuts to $backup"
