#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY_NAME="WalNotify"
INSTALL_DIR="$HOME/.local/bin"
SIGN_IDENTITY="-"

echo "==> Building $BINARY_NAME..."
cd "$SCRIPT_DIR"
swift build -c release 2>&1

BUILT_BINARY="$SCRIPT_DIR/.build/release/$BINARY_NAME"
if [ ! -f "$BUILT_BINARY" ]; then
    echo "ERROR: Build failed"
    exit 1
fi

echo "==> Installing to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
cp "$BUILT_BINARY" "$INSTALL_DIR/$BINARY_NAME"
chmod +x "$INSTALL_DIR/$BINARY_NAME"

echo "==> Signing..."
codesign --force --options runtime --sign "$SIGN_IDENTITY" "$INSTALL_DIR/$BINARY_NAME"

echo "==> Seeding optional config..."
CFG_DIR="$HOME/.config/walnotify"
mkdir -p "$CFG_DIR"
if [ ! -f "$CFG_DIR/config.json" ]; then
cat > "$CFG_DIR/config.json" << 'JSON'
{
  "prefix": "wallpaper changed  ·  ",
  "fontSize": 13,
  "accentBarWidth": 5,
  "paddingX": 16,
  "paddingY": 14,
  "cornerRadius": 10,
  "marginRight": 24,
  "marginTop": 52,
  "durationSeconds": 3.0,
  "maxAlpha": 0.95,
  "maxWidth": 600,
  "minHeight": 44,
  "textYOffset": 0
}
JSON
fi

echo ""
echo "✓ WalNotify installed to $INSTALL_DIR/$BINARY_NAME"
echo ""
echo "  Test it:   ~/.local/bin/WalNotify \"crymelt2.png\""
echo "  Config:    ~/.config/walnotify/config.json"
echo ""
echo "  Update your ~/.config/wal/postrun to call:"
echo "    ~/.local/bin/WalNotify \"\$WALLPAPER_NAME\""
echo "  instead of the old python wal-notify.py"
