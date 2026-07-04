#!/usr/bin/env python3
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Wallpaper Picker
# @raycast.mode silent
import sys, os, subprocess, threading, hashlib
from pathlib import Path
import tkinter as tk
import tkinter.ttk as ttk
from PIL import Image, ImageTk, ImageDraw

WALLPAPER_DIR = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.home() / "Downloads/wallpapers"
SUPPORTED_EXT = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp", ".tiff"}
CACHE_DIR     = Path.home() / ".cache" / "wallpaper-picker"

COLS    = 6
THUMB_W = 210
THUMB_H = 130
PAD     = 10
LABEL_H = 26
CELL_W  = THUMB_W + PAD
CELL_H  = THUMB_H + LABEL_H + PAD
RADIUS  = 6

def _load_wal_colors():
    import json
    wal_json = Path.home() / ".cache/wal/colors.json"
    try:
        with open(wal_json) as f:
            data = json.load(f)
        c = data["colors"]
        return {
            "bg":         c["color0"],
            "bg_cell":    c["color8"],
            "bg_sel":     c["color8"],
            "border":     c["color1"],
            "border_sel": c["color13"],
            "text_dim":   c["color1"],
            "text_sel":   c["color15"],
            "text_title": c["color14"],
            "scroll_bg":  c["color0"],
            "scroll_fg":  c["color8"],
            "scroll_act": c["color1"],
        }
    except Exception:
        # (fallback if the wal cache is missing)
        return {
            "bg":         "#1c161e",
            "bg_cell":    "#221a26",
            "bg_sel":     "#3a2640",
            "border":     "#3d2e45",
            "border_sel": "#c896b4",
            "text_dim":   "#6e5f78",
            "text_sel":   "#e0b8d0",
            "text_title": "#e6b4cc",
            "scroll_bg":  "#2a1f30",
            "scroll_fg":  "#4a3555",
            "scroll_act": "#6e5078",
        }

_WAL = _load_wal_colors()
BG         = _WAL["bg"]
BG_CELL    = _WAL["bg_cell"]
BG_SEL     = _WAL["bg_sel"]
BORDER     = _WAL["border"]
BORDER_SEL = _WAL["border_sel"]
TEXT_DIM   = _WAL["text_dim"]
TEXT_SEL   = _WAL["text_sel"]
TEXT_TITLE = _WAL["text_title"]
SCROLL_BG  = _WAL["scroll_bg"]
SCROLL_FG  = _WAL["scroll_fg"]
SCROLL_ACT = _WAL["scroll_act"]

def set_wallpaper(path):
    script = f'tell application "System Events" to tell every desktop to set picture to POSIX file "{path}"'
    subprocess.run(["osascript", "-e", script], capture_output=True)
    subprocess.run([
        str(Path.home() / 'miniconda3' / 'bin' / 'wal'),
        '-i', str(path),
        '--backend', 'balanced',
        '-n',
    ])
    subprocess.Popen(['bash', str(Path.home() / '.config' / 'wal' / 'postrun')])

def cache_key(path: Path) -> str:
    stat = path.stat()
    sig  = f"{path}:{stat.st_size}:{stat.st_mtime}"
    return hashlib.md5(sig.encode()).hexdigest()

def make_thumb_pil(path: Path) -> Image.Image:
    """pure PIL work, safe from any thread."""
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    key       = cache_key(path)
    cache_png = CACHE_DIR / f"{key}.png"

    if cache_png.exists():
        try:
            img = Image.open(cache_png)
            img.load()
            return img.convert("RGBA")
        except Exception:
            pass

    try:
        img = Image.open(path)
        img.load()
        img = img.convert("RGBA")
        r  = img.width / img.height
        br = THUMB_W / THUMB_H
        if r > br:
            nw  = int(img.height * br)
            img = img.crop(((img.width - nw) // 2, 0,
                            (img.width - nw) // 2 + nw, img.height))
        else:
            nh  = int(img.width / br)
            img = img.crop((0, (img.height - nh) // 2,
                            img.width, (img.height - nh) // 2 + nh))
        img  = img.resize((THUMB_W, THUMB_H), Image.BILINEAR)
        mask = Image.new("L", (THUMB_W, THUMB_H), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            (0, 0, THUMB_W - 1, THUMB_H - 1), radius=RADIUS, fill=255)
        img.putalpha(mask)
        img.save(cache_png, "PNG")
        return img
    except Exception:
        return Image.new("RGBA", (THUMB_W, THUMB_H), "#2a1f30")


class Picker:
    def __init__(self, root, walls):
        self.root   = root
        self.walls  = walls
        self.sel    = 0
        self.photos = {}
        self._pil   = {}
        self._drag_x = self._drag_y = 0

        root.configure(bg=BG)  # (bg before first render, avoids the grey flash)
        root.title("wallpaper-picker")
        root.resizable(False, False)
        root.overrideredirect(True)
        root.attributes("-topmost", True)
        root.attributes("-alpha", 0.96)

        sw    = root.winfo_screenwidth()
        sh    = root.winfo_screenheight()
        win_w = COLS * CELL_W + PAD * 2 + 14   # +14 for scrollbar width
        rows  = (len(walls) + COLS - 1) // COLS
        win_h = min(sh - 80, rows * CELL_H + PAD * 2 + 100)
        # (position in the first geometry call so it never flashes at 0,0)
        x     = (sw - win_w) // 2
        y     = (sh - win_h) // 2
        root.geometry(f"{win_w}x{win_h}+{x}+{y}")
        root.update_idletasks()
        aw = root.winfo_width()
        ah = root.winfo_height()
        root.geometry(f"{aw}x{ah}+{(sw - aw) // 2}+{(sh - ah) // 2}")

        self._build()
        self._bind_keys()
        root.focus_force()
        root.grab_set()
        root.bind("<Enter>", lambda e: root.focus_force())
        threading.Thread(target=self._load_all, daemon=True).start()

    def _bind_keys(self):
        def _esc(e):  self.root.destroy(); return "break"
        def _q(e):    self.root.destroy(); return "break"
        def _ret(e):  self._pick();        return "break"
        def _up(e):   self._move(-COLS);   return "break"
        def _dn(e):   self._move( COLS);   return "break"
        def _lt(e):   self._move(-1);      return "break"
        def _rt(e):   self._move( 1);      return "break"
        def _k(e):    self._move(-COLS);   return "break"
        def _j(e):    self._move( COLS);   return "break"
        def _h(e):    self._move(-1);      return "break"
        def _l(e):    self._move( 1);      return "break"

        bindings = [
            ("<Escape>",  _esc), ("q",      _q),
            ("<Return>",  _ret),
            ("<Up>",      _up),  ("<Down>",  _dn),
            ("<Left>",    _lt),  ("<Right>", _rt),
            ("k",         _k),   ("j",       _j),
            ("h",         _h),   ("l",       _l),
        ]

        # (bind_all catches keys regardless of focus; "break" everywhere kills the Tk bell)
        for seq, fn in bindings:
            self.root.bind_all(seq, fn)

        self.root.bind_all("<Key>", lambda e: "break")

    def _build(self):
        bar = tk.Frame(self.root, bg=BG, height=58)
        bar.pack(fill="x")
        bar.pack_propagate(False)
        bar.bind("<Button-1>",  self._ds)
        bar.bind("<B1-Motion>", self._dm)

        title = tk.Label(
            bar,
            text="˚ ₊‧꒰ა  ✦ ˚  · ˚  wallpapers  ˚ ·  ˚ ✦  ໒꒱ ‧₊˚",
            bg=BG, fg=TEXT_TITLE,
            font=("JetBrains Mono", 16, "bold"),
        )
        title.place(relx=0.5, rely=0.5, anchor="center")
        title.bind("<Button-1>",  self._ds)
        title.bind("<B1-Motion>", self._dm)

        close = tk.Label(bar, text="✕", bg=BG, fg=TEXT_DIM,
                         font=("JetBrains Mono", 12), cursor="hand2", padx=16)
        close.pack(side="right", pady=4)
        close.bind("<Button-1>", lambda e: self.root.destroy())

        tk.Frame(self.root, bg=BORDER, height=1).pack(fill="x")

        frame = tk.Frame(self.root, bg=BG)
        frame.pack(fill="both", expand=True)

        style = ttk.Style()
        style.theme_use("default")
        style.configure(
            "WP.Vertical.TScrollbar",
            gripcount=0,
            background=SCROLL_FG,
            darkcolor=SCROLL_BG,
            lightcolor=SCROLL_BG,
            troughcolor=SCROLL_BG,
            bordercolor=SCROLL_BG,
            arrowcolor=SCROLL_FG,
            relief="flat",
        )
        style.map(
            "WP.Vertical.TScrollbar",
            background=[("active", SCROLL_ACT), ("!active", SCROLL_FG)],
        )

        self.canvas = tk.Canvas(frame, bg=BG, highlightthickness=0)
        scrollbar   = ttk.Scrollbar(
            frame, orient="vertical",
            command=self.canvas.yview,
            style="WP.Vertical.TScrollbar",
        )
        self.canvas.configure(yscrollcommand=scrollbar.set)

        scrollbar.pack(side="right", fill="y")
        self.canvas.pack(side="left", fill="both", expand=True)

        rows = (len(self.walls) + COLS - 1) // COLS
        self.canvas.configure(
            scrollregion=(0, 0,
                          COLS * CELL_W + PAD * 2,
                          rows * CELL_H + PAD))

        self.canvas.bind("<Button-1>",   self._click)
        self.canvas.bind("<MouseWheel>",
            lambda e: self.canvas.yview_scroll(-1 * (e.delta // 120), "units"))
        self.canvas.bind("<Button-4>",
            lambda e: self.canvas.yview_scroll(-1, "units"))
        self.canvas.bind("<Button-5>",
            lambda e: self.canvas.yview_scroll( 1, "units"))

        tk.Frame(self.root, bg=BORDER, height=1).pack(fill="x")

        self.footer = tk.StringVar()
        self._upfooter()
        tk.Label(self.root, textvariable=self.footer,
                 bg=BG, fg=TEXT_DIM,
                 font=("JetBrains Mono", 10)).pack(pady=7)

        self._draw()

    def _draw(self):
        self.canvas.delete("all")
        self.cells = {}
        for i, w in enumerate(self.walls):
            row = i // COLS
            col = i % COLS
            x   = PAD + col * CELL_W
            y   = PAD + row * CELL_H
            sel = (i == self.sel)
            self.cells[i] = (x, y)
            self.canvas.create_rectangle(
                x, y, x + THUMB_W, y + THUMB_H + LABEL_H,
                fill=BG_SEL if sel else BG_CELL,
                outline=BORDER_SEL if sel else BORDER,
                width=2 if sel else 1,
                tags=f"bg{i}",
            )
            if i in self.photos:
                self.canvas.create_image(x, y, anchor="nw",
                                         image=self.photos[i], tags=f"img{i}")
            label = w.stem[:26] + ("…" if len(w.stem) > 26 else "")
            self.canvas.create_text(
                x + THUMB_W // 2, y + THUMB_H + LABEL_H // 2,
                text=label,
                fill=TEXT_SEL if sel else TEXT_DIM,
                font=("JetBrains Mono", 9, "bold" if sel else "normal"),
                tags=f"lbl{i}",
            )

    def _load_all(self):
        """worker thread: PIL/disk only, no Tk calls."""
        for i, w in enumerate(self.walls):
            pil_img = make_thumb_pil(w)
            self.root.after(0, self._make_photo, i, pil_img)

    def _make_photo(self, i, pil_img):
        """main thread: PIL to PhotoImage, patch canvas."""
        photo = ImageTk.PhotoImage(pil_img)
        self.photos[i] = photo
        self._patch(i)

    def _patch(self, i):
        if i not in self.cells: return
        x, y = self.cells[i]
        self.canvas.delete(f"img{i}")
        self.canvas.create_image(x, y, anchor="nw",
                                 image=self.photos[i], tags=f"img{i}")
        self.canvas.tag_raise(f"lbl{i}")

    def _click(self, e):
        yc = self.canvas.canvasy(e.y)
        for i, (x, y) in self.cells.items():
            if x <= e.x <= x + THUMB_W and y <= yc <= y + THUMB_H + LABEL_H:
                if i == self.sel:
                    self._pick()
                else:
                    self.sel = i
                    self._draw()
                    self._upfooter()
                break

    def _move(self, d):
        n = max(0, min(len(self.walls) - 1, self.sel + d))
        if n != self.sel:
            self.sel = n
            self._draw()
            self._upfooter()
            row        = self.sel // COLS
            total_rows = (len(self.walls) + COLS - 1) // COLS
            self.canvas.yview_moveto(row / max(1, total_rows))

    def _pick(self):
        self.root.destroy()
        set_wallpaper(self.walls[self.sel])

    def _upfooter(self):
        name = self.walls[self.sel].stem
        if len(name) > 30:
            name = name[:29] + "…"
        self.footer.set(
            f"✦  {name}   ·   ↑↓←→ navigate   ·   ↵ set wallpaper   ·   q quit  ✦"
        )

    def _ds(self, e):
        self._drag_x = e.x_root - self.root.winfo_x()
        self._drag_y = e.y_root - self.root.winfo_y()

    def _dm(self, e):
        self.root.geometry(
            f"+{e.x_root - self._drag_x}+{e.y_root - self._drag_y}"
        )


def main():
    walls = sorted(
        [p for p in WALLPAPER_DIR.iterdir()
         if p.suffix.lower() in SUPPORTED_EXT],
        key=lambda p: p.name.lower(),
    )
    if not walls:
        print(f"no wallpapers in {WALLPAPER_DIR}")
        sys.exit(1)
    root = tk.Tk()
    root.tk.call('rename', 'bell', '_bell_orig')
    root.tk.call('proc', 'bell', '{args}', '{}')   # silence the Tk bell
    Picker(root, walls)
    root.mainloop()


if __name__ == "__main__":
    main()
