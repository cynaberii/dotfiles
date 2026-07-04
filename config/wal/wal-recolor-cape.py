#!/usr/bin/env python3
# (recolour a mousecape .cape file from the current pywal palette.
# usage: wal-recolor-cape.py <input.cape> <output.cape>)
import sys
import json
import plistlib
import io
import os
import numpy as np
from PIL import Image

def hex_to_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def load_wal_colors():
    wal_json = os.path.expanduser("~/.cache/wal/colors.json")
    with open(wal_json) as f:
        data = json.load(f)
    return data

def recolor_image_bytes(raw_bytes, color_map):
    img = Image.open(io.BytesIO(raw_bytes)).convert('RGBA')
    arr = np.array(img, dtype=np.uint8)
    result = arr.copy()
    for src, tgt in color_map.items():
        mask = (arr[:,:,0] == src[0]) & (arr[:,:,1] == src[1]) & (arr[:,:,2] == src[2])
        result[mask, 0] = tgt[0]
        result[mask, 1] = tgt[1]
        result[mask, 2] = tgt[2]
    out = Image.fromarray(result)
    buf = io.BytesIO()
    out.save(buf, format='TIFF')
    return buf.getvalue()

def main():
    if len(sys.argv) != 3:
        print("Usage: wal-recolor-cape.py <input.cape> <output.cape>")
        sys.exit(1)

    input_cape  = sys.argv[1]
    output_cape = sys.argv[2]

    wal = load_wal_colors()
    c   = wal['colors']

    src_dark_green  = (0x4A, 0x9E, 0x7E)
    src_mid_green   = (0x6D, 0xC4, 0xA0)
    src_light_green = (0x95, 0xD1, 0xB7)
    src_pink        = (0xF0, 0xA9, 0xC7)
    src_highlight   = (0xD3, 0xE5, 0xFF)

    color_map = {
        src_dark_green:  hex_to_rgb(c['color2']),
        src_mid_green:   hex_to_rgb(c['color10']),
        src_light_green: hex_to_rgb(c['color13']),
        src_pink:        hex_to_rgb(c['color3']),
        src_highlight:   hex_to_rgb(c['color14']),
    }

    with open(input_cape, 'rb') as f:
        cape = plistlib.load(f)

    for cursor_name, cursor in cape['Cursors'].items():
        try:
            raw = cursor['Representations'][0]
            cursor['Representations'][0] = recolor_image_bytes(raw, color_map)
        except Exception as e:
            print(f"  skipping {cursor_name}: {e}")

    # (patch metadata so each wallpaper is a distinct cape in mousecape)
    wallpaper_name = os.path.splitext(os.path.basename(output_cape))[0]
    cape['CapeName']   = wallpaper_name
    cape['Identifier'] = f"com.wal.{wallpaper_name.replace(' ', '-').lower()}"
    cape['Author']     = 'wal'

    with open(output_cape, 'wb') as f:
        plistlib.dump(cape, f, fmt=plistlib.FMT_BINARY)
    print(f"recolored cape written to {output_cape}")

if __name__ == '__main__':
    main()
