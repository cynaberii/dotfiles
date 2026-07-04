#!/usr/bin/env bash
# (fresh-machine setup, run it from inside a clone of this repo. installs the brew
# deps, symlinks the configs w/ install.sh, and builds the Swift apps. safe to re-run.)
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# (Xcode Command Line Tools, needed for swift)
xcode-select -p >/dev/null 2>&1 || xcode-select --install

# (Homebrew)
if ! command -v brew >/dev/null 2>&1; then
  echo "==> installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# (the installer doesn't add brew to the current shell, so put it on PATH for the
# rest of this script - /opt/homebrew on Apple Silicon, /usr/local on Intel)
command -v brew >/dev/null 2>&1 || eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"

echo "==> taps"
brew tap FelixKratz/formulae    # (sketchybar + borders)
brew tap acsandmann/tap         # (rift)

echo "==> core tools"
brew install acsandmann/tap/rift FelixKratz/formulae/sketchybar FelixKratz/formulae/borders \
  starship yazi btop cava spotify_player fzf jq gh
brew install --cask wezterm font-jetbrains-mono-nerd-font

# (skipping pywal, it's optional and a bit personal. everything falls back to a
# built-in palette without it. want wallpaper-driven colours? set it up yourself
# and see the readme's "customising the colours" bit.)

echo "==> optional extras (Neru keyboard-nav, AeroSpace as an alt WM)"
brew install y3owk1n/tap/neru || true
brew install --cask nikitabobko/tap/aerospace || true

echo "==> symlinking configs + wiring the pywal backend"
bash "$REPO/install.sh"

echo "==> building WalNotify"
( cd "$REPO/swift/WalNotify" && ./install.sh )

# (WorkspacePeek + WallpaperPeek are their own repos, so clone + build them. the
# URLs need to be public, or you gh-auth'd, for the clone to work.)
echo "==> WorkspacePeek + WallpaperPeek"
APPS_DIR="${TMPDIR:-/tmp}/rice-apps"
mkdir -p "$APPS_DIR"
for app in WorkspacePeek WallpaperPeek; do
  if [ ! -d "$APPS_DIR/$app" ]; then
    # (gh clone uses your login so it works while these are still private, and
    # falls back to a plain public clone if gh isn't around)
    gh repo clone "cynaberii/$app" "$APPS_DIR/$app" 2>/dev/null \
      || git clone "https://github.com/cynaberii/$app.git" "$APPS_DIR/$app"
  fi
  ( cd "$APPS_DIR/$app" && ./install.sh )
done

echo ""
echo "✓ done. still manual: Zen browser + Sine mods, and Mousecape for cursors."
echo "  grant Accessibility + Screen Recording when macOS prompts, then start rift."
