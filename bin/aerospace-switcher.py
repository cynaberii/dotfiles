#!/usr/bin/env python3
"""keyboard workspace switcher for aerospace + pywal. opens instantly with
placeholders, loads thumbnails in a background thread."""

import json
import subprocess
import sys
import threading
import tkinter as tk
from pathlib import Path
from PIL import Image, ImageTk, ImageDraw

WAL_COLORS = Path.home() / ".cache/wal/colors.json"
CACHE_DIR  = Path.home() / ".cache/aerospace-switcher"
AEROSPACE  = "/opt/homebrew/bin/aerospace"

THUMB_W  = 380
THUMB_H  = 238
CELL_PAD = 10
NUM_W    = 40
PANEL_W  = NUM_W + THUMB_W + CELL_PAD * 3 + 20
CELL_H   = THUMB_H + CELL_PAD * 2 + 20

def load_colors():
    try:
        with open(WAL_COLORS) as f:
            c = json.load(f)
        col = c["colors"]
        return {
            "bg":          col["color0"],
            "bg_cell":     col["color8"],
            "border":      col["color1"],
            "border_sel":  col["color13"],
            "text_dim":    col["color7"],
            "text_bright": col["color15"],
            "text_title":  col["color14"],
            "accent":      col["color13"],
        }
    except Exception:
        return {
            "bg": "#111116",      "bg_cell": "#1e1e26",
            "border": "#333",     "border_sel": "#bb88ff",
            "text_dim": "#888",   "text_bright": "#eee",
            "text_title": "#ffcc88", "accent": "#bb88ff",
        }

def run_aero(args):
    try:
        r = subprocess.run([AEROSPACE] + args,
                           capture_output=True, text=True, timeout=10)
        return r.stdout.strip()
    except Exception:
        return ""

def fetch_workspace_data():
    # (two aerospace calls fired in parallel: focused workspace + all windows)
    results = {}

    def call(key, args):
        results[key] = run_aero(args)

    t1 = threading.Thread(target=call, args=("focused",
         ["list-workspaces", "--focused"]))
    t2 = threading.Thread(target=call, args=("windows",
         ["list-windows", "--all", "--format", "%{workspace}|%{app-name}"]))
    t1.start(); t2.start()
    t1.join();  t2.join()

    current = results.get("focused", "").strip()
    raw     = results.get("windows", "").strip()

    ws_apps = {}
    for line in raw.splitlines():
        parts = line.strip().split("|", 1)
        if len(parts) == 2:
            ws  = parts[0].strip()
            app = parts[1].strip()
            if ws and app:
                ws_apps.setdefault(ws, set()).add(app)

    return current, {ws: sorted(apps) for ws, apps in ws_apps.items()}

def load_thumb(ws_id):
    path = CACHE_DIR / f"ws-{ws_id}.png"
    if path.exists():
        try:
            img = Image.open(path)
            img.thumbnail((THUMB_W, THUMB_H), Image.BILINEAR)
            out = Image.new("RGB", (THUMB_W, THUMB_H), (16, 16, 20))
            x = (THUMB_W - img.width)  // 2
            y = (THUMB_H - img.height) // 2
            out.paste(img, (x, y))
            return out
        except Exception:
            pass
    return make_placeholder()

def make_placeholder():
    img  = Image.new("RGB", (THUMB_W, THUMB_H), (16, 16, 20))
    draw = ImageDraw.Draw(img)
    for x in range(16, THUMB_W, 24):
        for y in range(16, THUMB_H, 24):
            draw.ellipse([x-1, y-1, x+1, y+1], fill=(38, 38, 48))
    draw.text((THUMB_W // 2, THUMB_H // 2), "not yet seen",
              fill=(60, 60, 75), anchor="mm")
    return img

class Switcher:
    def __init__(self):
        self.C = load_colors()
        self.workspaces = []
        self.ws_apps    = {}
        self.current    = ""
        self.sel        = 0
        self.cells      = []
        self.tk_thumbs  = []
        self._ready     = False

        self.root = tk.Tk()
        self.root.configure(bg=self.C["bg"])
        self.root.overrideredirect(True)
        self.root.attributes("-topmost", True)
        self.root.geometry("1x1+-100+-100")

        self._build_chrome()
        self._bind()

        threading.Thread(target=self._load_data, daemon=True).start()

    def _load_data(self):
        try:
            current, ws_apps = fetch_workspace_data()
            workspaces = sorted(ws_apps.keys(),
                                key=lambda w: int(w) if w.isdigit() else w)
            thumbs = {ws: load_thumb(ws) for ws in workspaces}

            self.root.after(0, lambda: self._populate(current, ws_apps,
                                                       workspaces, thumbs))
        except Exception as e:
            import traceback
            traceback.print_exc()
            self.root.after(0, self.quit)

    def _populate(self, current, ws_apps, workspaces, thumbs):
        self.current    = current
        self.ws_apps    = ws_apps
        self.workspaces = workspaces

        if not workspaces:
            self.quit()
            return

        self.sel = 0
        if current in workspaces:
            self.sel = workspaces.index(current)

        self._build_cells(thumbs)
        self._resize_and_position()
        self._highlight(self.sel)
        self._ready = True
        self.root.deiconify()
        self.root.focus_force()
        self.root.grab_set()

    def _build_chrome(self):
        C = self.C
        self.outer = tk.Frame(self.root, bg=C["border_sel"], padx=1, pady=1)
        self.outer.pack(fill="both", expand=True)
        self.body = tk.Frame(self.outer, bg=C["bg"])
        self.body.pack(fill="both", expand=True)

        hdr = tk.Frame(self.body, bg=C["bg"])
        hdr.pack(fill="x", padx=14, pady=(9, 6))
        tk.Label(hdr, text="✦ workspaces ✦",
                 bg=C["bg"], fg=C["text_title"],
                 font=("JetBrains Mono", 11, "bold")).pack(side="left")
        self.count_lbl = tk.Label(hdr, text="",
                                   bg=C["bg"], fg=C["text_dim"],
                                   font=("JetBrains Mono", 9))
        self.count_lbl.pack(side="right")

        tk.Frame(self.body, bg=C["border"], height=1).pack(fill="x")

        self.canvas = tk.Canvas(self.body, bg=C["bg"],
                                highlightthickness=0, bd=0)
        self.canvas.pack(fill="both", expand=True)

        self.list_frame = tk.Frame(self.canvas, bg=C["bg"])
        self._cw = self.canvas.create_window((0, 0), window=self.list_frame,
                                              anchor="nw")
        self.list_frame.bind("<Configure>",
            lambda e: self.canvas.configure(
                scrollregion=self.canvas.bbox("all")))
        self.canvas.bind("<Configure>",
            lambda e: self.canvas.itemconfig(self._cw, width=e.width))

        tk.Frame(self.body, bg=C["border"], height=1).pack(fill="x")
        tk.Label(self.body,
                 text="↑↓  navigate    enter  switch    1-9  jump    q  quit",
                 bg=C["bg"], fg=C["text_dim"],
                 font=("JetBrains Mono", 8), pady=6).pack()

    def _build_cells(self, thumbs):
        C = self.C
        self.cells     = []
        self.tk_thumbs = []

        self.count_lbl.configure(text=f"{len(self.workspaces)} active")

        for i, ws in enumerate(self.workspaces):
            tk_img = ImageTk.PhotoImage(thumbs[ws])
            self.tk_thumbs.append(tk_img)

            apps   = self.ws_apps.get(ws, [])
            is_cur = (ws == self.current)

            cell = tk.Frame(self.list_frame, bg=C["bg_cell"],
                            pady=CELL_PAD, padx=CELL_PAD, cursor="hand2")
            cell.pack(fill="x", padx=8, pady=(5, 0))

            badge = tk.Frame(cell, bg=C["bg_cell"], width=NUM_W)
            badge.pack(side="left", fill="y", padx=(0, CELL_PAD))
            badge.pack_propagate(False)

            num_lbl = tk.Label(badge,
                               text="◆" if is_cur else ws,
                               bg=C["bg_cell"],
                               fg=C["accent"] if is_cur else C["text_dim"],
                               font=("JetBrains Mono", 13, "bold"),
                               anchor="center")
            num_lbl.pack(expand=True)
            if is_cur:
                tk.Label(badge, text="now", bg=C["bg_cell"],
                         fg=C["accent"],
                         font=("JetBrains Mono", 7)).pack()

            right = tk.Frame(cell, bg=C["bg_cell"])
            right.pack(side="left", fill="both", expand=True)

            thumb_lbl = tk.Label(right, image=tk_img,
                                 bg=C["bg_cell"], bd=0)
            thumb_lbl.pack(anchor="w")

            apps_str = "  ·  ".join(apps[:6])
            if len(apps) > 6:
                apps_str += f"  +{len(apps)-6}"
            apps_lbl = tk.Label(right, text=apps_str or "-",
                                bg=C["bg_cell"], fg=C["text_dim"],
                                font=("JetBrains Mono", 8),
                                anchor="w", wraplength=THUMB_W, justify="left")
            apps_lbl.pack(anchor="w", pady=(4, 0))

            for w in [cell, badge, num_lbl, right, thumb_lbl, apps_lbl]:
                w.bind("<Button-1>",        lambda e, n=i: self._click(n))
                w.bind("<Double-Button-1>", lambda e, n=i: self._dclick(n))

            self.cells.append({
                "frame": cell, "badge": badge, "num": num_lbl,
                "right": right, "thumb": thumb_lbl, "apps": apps_lbl,
            })

        tk.Frame(self.list_frame, bg=C["bg"], height=8).pack()

    def _resize_and_position(self):
        sh      = self.root.winfo_screenheight()
        visible = min(len(self.workspaces), 4)
        cells_h = visible * (CELL_H + 5) + 8
        panel_h = min(42 + 30 + 2 + cells_h, sh - 80)
        x, y    = 16, max(55, (sh - panel_h) // 2)
        self.canvas.configure(height=cells_h)
        self.root.geometry(f"{PANEL_W}x{panel_h}+{x}+{y}")

    def _highlight(self, idx):
        C = self.C
        for i, ci in enumerate(self.cells):
            sel = (i == idx)
            bg  = C["bg_cell"]
            ci["frame"].configure(
                bg=bg,
                highlightbackground=C["border_sel"] if sel else C["bg_cell"],
                highlightthickness=2 if sel else 0,
            )
            for w in [ci["badge"], ci["num"], ci["right"],
                      ci["thumb"], ci["apps"]]:
                try:
                    w.configure(bg=bg)
                except Exception:
                    pass
            ci["apps"].configure(
                fg=C["text_bright"] if sel else C["text_dim"])
            ci["num"].configure(
                fg=C["accent"] if (sel or self.workspaces[i] == self.current)
                   else C["text_dim"])

        self.root.update_idletasks()
        total = len(self.cells)
        if total:
            self.canvas.yview_moveto(max(0, (idx / total) - 0.05))

    def _bind(self):
        r = self.root
        r.bind("<Escape>", lambda e: self.quit())
        r.bind("<q>",      lambda e: self.quit())
        r.bind("<Up>",     lambda e: self._nav(-1))
        r.bind("<Down>",   lambda e: self._nav(1))
        r.bind("<k>",      lambda e: self._nav(-1))
        r.bind("<j>",      lambda e: self._nav(1))
        r.bind("<Return>", lambda e: self._confirm())
        r.bind("<space>",  lambda e: self._confirm())
        for n in range(1, 10):
            r.bind(str(n), lambda e, n=n: self._jump(n))

    def _nav(self, d):
        if not self._ready: return
        self.sel = (self.sel + d) % len(self.workspaces)
        self._highlight(self.sel)

    def _jump(self, n):
        if not self._ready: return
        ws = str(n)
        if ws in self.workspaces:
            self.sel = self.workspaces.index(ws)
            self._highlight(self.sel)

    def _click(self, idx):
        if not self._ready: return
        self.sel = idx
        self._highlight(self.sel)
        self.root.focus_force()

    def _dclick(self, idx):
        if not self._ready: return
        self.sel = idx
        self._confirm()

    def _confirm(self):
        if not self._ready: return
        ws = self.workspaces[self.sel]
        self.root.grab_release()
        self.root.withdraw()
        subprocess.run([AEROSPACE, "workspace", ws],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.root.destroy()

    def quit(self):
        self.root.destroy()

    def run(self):
        self.root.mainloop()


if __name__ == "__main__":
    try:
        from PIL import Image, ImageTk, ImageDraw
    except ImportError:
        print("Missing Pillow:  ~/miniconda3/bin/pip install Pillow")
        sys.exit(1)
    Switcher().run()
