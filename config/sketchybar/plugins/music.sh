#!/usr/bin/env bash
source "$HOME/.cache/wal/colors-sketchybar.sh"

# (single-instance guard, skip this tick if a previous run is still alive. dead
# PID gets taken over.)
LOCK="/tmp/sketchybar-music.lock"
if [[ -f "$LOCK" ]] && kill -0 "$(cat "$LOCK" 2>/dev/null)" 2>/dev/null; then
  exit 0
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

# (bail if spotify_player isn't logged in, else `get key playback` reopens an
# auth tab every tick. draw nothing till the creds exist.)
SP_CACHE="$HOME/.cache/spotify-player"
if [[ ! -f "$SP_CACHE/credentials.json" || ! -f "$SP_CACHE/user_client_token.json" ]]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

# (timeout, `spotify_player get key playback` can block forever when the daemon hangs)
to() { perl -e 'alarm shift; exec @ARGV' "$@"; }

PLAYBACK=$(to 5 spotify_player get key playback 2>/dev/null)
if [[ -z "$PLAYBACK" ]]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

IS_PLAYING=$(echo "$PLAYBACK" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('is_playing','false'))" 2>/dev/null)
if [[ "$IS_PLAYING" != "True" ]]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

TRACK=$(echo "$PLAYBACK" | python3 -c "
import sys, json
d = json.load(sys.stdin)
item = d.get('item', {})
name = item.get('name', '')
artists = item.get('artists', [{}])
artist = artists[0].get('name', '') if artists else ''
print(f'{artist} - {name}')
" 2>/dev/null)

META=$(echo "$PLAYBACK" | python3 -c "
import sys, json
d = json.load(sys.stdin)
item = d.get('item', {})
album = item.get('album', {})
images = album.get('images', [])
url = images[-1]['url'] if images else ''
artists = item.get('artists', [{}])
artist = artists[0].get('name', '') if artists else ''
print(url)
print(album.get('name', ''))
print(artist)
" 2>/dev/null)
{ read -r ART_URL; read -r ALBUM; read -r ARTIST; } <<< "$META"

ART_PATH="/tmp/sketchybar-album-raw.jpg"
ART_CROPPED="/tmp/sketchybar-album.jpg"
ART_SRC=""
PY=$HOME/miniconda3/bin/python3
FF=$HOME/miniconda3/bin/ffmpeg

# (1: streaming, artwork url from the web api)
if [[ -n "$ART_URL" ]]; then
  curl -s --max-time 8 -o "$ART_PATH" "$ART_URL" && [[ -s "$ART_PATH" ]] && ART_SRC="$ART_PATH"
fi

# (2: local, reuse spotify_player's own cover cache)
if [[ -z "$ART_SRC" && -n "$ALBUM" ]]; then
  CACHE=$("$PY" -c "
import os, sys
album, artist = sys.argv[1], sys.argv[2]
d = os.path.expanduser('~/.cache/spotify-player/image')
pre = f'{album}-{artist}-cover-'
m = [f for f in os.listdir(d) if f.startswith(pre)] if os.path.isdir(d) else []
print(os.path.join(d, m[0]) if m else '')
" "$ALBUM" "$ARTIST" 2>/dev/null)
  [[ -n "$CACHE" && -s "$CACHE" ]] && ART_SRC="$CACHE"
fi

# (3: local, pull embedded art straight from the file in ~/Music)
if [[ -z "$ART_SRC" && -n "$ALBUM" ]]; then
  DIR=$(find "$HOME/Music" -type d -iname "$ALBUM" -print -quit 2>/dev/null)
  if [[ -n "$DIR" ]]; then
    FILE=$(find "$DIR" -maxdepth 1 -type f \
      \( -iname '*.flac' -o -iname '*.mp3' -o -iname '*.m4a' -o -iname '*.ogg' \) \
      -print -quit 2>/dev/null)
    if [[ -n "$FILE" ]]; then
      "$FF" -y -v error -i "$FILE" -an -frames:v 1 "$ART_PATH" 2>/dev/null \
        && [[ -s "$ART_PATH" ]] && ART_SRC="$ART_PATH"
    fi
  fi
fi

if [[ -n "$ART_SRC" ]]; then
  "$PY" -c "
import sys
from PIL import Image
img = Image.open(sys.argv[1]).convert('RGB')
# (square crop from centre)
w, h = img.size
s = min(w, h)
img = img.crop(((w-s)//2, (h-s)//2, (w+s)//2, (h+s)//2))
img = img.resize((26, 26), Image.LANCZOS)
img.save('$ART_CROPPED')
" "$ART_SRC"
  sketchybar --set "$NAME" \
    icon="" \
    icon.background.image="$ART_CROPPED" \
    icon.background.drawing=on \
    icon.background.corner_radius=4 \
    icon.background.height=26 \
    icon.width=26 \
    label="$TRACK" \
    label.color=$WHITE \
    drawing=on
else
  sketchybar --set "$NAME" \
    icon="󰎆" \
    icon.color=$WHITE \
    icon.align=center \
    icon.background.drawing=off \
    icon.width=26 \
    label="$TRACK" \
    label.color=$WHITE \
    drawing=on
fi
