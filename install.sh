#!/usr/bin/env bash
# (symlink the configs, wire the balanced pywal backend in, set up the
# wallpaper-watch LaunchAgent, point at the swift builds. re-runnable: existing links
# are left alone, anything it would clobber is backed up first.)
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.dotfiles-install-backup-$(date +%Y%m%d-%H%M%S)"

link() {  # $1 = repo source, $2 = target location
  local src="$1" dst="$2"
  [ -e "$src" ] || { echo "  skip (missing in repo): $src"; return; }
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "  ok   ${dst/#$HOME/\~}"; return
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mkdir -p "$BACKUP"; mv "$dst" "$BACKUP/"; echo "  backed up existing ${dst/#$HOME/\~}"
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  echo "  link ${dst/#$HOME/\~} -> ${src/#$HOME/\~}"
}

echo "==> Linking ~/.config entries"
for d in sketchybar borders aerospace btop spotify-player nvim yazi wal \
         wallpaperpeek walnotify workspacepeek cava rift; do
  link "$REPO/config/$d" "$HOME/.config/$d"
done
link "$REPO/config/starship.toml" "$HOME/.config/starship.toml"
link "$REPO/config/wezterm/wezterm.lua" "$HOME/.wezterm.lua"

echo "==> Seeding sketchybar colours (fallback until pywal makes its own)"
# (the bar sources ~/.cache/wal/colors-sketchybar.sh. without pywal it's missing
# and the bar goes invisible, so seed the fallback. pywal overwrites it later.)
WAL_SB="$HOME/.cache/wal/colors-sketchybar.sh"
if [ ! -f "$WAL_SB" ]; then
  mkdir -p "$(dirname "$WAL_SB")"
  cp "$REPO/config/sketchybar/colors-fallback.sh" "$WAL_SB"
  echo "  seeded ${WAL_SB/#$HOME/\~}"
else
  echo "  ok   ${WAL_SB/#$HOME/\~} already there"
fi

echo "==> Linking ~/.local/bin scripts"
for f in ws-capture.sh wallpaper-pick wallpaper-picker.py aerospace-switcher.py; do
  link "$REPO/bin/$f" "$HOME/.local/bin/$f"
done

echo "==> Wiring the custom pywal 'balanced' backend"
BACKENDS_DIR="$(python3 -c 'import pywal, os; print(os.path.join(os.path.dirname(pywal.__file__), "backends"))' 2>/dev/null \
  || ~/miniconda3/bin/python3 -c 'import pywal, os; print(os.path.join(os.path.dirname(pywal.__file__), "backends"))' 2>/dev/null)"
if [ -n "${BACKENDS_DIR:-}" ] && [ -d "$BACKENDS_DIR" ]; then
  link "$REPO/pywal-backend/balanced.py" "$BACKENDS_DIR/balanced.py"
else
  echo "  WARN: could not locate pywal backends dir - install pywal, then re-run."
fi

echo "==> Installing the wallpaper-watch LaunchAgent"
link "$REPO/launchagents/com.user.wal-watch.plist" "$HOME/Library/LaunchAgents/com.user.wal-watch.plist"
launchctl bootout "gui/$(id -u)/com.user.wal-watch" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.user.wal-watch.plist" 2>/dev/null || true

echo "==> Swift apps"
echo "  Build + install each with its own install.sh (needs your Apple signing identity):"
for app in WorkspacePeek WallpaperPeek WalNotify; do
  echo "    (cd \"$REPO/swift/$app\" && ./install.sh)"
done

echo
echo "✓ Link step complete."
[ -d "$BACKUP" ] && echo "  Replaced files were backed up to: $BACKUP"
echo
echo "Next:"
echo "  • Reload: sketchybar --reload ; brew services restart borders ; aerospace reload-config"
echo "  • Light/dark: ~/.config/wal/wal-mode.sh light | dark | toggle"
