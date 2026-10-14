#!/usr/bin/env bash
# One-command GNOME customization for Arch Linux. Run inside a GNOME user session.
set -Eeuo pipefail

say() { printf '\n==> %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

[[ $EUID -ne 0 ]] || fail 'Run as your normal user, NOT with sudo.'
[[ -f /etc/os-release ]] || fail 'Cannot find /etc/os-release.'
# shellcheck source=/dev/null
source /etc/os-release
[[ ${ID:-} == arch ]] || fail 'This setup only supports Arch Linux.'
[[ ${XDG_CURRENT_DESKTOP:-} == *GNOME* || ${XDG_CURRENT_DESKTOP:-} == *gnome* ]] || fail 'Log in to GNOME first.'
[[ -n ${DBUS_SESSION_BUS_ADDRESS:-} ]] || fail 'GNOME user D-Bus session is not available.'
for cmd in sudo pacman gsettings dconf gnome-shell; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Missing command: $cmd"
done

backup_dir="$HOME/.local/share/installSoftArch/tweaks-backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir"
log_file="$backup_dir/install.log"
exec > >(tee -a "$log_file") 2>&1
trap 'warn "Setup stopped (line $LINENO). See $log_file. Backups: $backup_dir"' ERR
say "Backing up GNOME settings to $backup_dir"
dconf dump /org/gnome/desktop/wm/preferences/ > "$backup_dir/wm-preferences.dconf"
dconf dump /org/gnome/shell/ > "$backup_dir/shell.dconf"
gsettings get org.gnome.shell enabled-extensions > "$backup_dir/enabled-extensions.txt"
# Preserve any pre-existing user installs of extensions that might be upgraded.
mkdir -p "$backup_dir/previous-extensions"
for uuid in dash-to-dock@micxgx.gmail.com blur-my-shell@aunetx just-perfection-desktop@just-perfection; do
  if [[ -d "$HOME/.local/share/gnome-shell/extensions/$uuid" ]]; then
    cp -a "$HOME/.local/share/gnome-shell/extensions/$uuid" "$backup_dir/previous-extensions/$uuid"
  fi
done

say 'Refreshing Arch and installing system utilities + AppIndicator from official repo'
sudo -v
sudo pacman -Syu --needed gnome-extensions-app gnome-disk-utility baobab gnome-shell-extension-appindicator python curl unzip dconf
for command_name in python3 gnome-extensions; do
  command -v "$command_name" >/dev/null || fail "$command_name not available after installation"
done

shell_raw="$(gnome-shell --version)"
if [[ "$shell_raw" =~ ([0-9]+)\. ]]; then
  major="${BASH_REMATCH[1]}"
else
  fail "Cannot determine GNOME Shell version: $shell_raw"
fi
say "GNOME version detected: $shell_raw (major $major)"

say 'Window controls: minimize, maximize, close on the right'
gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'

say 'Installing only GNOME-version-compatible extensions from extensions.gnome.org'
installed_uuids=()
failed_uuids=()
install_from_ego() {
  local uuid="$1" name="$2" target
  target="$(mktemp --suffix=.zip)"
  # Official GNOME Extensions API chooses an approved build for the current shell version.
  if python3 - "$major" "$uuid" "$target" <<'PY'
import io
import json
import pathlib
import sys
import urllib.parse
import urllib.request
import zipfile

major, uuid, output = sys.argv[1:]
base = 'https://extensions.gnome.org'
query = urllib.parse.urlencode({'uuid': uuid, 'shell_version': major})
request = urllib.request.Request(f'{base}/extension-info/?{query}', headers={'User-Agent': 'Arch-GNOME-TWEAKS/1.0'})
with urllib.request.urlopen(request, timeout=30) as response:
    info = json.load(response)
version_map = info.get('shell_version_map', {})
item = version_map.get(major)
if not isinstance(item, dict) or not isinstance(item.get('pk'), int):
    raise SystemExit(f'No approved extension release for GNOME {major}: {uuid}')
# The download endpoint uses the reviewed version_tag from shell_version_map.
url = f'{base}/download-extension/{urllib.parse.quote(uuid, safe="")}.shell-extension.zip?version_tag={item["pk"]}'
request = urllib.request.Request(url, headers={'User-Agent': 'Arch-GNOME-TWEAKS/1.0'})
with urllib.request.urlopen(request, timeout=90) as response:
    blob = response.read(30 * 1024 * 1024 + 1)
if len(blob) > 30 * 1024 * 1024:
    raise SystemExit('Extension archive too large')
with zipfile.ZipFile(io.BytesIO(blob)) as archive:
    members = archive.infolist()
    names = [m.filename for m in members]
    if len(members) > 5000 or not members:
        raise SystemExit('Invalid zip entry count')
    for m in members:
        p = pathlib.PurePosixPath(m.filename)
        if p.is_absolute() or '..' in p.parts or '\\' in m.filename:
            raise SystemExit(f'Unsafe zip path: {m.filename}')
    if 'metadata.json' not in names:
        raise SystemExit('No metadata.json in official archive')
    meta = json.loads(archive.read('metadata.json'))
    if meta.get('uuid') != uuid or major not in meta.get('shell-version', []):
        raise SystemExit(f'Extension metadata is not compatible with GNOME {major}')
pathlib.Path(output).write_bytes(blob)
print(f'Verified {uuid}: GNOME {major}, release {item.get("version", "unknown")}')
PY
  then
    if gnome-extensions install --force "$target"; then
      say "Installed: $name"
      installed_uuids+=("$uuid")
    else
      warn "$name: GNOME extension install failed; preserving other settings"
      failed_uuids+=("$uuid")
    fi
  else
    warn "$name: compatible verified archive unavailable; skipped"
    failed_uuids+=("$uuid")
  fi
  rm -f "$target"
}

install_from_ego 'dash-to-dock@micxgx.gmail.com' 'Dash to Dock'
install_from_ego 'blur-my-shell@aunetx' 'Blur my Shell'
install_from_ego 'just-perfection-desktop@just-perfection' 'Just Perfection'

app_uuid='appindicatorsupport@rgcjonas.gmail.com'
app_meta="/usr/share/gnome-shell/extensions/$app_uuid/metadata.json"
if [[ -f "$app_meta" ]] && python3 - "$major" "$app_meta" <<'PY'
import json, sys
major, path = sys.argv[1:]
with open(path, encoding='utf-8') as f:
    metadata = json.load(f)
sys.exit(0 if major in metadata.get('shell-version', []) else 1)
PY
then
  say 'AppIndicator official Arch package matches this GNOME version'
  installed_uuids+=("$app_uuid")
else
  warn "AppIndicator official package not marked compatible with GNOME $major; leaving disabled"
  failed_uuids+=("$app_uuid")
fi

say 'Configure bottom, always-visible Dash to Dock (if installed)'
dock_dir="$HOME/.local/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com"
dock_schema='org.gnome.shell.extensions.dash-to-dock'
if [[ " ${installed_uuids[*]} " == *' dash-to-dock@micxgx.gmail.com '* ]]; then
  schemas="$dock_dir/schemas"
  if [[ -d "$schemas" ]]; then
    if [[ ! -f "$schemas/gschemas.compiled" ]] && command -v glib-compile-schemas >/dev/null; then
      glib-compile-schemas "$schemas" || warn 'Could not compile dock GSettings schema'
    fi
    dock_set() {
      local key="$1" value="$2"
      if gsettings --schemadir "$schemas" writable "$dock_schema" "$key" 2>/dev/null | grep -qx true; then
        gsettings --schemadir "$schemas" set "$dock_schema" "$key" "$value"
      else
        warn "Dock setting unavailable: $key"
      fi
    }
    dock_set dock-position BOTTOM
    dock_set dock-fixed false
    dock_set autohide true
    dock_set intellihide true
    dock_set dash-max-icon-size 46
    dock_set extend-height false
  else
    warn 'Dock schema not found; extension installed but dock preferences need manual adjustment'
  fi
fi

say 'Mark compatible extensions enabled without clearing existing extensions'
# On Wayland new extensions become visible to the running Shell only after logout/login.
python3 - "${installed_uuids[@]}" <<'PY'
import ast
import subprocess
import sys
schema = 'org.gnome.shell'
key = 'enabled-extensions'
raw = subprocess.check_output(['gsettings', 'get', schema, key], text=True).strip()
if raw.startswith('@as '):
    raw = raw[4:]
try:
    enabled = ast.literal_eval(raw)
except (SyntaxError, ValueError) as exc:
    raise SystemExit(f'Could not safely parse existing extension list: {exc}')
if not isinstance(enabled, list) or any(not isinstance(x, str) for x in enabled):
    raise SystemExit('Unexpected GNOME enabled-extensions data; refusing to overwrite')
for uuid in sys.argv[1:]:
    if uuid not in enabled:
        enabled.append(uuid)
subprocess.run(['gsettings', 'set', schema, key, str(enabled)], check=True)
print('Enabled or staged:', ', '.join(sys.argv[1:]) or '(none)')
PY

say 'Disk space GUI tools'
if command -v baobab >/dev/null; then say 'Open "Disk Usage Analyzer" from the applications menu to see used/free space'; fi
if command -v gnome-disks >/dev/null; then say 'Open "Disks" to see SSD models, partitions and capacity'; fi
say 'Installing Windows-like GNOME shortcuts'
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/windows-shortcuts.sh" ]]; then
  bash "$(dirname "${BASH_SOURCE[0]}")/windows-shortcuts.sh" || warn 'Keyboard shortcuts could not be fully configured; see backup and log'
else
  warn 'windows-shortcuts.sh missing; shortcut setup skipped'
fi

say 'Verifying final configuration'
[[ "$(gsettings get org.gnome.desktop.wm.preferences button-layout)" == *minimize,maximize,close* ]] && say 'Window buttons configured' || warn 'Window buttons not applied'
for uuid in "${installed_uuids[@]}"; do
  if gsettings get org.gnome.shell enabled-extensions | grep -Fq "$uuid"; then
    printf '[OK] Extension staged: %s\n' "$uuid"
  else
    warn "Extension not enabled: $uuid"
  fi
done
if ((${#failed_uuids[@]})); then
  warn "These extensions were skipped; see log and GNOME Extensions: ${failed_uuids[*]}"
fi
printf '\nDone. Settings backup: %s\n' "$backup_dir"
printf '%s\n' 'IMPORTANT: Log out of GNOME and log back in once (Wayland extension activation).'
printf '%s\n' 'Manage extensions via the GNOME Extensions app. See TWEAKS.md for restoration.'