#!/usr/bin/env python3
# (generate a vencord translucence css theme for the current wallpaper. reuses an
# existing css if there is one, else uploads the wallpaper to imgbb and makes a new
# one. called from postrun.)

import sys
import os
import json
import re
import colorsys
import urllib.request
import urllib.parse

IMGBB_API_KEY  = os.environ.get("IMGBB_API_KEY", "")  # export IMGBB_API_KEY in your shell
VENCORD_THEMES = os.path.expanduser("~/Library/Application Support/Vencord/themes")
WAL_CACHE      = os.path.expanduser("~/.cache/wal")
# (the permanently-enabled theme in vencord. mirror the active css here each change
# so discord re-injects it live.)
STABLE_THEME   = "pywal.css"


def load_wal_colors():
    with open(os.path.join(WAL_CACHE, "colors.json")) as f:
        return json.load(f)


def hex_to_hsl(h):
    h = h.lstrip("#")
    r, g, b = int(h[0:2], 16)/255, int(h[2:4], 16)/255, int(h[4:6], 16)/255
    hue, lum, sat = colorsys.rgb_to_hls(r, g, b)
    return round(hue * 360), round(sat * 100, 1), round(lum * 100, 1)


def luminance(h):
    h = h.lstrip("#")
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return 0.299*r + 0.587*g + 0.114*b


def get_accent_color(colors):
    """Pick the most colorful mid-tone color for the accent."""
    candidates = [colors["colors"][f"color{i}"] for i in range(1, 8)]
    def saturation(h):
        h = h.lstrip("#")
        r, g, b = int(h[0:2], 16)/255, int(h[2:4], 16)/255, int(h[4:6], 16)/255
        _, _, s = colorsys.rgb_to_hls(r, g, b)
        return s
    return max(candidates, key=saturation)


def get_text_colors(colors):
    """Return light colors from palette for text."""
    all_colors = list(colors["colors"].values())
    sorted_by_lum = sorted(all_colors, key=luminance, reverse=True)
    lightest     = sorted_by_lum[0]   # primary text
    second_light = sorted_by_lum[1]   # secondary text
    third_light  = sorted_by_lum[2]   # channel names
    muted        = sorted_by_lum[-2]  # muted/inactive

    def to_hsl_str(h):
        hue, sat, lum = hex_to_hsl(h)
        return f"hsl({hue},{sat}%,{lum}%)"

    return {
        "primary":   to_hsl_str(lightest),
        "secondary": to_hsl_str(second_light),
        "channels":  to_hsl_str(third_light),
        "muted":     to_hsl_str(muted),
    }


def upload_to_imgbb(image_path):
    """Upload image to imgbb, return the direct URL."""
    with open(image_path, "rb") as f:
        image_data = f.read()
    import base64
    encoded = base64.b64encode(image_data).decode("utf-8")
    data = urllib.parse.urlencode({
        "key":   IMGBB_API_KEY,
        "image": encoded,
        "name":  os.path.splitext(os.path.basename(image_path))[0],
    }).encode("utf-8")
    req = urllib.request.Request(
        "https://api.imgbb.com/1/upload",
        data=data,
        method="POST"
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        result = json.loads(resp.read())
    if not result.get("success"):
        raise RuntimeError(f"imgbb upload failed: {result}")
    return result["data"]["url"]


def css_name_from_wallpaper(wallpaper_path):
    """Generate a clean CSS filename from wallpaper path."""
    base = os.path.basename(wallpaper_path)
    name = os.path.splitext(base)[0]
    return name


def find_existing_css(name):
    """Check if a CSS for this wallpaper already exists."""
    css_path = os.path.join(VENCORD_THEMES, f"{name}.css")
    if os.path.exists(css_path):
        return css_path
    return None


def extract_ibb_url_from_css(css_path):
    """Extract the existing ibb URL from a CSS file."""
    with open(css_path) as f:
        content = f.read()
    match = re.search(r'--app-bg:\s*url\(([^)]+)\)', content)
    if match:
        return match.group(1)
    return None


def generate_css(name, ibb_url, wal_colors):
    """Generate the full CSS content."""
    accent     = get_accent_color(wal_colors)
    text       = get_text_colors(wal_colors)
    hue, sat, lum = hex_to_hsl(accent)

    # (reply colour = second most saturated)
    candidates = [wal_colors["colors"][f"color{i}"] for i in range(1, 8)]
    def saturation(h):
        h = h.lstrip("#")
        r, g, b = int(h[0:2], 16)/255, int(h[2:4], 16)/255, int(h[4:6], 16)/255
        _, _, s = colorsys.rgb_to_hls(r, g, b)
        return s
    sorted_by_sat = sorted(candidates, key=saturation, reverse=True)
    reply_color = sorted_by_sat[1] if len(sorted_by_sat) > 1 else sorted_by_sat[0]
    r_hue, r_sat, r_lum = hex_to_hsl(reply_color)

    return f"""/**
 * @name {name}
 * @version 1.0.6.4
 * @description A translucent/frosted glass Discord theme
 * @author CapnKitten
 *
 * @website http://github.com/CapnKitten
 * @source https://github.com/CapnKitten/BetterDiscord/blob/master/Themes/Translucence/css/source.css
 * @donate https://paypal.me/capnkitten
 * @invite jzJkA6Z
 */

@import url(https://capnkitten.github.io/BetterDiscord/Themes/Translucence/css/source.css);

:root {{
\t/* APP ELEMENTS */
\t--app-bg: url({ibb_url});
\t--app-blur: 6px;
\t--app-margin: 24px;
\t--app-radius: 8px;

\t/* ACCENT HSL AND TEXT COLOR SETTINGS */
\t--accent-hue: {hue};
\t--accent-saturation: {sat}%;
\t--accent-lightness: {lum}%;
\t--accent-opacity: 1;
\t--accent-text-color: hsl(0,0%,0%);

\t/* SIDEBARS AND CHAT AREA COLOR SETTINGS */
\t--sidebar-color: hsl(0,0%,0%,0.4);
\t--main-content-color: hsl(0,0%,0%,0.2);

\t/* MESSAGE SETTINGS */
\t--message-color: hsl(0,0%,0%,0.4);
\t--message-radius: 8px;
\t--message-padding-top: 8px;
\t--message-padding-side: 8px;

\t/* REPLY HSL COLOR SETTINGS */
\t--reply-hue: {r_hue};
\t--reply-saturation: {r_sat}%;
\t--reply-lightness: {r_lum}%;
\t--reply-opacity: 1;

\t/* TEXTAREA SETTINGS */
\t--textarea-color: 255,255,255;
\t--textarea-alpha: 0.1;
\t--textarea-alpha-focus: 0.15;
\t--textarea-text-color: hsl(0,0%,100%);
\t--textarea-radius: 22px;

\t/* CARD SETTINGS */
\t--card-color: hsl(0,0%,0%,0.4);
\t--card-color-hover: hsl(0,0%,0%,0.5);
\t--card-color-select: hsl(0,0%,0%,0.7);

\t/* BUTTON SETTINGS */
\t--button-height: 32px;
\t--button-padding: 0 16px;
\t--button-action-color: hsl(0,0%,0%);
\t--button-radius: 16px;
}}

.visual-refresh.theme-dark {{
\t/* TEXT COLOR SETTINGS */
\t--text-primary: {text['primary']};
\t--text-secondary: {text['secondary']};

\t/* CHANNEL COLOR SETTINGS */
\t--channels-default: {text['channels']};
\t--channel-icon: {text['channels']};

\t/* ICON COLOR SETTINGS */
\t--icon-primary: {text['primary']};
\t--icon-secondary: {text['secondary']};
\t--icon-tertiary: {text['channels']};

\t/* INTERACTIVE COLOR SETTINGS */
\t--interactive-normal: {text['secondary']};
\t--interactive-hover: {text['primary']};
\t--interactive-active: {text['primary']};
\t--interactive-muted: {text['muted']};

\t/* BACKGROUND MODIFIER SETTINGS */
\t--background-modifier-hover: hsl(0,0%,100%,0.075);
\t--background-modifier-selected: hsl(0,0%,100%,0.125);
}}
"""


def update_existing_css_colors(css_path, wal_colors):
    """Update only the wal-derived color values in an existing CSS, preserving the ibb URL."""
    ibb_url = extract_ibb_url_from_css(css_path)
    if not ibb_url:
        return
    name = os.path.splitext(os.path.basename(css_path))[0]
    new_css = generate_css(name, ibb_url, wal_colors)
    with open(css_path, "w") as f:
        f.write(new_css)


def mirror_to_stable(css_path):
    """Copy the active theme's CSS into the permanently-enabled stable file so
    Vencord re-injects it live. Overwriting an enabled theme's contents triggers
    Vencord's reactive re-injection - no manual theme switching, no restart."""
    stable_path = os.path.join(VENCORD_THEMES, STABLE_THEME)
    with open(css_path) as src:
        content = src.read()
    with open(stable_path, "w") as dst:
        dst.write(content)
    print(f"wal-discord: mirrored → {stable_path}")


def main():
    colors_sh = os.path.join(WAL_CACHE, "colors.sh")
    wallpaper_path = None
    with open(colors_sh) as f:
        for line in f:
            if line.startswith("wallpaper="):
                wallpaper_path = line.strip().split("=", 1)[1].strip('"\'')
                break

    if not wallpaper_path or not os.path.exists(wallpaper_path):
        print("wal-discord: could not find wallpaper path", file=sys.stderr)
        sys.exit(1)

    wal_colors = load_wal_colors()
    name = css_name_from_wallpaper(wallpaper_path)
    css_path = os.path.join(VENCORD_THEMES, f"{name}.css")

    existing = find_existing_css(name)

    if existing:
        # (reuse the existing css, just refresh colours, keep the imgbb url)
        print(f"wal-discord: updating colors in existing theme '{name}.css'")
        update_existing_css_colors(existing, wal_colors)
    else:
        # (new wallpaper needs an imgbb upload, skip cleanly with no key)
        if not IMGBB_API_KEY:
            print("wal-discord: no IMGBB_API_KEY set, skipping discord theme")
            return
        print(f"wal-discord: uploading '{os.path.basename(wallpaper_path)}' to imgbb...")
        try:
            ibb_url = upload_to_imgbb(wallpaper_path)
            print(f"wal-discord: uploaded → {ibb_url}")
        except Exception as e:
            print(f"wal-discord: upload failed: {e}", file=sys.stderr)
            sys.exit(1)

        css = generate_css(name, ibb_url, wal_colors)
        os.makedirs(VENCORD_THEMES, exist_ok=True)
        with open(css_path, "w") as f:
            f.write(css)
        print(f"wal-discord: created '{name}.css'")

    # (mirror to the stable enabled file so vencord live-reloads it)
    mirror_to_stable(css_path)

    print(f"wal-discord: done → {css_path}")


if __name__ == "__main__":
    main()
