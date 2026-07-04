"""
Generate a colorscheme spread across the full luminance range.
Picks colors from dark, mid, and light zones of the image
so the palette always has contrast and balance.
"""

import logging
import sys
import colorsys

try:
    from PIL import Image
    import numpy as np
except ImportError:
    logging.error("Pillow and numpy are required for this backend.")
    logging.error("pip3 install Pillow numpy --break-system-packages")
    sys.exit(1)

from .. import util
from .. import colors as colors_module


def hex_to_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


def rgb_to_hex(r, g, b):
    return "#%02x%02x%02x" % (int(r), int(g), int(b))


def luminance(r, g, b):
    """Perceived luminance (0-1)."""
    return 0.299 * r + 0.587 * g + 0.114 * b


def kmeans_zone(pixels, k, max_iter=50):
    """Simple k-means on a pixel array."""
    if len(pixels) == 0:
        return []
    k = min(k, len(pixels))          # can't have more clusters than pixels
    idx = np.random.choice(len(pixels), k, replace=False)
    centers = pixels[idx].astype(float)
    for _ in range(max_iter):
        dists = np.linalg.norm(pixels[:, None] - centers[None, :], axis=2)
        labels = np.argmin(dists, axis=1)
        new_centers = np.array([
            pixels[labels == i].mean(axis=0) if (labels == i).any() else centers[i]
            for i in range(k)
        ])
        if np.allclose(centers, new_centers, atol=1):
            break
        centers = new_centers
    # Sort by cluster size descending
    sizes = [(labels == i).sum() for i in range(k)]
    order = np.argsort(sizes)[::-1]
    return [centers[i] for i in order]


def gen_colors(img):
    """
    Extract colors spread across the luminance range.
    Returns 16 hex colors:
      - 2 very dark (shadows)
      - 6 mid-dark (main palette, colors 1-6)
      - 2 mid-light
      - 6 light (bright variants, colors 9-14)
      - color0 = darkest, color7/15 = lightest
    """
    image = Image.open(img).convert('RGB')
    # Resize for speed
    image = image.resize((150, 150))
    arr = np.array(image, dtype=np.float32)
    pixels = arr.reshape(-1, 3)

    # Compute luminance for each pixel
    lums = (0.299 * pixels[:, 0] + 0.587 * pixels[:, 1] + 0.114 * pixels[:, 2]) / 255.0

    # Split into zones
    dark_mask   = lums < 0.25
    mid_mask    = (lums >= 0.25) & (lums < 0.60)
    light_mask  = lums >= 0.60

    dark_px  = pixels[dark_mask]
    mid_px   = pixels[mid_mask]
    light_px = pixels[light_mask]

    # fallback: if a zone is too sparse, pull from neighbours
    if len(dark_px) < 50:
        dark_px = pixels[lums < 0.40]
    if len(mid_px) < 50:
        mid_px = pixels
    if len(light_px) < 50:
        light_px = pixels[lums > 0.50]

    # Sample to speed up k-means
    def sample(px, n=2000):
        if len(px) > n:
            idx = np.random.choice(len(px), n, replace=False)
            return px[idx]
        return px

    dark_centers  = kmeans_zone(sample(dark_px),  k=3)
    mid_centers   = kmeans_zone(sample(mid_px),   k=8)
    light_centers = kmeans_zone(sample(light_px), k=5)

    def centers_to_hex(centers):
        return [rgb_to_hex(*c) for c in centers]

    darks  = centers_to_hex(dark_centers)
    mids   = centers_to_hex(mid_centers)
    lights = centers_to_hex(light_centers)

    # (a near solid-colour image can leave a zone empty, so seed it from the
    # image's darkest / mean / lightest pixel so the padding below has smth to grow)
    if not darks:  darks  = [rgb_to_hex(*pixels[np.argmin(lums)])]
    if not mids:   mids   = [rgb_to_hex(*pixels.mean(axis=0))]
    if not lights: lights = [rgb_to_hex(*pixels[np.argmax(lums)])]

    # Pad zones if needed
    while len(darks)  < 3:  darks.append(darks[-1])
    while len(mids)   < 8:  mids.append(mids[-1])
    while len(lights) < 5:  lights.append(lights[-1])

    # Sort each zone by luminance
    darks.sort(key=lambda h: luminance(*hex_to_rgb(h)))
    mids.sort(key=lambda h: luminance(*hex_to_rgb(h)))
    lights.sort(key=lambda h: luminance(*hex_to_rgb(h)))

    # Build 16-slot palette
    # 0         = darkest dark (bg)
    # 1-6       = mid colors (accent palette)
    # 7         = lightest light (fg)
    # 8         = second dark (bright bg)
    # 9-14      = lightened mids (bright accents)
    # 15        = lightest light (bright fg)

    color0  = darks[0]
    color8  = darks[1] if len(darks) > 1 else util.lighten_color(darks[0], 0.15)
    color7  = lights[-1]
    color15 = lights[-1]

    # Mid colors: pick 6 spread across mids
    mid6 = [mids[i] for i in [0, 1, 3, 4, 5, 6]] if len(mids) >= 7 else mids[:6]
    while len(mid6) < 6:
        mid6.append(mid6[-1])

    # Bright variants: lighten mid colors
    bright6 = [util.lighten_color(c, 0.25) for c in mid6]

    raw = [
        color0,           # 0  bg
        mid6[0],          # 1
        mid6[1],          # 2
        mid6[2],          # 3
        mid6[3],          # 4
        mid6[4],          # 5
        mid6[5],          # 6
        color7,           # 7  fg
        color8,           # 8  bright bg
        bright6[0],       # 9
        bright6[1],       # 10
        bright6[2],       # 11
        bright6[3],       # 12
        bright6[4],       # 13
        bright6[5],       # 14
        color15,          # 15 bright fg
    ]

    return raw


# Light-mode tunables. gen_colors() builds a dark palette (color0 = darkest = bg,
# color7/15 = lightest = fg); make_light() flips those roles so bg comes from the
# light end and text from the dark end, keeping the hues. All values are 0-1
# blend-toward-white/black amounts.
LIGHT_BG_LIGHTEN       = 0.45   # push background toward white for a clean light surface
LIGHT_SURFACE_DARKEN   = 0.08   # color8 = bg darkened slightly (UI surfaces / bright-bg)
LIGHT_FG_DARKEN        = 0.25   # push main text toward black
LIGHT_FG_BRIGHT_DARKEN = 0.40   # color15 (bright fg) darker still
LIGHT_ACCENT_DARKEN    = 0.32   # darken mid accents (1-6) so they read on light bg
LIGHT_BRIGHT_DARKEN    = 0.18   # darken bright accents (9-14) a touch less


def make_light(cols):
    """Flip the dark palette into a light one: light background, dark text,
    accents darkened for contrast. Preserves the image's hues."""
    darkest  = cols[0]
    lightest = cols[15]
    new = list(cols)

    # Background from the LIGHT end, pushed lighter for a clean light surface.
    new[0] = util.lighten_color(lightest, LIGHT_BG_LIGHTEN)
    new[8] = util.darken_color(new[0], LIGHT_SURFACE_DARKEN)

    # Foreground / text from the DARK end, pushed darker for contrast.
    new[7]  = util.darken_color(darkest, LIGHT_FG_DARKEN)
    new[15] = util.darken_color(darkest, LIGHT_FG_BRIGHT_DARKEN)

    # Accent colors (1-6): darken the mids so they contrast on the light bg.
    for i in range(1, 7):
        new[i] = util.darken_color(cols[i], LIGHT_ACCENT_DARKEN)

    # Bright accents (9-14): darkened mids, slightly lighter than the 1-6 set.
    for i in range(9, 15):
        new[i] = util.darken_color(cols[i - 8], LIGHT_BRIGHT_DARKEN)

    return new


def adjust(cols, light, **kwargs):
    """Final balance pass. Dark: keep bg dark. Light: flip to a light palette."""
    if light:
        return make_light(cols)
    # Ensure bg is dark enough
    if cols[0][1] not in ('0', '1', '2'):
        cols[0] = util.darken_color(cols[0], 0.40)
    return cols


def get(img, light=False, **kwargs):
    """Get colorscheme."""
    np.random.seed(42)  # reproducible results for same image
    cols = gen_colors(img)
    return adjust(cols, light)
