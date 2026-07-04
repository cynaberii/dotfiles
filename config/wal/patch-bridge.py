#!/usr/bin/env python3
import sys, re

path = sys.argv[1]
with open(path) as f:
    src = f.read()

if '"youtube.com": "youtube"' not in src:
    src = src.replace(
        '  "raw.githubusercontent.com": "github",\n};',
        '  "raw.githubusercontent.com": "github",\n'
        '  "youtube.com": "youtube",\n'
        '  "www.youtube.com": "youtube",\n'
        '  "m.youtube.com": "youtube",\n};'
    )

if '"youtube.com": {' not in src:
    yt_block = (
        '  },\n'
        '  "youtube.com": {\n'
        '    cssFile: "matugen-userstyles-youtube.css",\n'
        '    options: {\n'
        '      boostName: "matugen youtube",\n'
        '      enableColorBoost: false,\n'
        '      autoTheme: false,\n'
        '      smartInvert: false,\n'
        '      brightness: 0.5,\n'
        '      saturation: 0.5,\n'
        '      contrast: 0.75,\n'
        '      changeWasMade: true,\n'
        '    },\n'
        '  },\n'
        '};'
    )
    marker = '      changeWasMade: true, // <-- required: parent actor checks this\n      //     before returning the stylesheet\n    },\n  },\n};'
    if marker in src:
        replacement = (
            '      changeWasMade: true, // <-- required: parent actor checks this\n'
            '      //     before returning the stylesheet\n'
            '    },\n' + yt_block
        )
        src = src.replace(marker, replacement, 1)
    else:
        print("WARN: BOOST_SITES marker not found exactly; trying fallback")
        m = re.search(r'(changeWasMade: true,[^\n]*\n[^\n]*\n\s*\},\n\s*\},\n\};)', src)
        if m:
            src = src.replace(m.group(1),
                m.group(1).rsplit('};',1)[0] + yt_block.split('  },\n',1)[1], 1)

with open(path, 'w') as f:
    f.write(src)

ok_host = '"youtube.com": "youtube"' in src
ok_boost = '"youtube.com": {' in src
print(f"HOST_TO_FILE youtube added: {ok_host}")
print(f"BOOST_SITES youtube added: {ok_boost}")
