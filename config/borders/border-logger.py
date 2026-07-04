#!/usr/bin/env python3
"""borders active-colour diagnostic. each tick compares three notions of "which
window is focused": rift's is_focused, macOS is_frontmost, and which window
actually shows the salmon active border in a screenshot. exactly one window should
carry active and match the focused one; divergence pinpoints the bug.

usage: border-logger.py [interval] [duration] [cycle]
  interval  seconds between ticks (default 0.6)
  duration  seconds to run, omit/0 = until ctrl-c
  cycle     literal 'cycle', drives `execute window next` each tick to walk focus
logs to /tmp/border-diag.log.
"""
import json, subprocess, sys, time
from datetime import datetime
from PIL import Image

SCALE = 2
SHOT = "/tmp/border-diag-shot.png"
LOG = "/tmp/border-diag.log"

INTERVAL = float(sys.argv[1]) if len(sys.argv) > 1 else 0.6
DURATION = float(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2] not in ("cycle",) else None
CYCLE = "cycle" in sys.argv[1:]


def classify_pixel(r, g, b):
    mx, mn = max(r, g, b), min(r, g, b)
    if r - max(g, b) > 28 and r > 115:        # reddish -> active
        return "A"
    if (mx - mn) < 26 and 78 < (r + g + b) / 3 < 145:  # gray -> inactive
        return "I"
    return None


def scan_window(px, frame):
    x0 = int(frame["origin"]["x"] * SCALE)
    y0 = int(frame["origin"]["y"] * SCALE)
    w = int(frame["size"]["width"] * SCALE)
    h = int(frame["size"]["height"] * SCALE)
    x1, y1 = x0 + w, y0 + h
    imgW, imgH = px.width, px.height
    a = i = 0

    def sample(cx, cy, horizontal):
        nonlocal a, i
        hitA = False
        for d in range(-22, 23, 2):
            x, y = (cx, cy + d) if horizontal else (cx + d, cy)
            if 0 <= x < imgW and 0 <= y < imgH:
                c = classify_pixel(*px.getpixel((x, y))[:3])
                if c == "A":
                    a += 1; hitA = True
                elif c == "I" and not hitA:
                    i += 1

    N = 24
    for k in range(N):
        ex = x0 + int(w * (k + 0.5) / N)
        sample(ex, y0, True); sample(ex, y1, True)
        ey = y0 + int(h * (k + 0.5) / N)
        sample(x0, ey, False); sample(x1, ey, False)
    return a, i


def q(cmd):
    try:
        return json.loads(subprocess.check_output(["rift-cli", "query", cmd], text=True))
    except Exception:
        return []


def frontmost_app():
    for a in q("applications"):
        if a.get("is_frontmost"):
            return a.get("name")
    return None


def tick(logf):
    if CYCLE:
        subprocess.run(["rift-cli", "execute", "window", "next"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(0.35)  # let rift + borders settle before the shot
    wins = q("windows")
    if not wins:
        return
    front = frontmost_app()
    subprocess.run(["screencapture", "-x", "-t", "png", SHOT],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        img = Image.open(SHOT).convert("RGB")
    except Exception:
        return

    rift_focus = None
    results = []
    for w in wins:
        a, ic = scan_window(img, w["frame"])
        # (active only when salmon clearly dominates grey)
        if a >= 8 and a > ic * 1.3:
            state = "ACTIVE"
        elif ic >= 4:
            state = "INACTIVE"
        else:
            state = "NONE"
        label = f'{w["app_name"]}:{(w.get("title") or "")[:16]}'
        results.append((label, state, a, ic))
        if w.get("is_focused"):
            rift_focus = label

    active = [r[0] for r in results if r[1] == "ACTIVE"]
    ts = datetime.now().strftime("%H:%M:%S.%f")[:-3]

    anomaly = ""
    if len(active) == 0:
        anomaly = "!! 0 active"
    elif len(active) > 1:
        anomaly = f"!! {len(active)} active"
    elif rift_focus and active[0] != rift_focus:
        anomaly = f"!! border!=rift(rift={rift_focus})"

    detail = " ".join(f"[{l}={s}·a{a}/i{ic}]" for l, s, a, ic in results)
    line = f"{ts} rift={rift_focus} front={front} BORDER={active} {anomaly}  {detail}"
    logf.write(line + "\n"); logf.flush()
    print(line)


def main():
    start = time.time()
    with open(LOG, "w") as logf:
        logf.write(f"# border diag {datetime.now()} interval={INTERVAL}s cycle={CYCLE}\n")
        logf.flush()
        print(f"logging -> {LOG}. Ctrl-C to stop." + (" [CYCLE mode]" if CYCLE else ""))
        try:
            while True:
                tick(logf)
                if DURATION and time.time() - start > DURATION:
                    break
                time.sleep(INTERVAL)
        except KeyboardInterrupt:
            pass
    print("done ->", LOG)


if __name__ == "__main__":
    main()
