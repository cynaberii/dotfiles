#!/usr/bin/env bash
PLIST="$HOME/Library/Application Support/com.apple.wallpaper/Store/Index.plist"
LAST_IMAGE=""

echo "watching for wallpaper changes..."

/opt/homebrew/bin/fswatch -o "$PLIST" | while read -r; do
  IMAGE=$(plutil -convert xml1 -o - "$PLIST" 2>/dev/null | python3 -c "
import sys, re
from urllib.parse import unquote
xml = sys.stdin.read()
matches = re.findall(r'<string>(file:///[^<]+)</string>', xml)
if matches:
    path = unquote(matches[-1].replace('file://', ''))
    print(path)
" 2>/dev/null)

  if [[ -z "$IMAGE" ]] || [[ ! -f "$IMAGE" ]]; then
    continue
  fi

  if [[ "$IMAGE" == "$LAST_IMAGE" ]]; then
    continue
  fi

  LAST_IMAGE="$IMAGE"

  echo "wallpaper changed → $IMAGE"
  # (keep the last-chosen light/dark, default dark)
  LIGHT_FLAG=""
  [[ "$(cat "$HOME/.cache/wal/appearance" 2>/dev/null)" == "light" ]] && LIGHT_FLAG="-l"
  # (-n = don't set the wallpaper, raycast already did, avoids a feedback loop)
  $HOME/miniconda3/bin/wal -i "$IMAGE" --backend balanced $LIGHT_FLAG -n
  bash "$HOME/.config/wal/postrun"
  echo "postrun done"
done
