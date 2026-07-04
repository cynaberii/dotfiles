#!/usr/bin/env python3
import sys, re
path = sys.argv[1]
brightness = sys.argv[2] if len(sys.argv) > 2 else "0.5"
saturation = sys.argv[3] if len(sys.argv) > 3 else "0.8"
contrast   = sys.argv[4] if len(sys.argv) > 4 else "0.85"

with open(path) as f:
    s = f.read()

# (only touch UNIVERSAL_BOOST_OPTIONS, leave the per-site blocks alone)
m = re.search(r'(const UNIVERSAL_BOOST_OPTIONS = \{.*?\n\};)', s, re.DOTALL)
if not m:
    print("ERROR: UNIVERSAL_BOOST_OPTIONS block not found"); sys.exit(1)
block = m.group(1)
new = block
new = re.sub(r'brightness:\s*[\d.]+', f'brightness: {brightness}', new)
new = re.sub(r'saturation:\s*[\d.]+', f'saturation: {saturation}', new)
new = re.sub(r'contrast:\s*[\d.]+',   f'contrast: {contrast}',   new)
s = s.replace(block, new, 1)

with open(path, "w") as f:
    f.write(s)
print(f"Set universal tint → brightness={brightness}, saturation={saturation}, contrast={contrast}")
