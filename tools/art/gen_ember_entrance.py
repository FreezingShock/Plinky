"""Ember Quarry cave entrance art for Larkmoor: cave mouth, mine timbers, neon sign and decor, drawn texel by texel.
Usage: python3 tools/art/gen_ember_entrance.py mock <outdir>   (three styles, day and night, composited on the real cliff)"""
import sys, os, json, math
from PIL import Image, ImageEnhance
sys.path.insert(0, os.path.dirname(__file__))
from ember_kit import *

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
LK = os.path.join(ROOT, "assets/art/zone1b/larkmoor/")

# ---------------------------------------------------------------- font (6 tall strokes are 2 texels wide)
G = {
 "E": ["111111", "111111", "110000", "111100", "111100", "110000", "110000", "111111", "111111"],
 "M": ["11000011", "11100111", "11111111", "11011011", "11011011", "11000011", "11000011", "11000011", "11000011"],
 "B": ["111110", "111111", "110011", "111110", "111110", "110011", "110011", "111111", "111110"],
 "R": ["111110", "111111", "110011", "110011", "111110", "111100", "110110", "110011", "110011"],
 "Q": ["0111110", "1111111", "1100011", "1100011", "1100011", "1101011", "1100111", "1111110", "0111011"],
 "U": ["110011", "110011", "110011", "110011", "110011", "110011", "110011", "111111", "011110"],
 "A": ["011110", "111111", "110011", "110011", "111111", "111111", "110011", "110011", "110011"],
 "Y": ["110011", "110011", "111111", "011110", "001100", "001100", "001100", "001100", "001100"],
}
ARROW = ["...111...", "...111...", "...111...", "...111...", "...111...", "...111...",
         "111111111", ".1111111.", "..11111..", "...111...", "....1...."]


def text_mask(s, gap=1, space=6):
    cells = []; x = 0
    for ch in s:
        if ch == " ": x += space; continue
        g = G[ch]; w = len(g[0])
        for y, row in enumerate(g):
            for i, v in enumerate(row):
                if v == "1": cells.append((x + i, y))
        x += w + gap
    return cells, x - gap


def neon_layer(cv, cells, ox, oy, glow=1.0, off=False):
    """Draw neon tubes at (ox, oy) into cv: hot top-left edge, amber body, dithered ember halo around them."""
    S = set((ox + x, oy + y) for x, y in cells)
    if off:
        for (x, y) in S: cv.px(x, y, QSHADOW if (x + y) & 1 else QEARTH)
        return
    R = 5
    for (x, y) in list(S):
        for dy in range(-R, R + 1):
            for dx in range(-R, R + 1):
                px_, py_ = x + dx, y + dy
                if (px_, py_) in S: continue
                d = math.hypot(dx, dy)
                if d > R: continue
                t = (1 - d / (R + .5)) * glow
                if bayer(px_, py_) < t * t * 1.15:
                    cur = cv.get(px_, py_)
                    lvl = QBASE if d <= 1.5 else QDEEP if d <= 3 else QSHADOW
                    if cur[3] == 0 or cur[:3] in (QINK[:3], QSHADOW[:3], QEARTH[:3], QDEEP[:3]):
                        cv.px(px_, py_, lvl)
    for (x, y) in S:
        hot = ((x - 1, y) not in S) or ((x, y - 1) not in S)
        cv.px(x, y, QPAPER if hot else QLIGHT)


def sign(style):
    cells, tw = text_mask("EMBER QUARRY")
    aw = len(ARROW[0]); ah = len(ARROW)
    gapa = 9
    inner = tw + 2 * (aw + gapa)
    W = inner + 20; H = 28
    cv = Canvas(W, H + (14 if style == "B" else 8))
    # iron plate
    cv.rect(2, 2, W - 3, H - 3, QINK)
    for x in range(2, W - 2):
        cv.px(x, 2, QEARTH); cv.px(x, H - 3, QSHADOW)
    for y in range(2, H - 2):
        cv.px(2, y, QEARTH); cv.px(W - 3, y, QSHADOW)
    for x in range(3, W - 3):
        cv.px(x, 3, QACCENT if x % 2 else QEARTH)
    for (rx, ry) in ((5, 6), (W - 6, 6), (5, H - 7), (W - 6, H - 7)):
        cv.rect(rx, ry, rx + 1, ry + 1, QACCENT); cv.px(rx + 1, ry + 1, QSHADOW)
    ox = 10 + aw + gapa; oy = (H - 9) // 2
    arr = [(x, y) for y, r in enumerate(ARROW) for x, v in enumerate(r) if v == "1"]
    neon_layer(cv, cells, ox, oy)
    neon_layer(cv, arr, 10, (H - ah) // 2)
    neon_layer(cv, arr, W - 10 - aw, (H - ah) // 2)
    if style == "A":      # bracket legs into the cliff
        for x in (10, W - 12):
            cv.rect(x, H - 2, x + 1, H + 5, QEARTH); cv.px(x, H - 2, QACCENT)
    if style == "B":      # hung on two chains
        for x in (14, W - 15):
            for y in range(H - 2, H + 12, 2): cv.px(x, y, QACCENT); cv.px(x, y + 1, QEARTH)
    return cv


# ---------------------------------------------------------------- cave mouth
def cave(style):
    W, H = 128, 92
    cx, cr, cy0 = 64, 26, 56
    if style == "C": cr = 22
    cv = Canvas(W, H)
    base = 88

    def mound_d(x, y):          # distance in texels to the mound edge (<0 outside)
        if y < 46:
            k = math.hypot((x + .5 - 64) / 62.0, (y + .5 - 46) / 44.0)
            return (1 - k) * 44
        return min(x - 2, 125 - x)

    def in_open(x, y):
        if y >= cy0: return abs(x + .5 - cx) <= cr and y <= base
        return math.hypot(x + .5 - cx, y + .5 - cy0) <= cr

    def ring(x, y):             # 0 = outside ring, else 1 + course
        th = 10
        if y >= cy0: return (abs(x + .5 - cx) <= cr + th) and y <= base + 2 and not in_open(x, y)
        return math.hypot(x + .5 - cx, y + .5 - cy0) <= cr + th and not in_open(x, y)

    rock_lo, rock_mid, rock_hi = ((EARTH, ACCENT, SHADOW) if style != "C" else (QEARTH, QACCENT, QINK))
    for y in range(H):
        for x in range(W):
            d = mound_d(x, y)
            if d < 0 or in_open(x, y): continue
            if d < 5 and bayer(x, y) > d / 5.0 and y < base - 3: continue
            n = vnoise(x / 3.2, y / 2.1, 3) * .6 + vnoise(x / 1.6, y / 1.4, 8) * .4
            c = rock_lo
            if n > .66 - 0.18 * (1 - (x + y) / 200.0): c = rock_mid
            elif n < .30: c = rock_hi if style != "C" else QSHADOW
            if style == "C" and n > .55 and vnoise(x / 2.0, y / 5.0, 11) > .72: c = QBASE   # ember seams in the basalt
            cv.px(x, y, c)
    # masonry ring (A, C) or rough boulder lip (B)
    for y in range(H):
        for x in range(W):
            if not ring(x, y): continue
            if style == "B":
                n = vnoise(x / 4.0, y / 3.0, 21)
                c = QEARTH if n < .45 else EARTH
                if n > .75: c = ACCENT
                if (x - 64) * (y - 40) > 600 and n < .6: c = QDEEP
                cv.px(x, y, c); continue
            if y < cy0:
                r = math.hypot(x + .5 - cx, y + .5 - cy0); th_ = math.atan2(y + .5 - cy0, x + .5 - cx)
                course = int((r - cr) // 5); segs = 14 + 3 * course
                u = (th_ + math.pi) / math.pi * segs / 2 + course * .5
                fu = u - math.floor(u); fr = ((r - cr) % 5) / 5.0
                edge_u = fu * (math.pi * r / segs)         # texels from block edge along the ring
                mort = edge_u < .9 or fr < .2
                top_edge = fr > .75; left_edge = edge_u < 1.9
            else:
                course = int((base - y) // 7); xo = (x - cx) + (cr + 10)
                bw = 12 if course % 2 == 0 else 15
                fu = ((x - 0) + (course % 2) * 6) % bw
                mort = fu == 0 or (base - y) % 7 == 0
                top_edge = (base - y) % 7 == 6; left_edge = fu == 1
            blk = hsh(int(x // 3), int(y // 3), 4)
            if style == "C":
                col = QEARTH if blk > .35 else QSHADOW
                if mort: col = QINK
                elif left_edge or top_edge: col = QACCENT
                cv.px(x, y, col)
            else:
                col = EARTH
                if blk > .78: col = ACCENT
                elif blk < .22: col = QDEEP
                if mort: col = SHADOW
                elif top_edge or left_edge: col = ACCENT if col != ACCENT else PAPER
                cv.px(x, y, col)
    # keystone
    if style in ("A", "C"):
        ky = cy0 - cr - 10
        k = ACCENT if style == "A" else QACCENT
        cv.rect(cx - 6, ky, cx + 5, ky + 10, k)
        cv.rect(cx - 6, ky, cx + 5, ky, PAPER if style == "A" else QPAPER); cv.rect(cx - 6, ky, cx - 6, ky + 10, PAPER if style == "A" else QPAPER)
        cv.rect(cx - 5, ky + 10, cx + 5, ky + 10, SHADOW if style == "A" else QINK)
        cv.rect(cx + 5, ky + 1, cx + 5, ky + 10, SHADOW if style == "A" else QINK)
        # ember rune: a lit chevron
        for i in range(3):
            cv.px(cx - 2 + i, ky + 4 + i, QBASE); cv.px(cx + 3 - i, ky + 4 + i, QBASE)
        cv.px(cx, ky + 7, QLIGHT)
    # ---- interior
    gx, gy = cx, 49
    for y in range(H):
        for x in range(W):
            if not in_open(x, y): continue
            dd = math.hypot((x - gx) / 15.0, (y - gy) / 11.0)
            t = max(0.0, 1 - dd) * (1.25 if style == "C" else 1.0)
            lv = t * 4.2 + (bayer(x, y) - .5) * .9
            c = QINK
            if lv > 3.4: c = QLIGHT
            elif lv > 2.4: c = QBASE
            elif lv > 1.5: c = QDEEP
            elif lv > .7: c = QSHADOW
            cv.px(x, y, c)
    # floor trapezoid
    fl_top, fl_bot = 50, base
    def hw(y): return 3 + (y - fl_top) / float(fl_bot - fl_top) * (cr - 1)
    for y in range(fl_top, fl_bot + 1):
        for x in range(W):
            if not in_open(x, y): continue
            if abs(x + .5 - cx) > hw(y): continue
            near = (y - fl_top) / float(fl_bot - fl_top)
            warm = max(0.0, near * 1.1 - abs(x - cx) / 40.0)
            lv = warm * 2.6 + (bayer(x, y) - .5) * .9 + (1 - near) * .5 * max(0, 1 - math.hypot((x - gx) / 12.0, (y - gy) / 9.0))
            c = QSHADOW
            if lv > 1.9: c = QDEEP
            elif lv > .9: c = QEARTH if near > .55 else QSHADOW
            if lv > 2.5: c = QBASE
            cv.px(x, y, c)
    # rails + sleepers
    sl = [87, 83, 78, 73, 69, 65, 62, 59, 56, 53]
    for y in sl:
        h = hw(y) * .82
        cv.rect(cx - h, y, cx + h, y, QDEEP if y > 66 else QSHADOW)
        cv.rect(cx - h, y - 1, cx + h, y - 1, EARTH if y > 70 else QEARTH)
    for y in range(fl_top + 1, fl_bot + 1):
        h = hw(y) * .38 + 1.5
        for s in (-1, 1):
            xx = round(cx + s * h)
            cv.px(xx, y, QPAPER if y > 60 else QACCENT); cv.px(xx + s, y, QEARTH if y > 60 else QSHADOW)
    # mine cart on the rails
    cy_ = 70
    cv.poly([(cx - 8, cy_ - 7), (cx + 8, cy_ - 7), (cx + 6, cy_ + 2), (cx - 6, cy_ + 2)], QEARTH)
    cv.poly([(cx - 8, cy_ - 7), (cx + 8, cy_ - 7), (cx + 7, cy_ - 4), (cx - 7, cy_ - 4)], QPAPER)
    cv.rect(cx - 6, cy_ - 3, cx - 6, cy_ + 1, QACCENT); cv.rect(cx + 5, cy_ - 3, cx + 6, cy_ + 1, QSHADOW)
    for i in range(-5, 6, 2): cv.px(cx + i, cy_ - 1, QDEEP)
    cv.px(cx - 6, cy_ + 3, QINK); cv.px(cx - 5, cy_ + 3, QINK); cv.px(cx + 5, cy_ + 3, QINK); cv.px(cx + 6, cy_ + 3, QINK)
    for i, (ox_, oy_, r_) in enumerate(((-5, -9, 3), (0, -11, 4), (5, -9, 3), (-2, -8, 3))):   # ore heap, ember in the cracks
        cv.ell(cx + ox_, cy_ + oy_, r_ + .5, r_ * .8, QINK)
        cv.ell(cx + ox_, cy_ + oy_ - .3, r_ - .5, r_ * .6, QEARTH)
        cv.px(cx + ox_ - 1, cy_ + oy_ - 1, QACCENT)
    for (ox_, oy_) in ((-3, -10), (2, -12), (5, -9), (-6, -8)): cv.px(cx + ox_, cy_ + oy_, QLIGHT)
    cv.px(cx + 1, cy_ - 10, QBASE)
    # timber frames, far to near
    frames = [(54, 8, 14), (62, 12, 22), (73, 17, 32), (86, 22, 44)]
    for i, (fy, h_, ht) in enumerate(frames):
        pw = max(2, h_ // 4 + 1)
        dark = i < 2
        body, hi, lo = ((QDEEP, QEARTH, QSHADOW) if dark else (EARTH, ACCENT, QDEEP))
        top = fy - ht
        for s in (-1, 1):
            x0 = cx + s * h_ - (pw if s < 0 else 0)
            for y in range(top, fy + 1):
                for x in range(x0, x0 + pw):
                    if not in_open(x, y): continue
                    cv.px(x, y, hi if (x == x0 and s < 0) or (x == x0 and s > 0) else body)
                    if x == x0 + pw - 1: cv.px(x, y, lo)
        lt = max(2, pw)
        for y in range(top, top + lt):
            for x in range(cx - h_ - pw - 1, cx + h_ + pw + 1):
                if in_open(x, y) or (y >= cy0 and False): cv.px(x, y, hi if y == top else body if y < top + lt - 1 else lo)
        if i == 3:             # corner braces
            for s in (-1, 1):
                for k in range(9):
                    xx = cx + s * (h_ - 1 - k); yy = top + lt + k
                    cv.px(xx, yy, body); cv.px(xx, yy + 1, lo)
            cv.rect(cx - 1, top + lt, cx, top + lt + 5, QEARTH)       # king post stub holding the lamp chain
    # hanging lamp inside the near frame
    lx, ly = cx - 12, 52
    for t in range(-6, 7):
        for u in range(-6, 7):
            d = math.hypot(t, u)
            if d <= 6 and bayer(lx + t, ly + u) < (1 - d / 6.5) * .9 and in_open(lx + t, ly + u):
                if cv.get(lx + t, ly + u)[:3] in (QINK[:3], QSHADOW[:3], QDEEP[:3], QEARTH[:3]):
                    cv.px(lx + t, ly + u, QBASE if d < 3.5 else QDEEP)
    cv.rect(lx - 1, ly - 1, lx + 1, ly + 2, QLIGHT); cv.px(lx, ly - 2, QINK); cv.px(lx, ly, QPAPER)
    for y in range(44, 51): cv.px(lx, y, QINK)
    # ember glints deep in the tunnel and on the walls
    for (gx_, gy_) in ((50, 60), (79, 62), (57, 47), (71, 45), (62, 41), (44, 72), (84, 74)):
        if in_open(gx_, gy_): cv.px(gx_, gy_, QLIGHT)
    # grounding: dark base line + shadow lip under the ring
    for x in range(cx - cr - 10, cx + cr + 11):
        cv.px(x, base + 1, QINK); cv.px(x, base + 2, QINK)
    # ink outline of the opening
    for y in range(H):
        for x in range(W):
            if in_open(x, y) and not all(in_open(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, -1))) and y < base:
                cv.px(x, y, QINK)
    if style == "B":      # timber headframe outside: two posts, crossbeam, pulley
        for s in (-1, 1):
            x0 = cx + s * 38 - 2
            cv.rect(x0, 8, x0 + 4, base + 1, QDEEP); cv.rect(x0, 8, x0, base + 1, ACCENT); cv.rect(x0 + 4, 8, x0 + 4, base + 1, QSHADOW)
            for k in range(14):
                cv.px(x0 + (5 + k if s < 0 else -k), 20 + k, EARTH); cv.px(x0 + (5 + k if s < 0 else -k), 21 + k, QSHADOW)
        cv.rect(cx - 44, 4, cx + 44, 9, QDEEP); cv.rect(cx - 44, 4, cx + 44, 4, ACCENT); cv.rect(cx - 44, 9, cx + 44, 9, QSHADOW)
        cv.ell(cx, 15, 6, 6, QINK); cv.ell(cx, 15, 4.5, 4.5, QEARTH); cv.ell(cx, 15, 1.6, 1.6, QINK)
        for k in range(12): cv.px(cx - 5, 15 + k, QACCENT)
    return cv


# ---------------------------------------------------------------- decor
def lit(cv, c_light, c_mid, c_dark): return c_light, c_mid, c_dark


def iso_box(cv, cx, cy, hw, h, top, left, right, ink=QINK):
    hh = hw // 2
    cv.poly([(cx, cy - h - hh), (cx + hw, cy - h), (cx, cy - h + hh), (cx - hw, cy - h)], top)
    cv.poly([(cx - hw, cy - h), (cx, cy - h + hh), (cx, cy + hh), (cx - hw, cy)], left)
    cv.poly([(cx, cy - h + hh), (cx + hw, cy - h), (cx + hw, cy), (cx, cy + hh)], right)


def crate(cv, cx, cy, hw, h, glow=False):
    iso_box(cv, cx, cy, hw, h, ACCENT, EARTH, QDEEP)
    hh = hw // 2
    for k in range(1, 3):                      # planks
        yy = cy - h + k * h // 3
        cv.line(cx - hw + 1, yy, cx - 1, yy + hh, QDEEP); cv.line(cx + 1, yy + hh, cx + hw - 1, yy, QSHADOW)
    cv.line(cx - hw, cy - h, cx - hw, cy, ACCENT); cv.line(cx, cy + hh, cx, cy - h + hh, QSHADOW)
    cv.line(cx - hw, cy - h, cx, cy - h - hh, PAPER)
    if glow:
        cv.rect(cx - 3, cy - h - 1, cx + 3, cy - h + 1, QINK)
        for i in range(-2, 3, 2): cv.px(cx + i, cy - h, QLIGHT if i else QBASE)
    cv.outline(QINK)


def crate_stack():
    cv = Canvas(34, 38)
    crate(cv, 12, 30, 10, 11); crate(cv, 26, 31, 8, 9, glow=True); crate(cv, 14, 19, 9, 9)
    cv.px(14, 8, QLIGHT)
    return cv


def timber_pile():
    cv = Canvas(40, 22)
    for row, (y, n) in enumerate(((16, 4), (10, 3), (5, 2))):
        for i in range(n):
            x = 6 + i * 8 + (4 if row == 1 else 6 if row == 2 else 0) - (0 if row == 0 else 0)
            cv.rect(x, y - 3, x + 22, y + 2, EARTH); cv.rect(x, y - 3, x + 22, y - 3, ACCENT); cv.rect(x, y + 2, x + 22, y + 2, QDEEP)
            cv.ell(x, y, 3.2, 3.2, ACCENT); cv.ell(x, y, 2.0, 2.0, EARTH); cv.px(x, y, QDEEP)
            for k in range(3, 20, 5): cv.px(x + k, y - 1, QDEEP)
    cv.rect(18, 1, 20, 21, QEARTH)       # a lashing post
    cv.outline(QINK)
    return cv


def ore_pile(seed=1, w=30):
    cv = Canvas(w + 4, 22)
    lumps = []
    for i in range(7):
        lumps.append((2 + hsh(seed, i, 1) * (w - 6) + 2, 10 + hsh(seed, i, 2) * 6, 3 + hsh(seed, i, 3) * 3.5))
    for (x, y, r) in sorted(lumps, key=lambda t: t[1]):
        cv.ell(x, y, r + .7, r * .78 + .6, QINK)
        cv.ell(x, y, r, r * .78, QEARTH)
        cv.ell(x - r * .25, y - r * .25, r * .55, r * .4, QACCENT)
        cv.px(x - r * .4, y - r * .4, QPAPER)
    for i in range(9):
        x = 3 + hsh(seed, i, 7) * (w - 3); y = 8 + hsh(seed, i, 9) * 8
        c = QLIGHT if i % 3 == 0 else QBASE
        cv.px(x, y, c); cv.px(x + 1, y + 1, QDEEP)
    cv.outline(QINK)
    return cv


def boulder(seed=1, w=30, h=20):
    cv = Canvas(w, h)
    for y in range(h):
        for x in range(w):
            k = math.hypot((x + .5 - w / 2) / (w / 2 - 1), (y + .5 - (h - 5)) / (h - 6))
            if k > 1 or y > h - 3: continue
            n = vnoise(x / 3.0, y / 2.4, seed)
            c = QEARTH
            if (x + y) < w * .55 and n > .35: c = QACCENT
            if (x - w / 2) > 3 and (y > h * .5) or n < .22: c = QSHADOW
            if (x + y) < w * .3 and n > .5: c = QPAPER
            cv.px(x, y, c)
    for i in range(2):                         # ember crack
        x0 = w * (.45 + .2 * i); y0 = h * .35
        for k in range(7):
            cv.px(x0 + k * (1 if i else -1) * .6, y0 + k * .9 + (k % 2), QBASE if k % 3 else QLIGHT)
    cv.outline(QINK)
    return cv


def barrels():
    cv = Canvas(30, 26)
    def bar(cx, cy, w=8, h=12):
        cv.rect(cx - w // 2, cy - h, cx + w // 2, cy, EARTH); cv.rect(cx + w // 2 - 1, cy - h, cx + w // 2, cy, QDEEP)
        cv.rect(cx - w // 2, cy - h, cx - w // 2, cy, ACCENT)
        cv.ell(cx, cy - h, w / 2 + .6, 2.4, ACCENT); cv.ell(cx, cy - h, w / 2 - .6, 1.5, QDEEP)
        for yy in (cy - h + 3, cy - 3): cv.rect(cx - w // 2, yy, cx + w // 2, yy, QEARTH)
    bar(9, 22); bar(21, 23); bar(15, 15)
    cv.outline(QINK)
    return cv


def cart_tipped():
    cv = Canvas(40, 24)
    cv.poly([(4, 8), (24, 4), (28, 16), (8, 20)], QEARTH)
    cv.poly([(4, 8), (24, 4), (25, 7), (5, 11)], QPAPER)
    cv.poly([(24, 4), (28, 16), (26, 17), (22, 6)], QSHADOW)
    for (x, y) in ((8, 21), (20, 18)):
        cv.ell(x, y, 3, 3, QINK); cv.ell(x, y, 1.4, 1.4, QACCENT)
    for i, (x, y, r) in enumerate(((32, 17, 3), (36, 19, 2.5), (30, 21, 2.5), (34, 14, 2), (28, 12, 2))):
        cv.ell(x, y, r + .6, r * .8 + .5, QINK); cv.ell(x, y, r, r * .8, QEARTH); cv.px(x - 1, y - 1, QACCENT)
    for (x, y) in ((31, 16), (35, 18), (29, 20), (33, 13)): cv.px(x, y, QLIGHT)
    cv.outline(QINK)
    return cv


def pick_rack():
    cv = Canvas(22, 26)
    cv.rect(2, 22, 19, 23, QDEEP); cv.rect(2, 22, 19, 22, EARTH)
    cv.rect(4, 8, 5, 22, EARTH); cv.rect(16, 8, 17, 22, EARTH); cv.rect(4, 8, 17, 9, QDEEP); cv.rect(4, 8, 17, 8, ACCENT)
    for x in (8, 12):                           # a pick and a shovel leaning on the rack
        cv.line(x, 22, x + 2, 4, EARTH); cv.line(x + 1, 22, x + 3, 4, QDEEP)
    cv.line(5, 4, 14, 4, QACCENT); cv.px(5, 5, QACCENT); cv.px(14, 5, QACCENT); cv.px(10, 3, PAPER)
    cv.rect(12, 2, 16, 5, QEARTH); cv.px(12, 2, QACCENT)
    cv.outline(QINK)
    return cv


def lantern_post(ref):
    return ref.copy()


# ---------------------------------------------------------------- scene composition
def load_sprite(name):
    return Image.open(LK + "sprites/" + name + ".png").convert("RGBA")


def build_scene(style, night):
    X0, Y0, X1, Y1 = 1380, 372, 1660, 600
    g = Image.open(LK + "ground_fg.png").convert("RGBA").crop((X0, Y0, X1, Y1))
    sc = Canvas(X1 - X0, Y1 - Y0); sc.im = g; sc.d = ImageDraw.Draw(g)
    items = []     # (sort_y, Image, x, y, tag)
    d = json.load(open(LK + "placements3d.json"))
    for s in d["sprites"]:
        fx, fy = s["foot"]
        if X0 - 30 < s["x"] < X1 and Y0 - 40 < s["y"] < Y1 + 30 and s["kind"] in ("gateway", "tower", "rock", "lantern", "crystals"):
            items.append((fy, Image.open(LK + s["file"]).convert("RGBA"), s["x"] - X0, s["y"] - Y0, s["kind"]))
    cvv = cave(style); items.append((470, cvv.im, 1456 - X0, 431 - Y0, "cave"))
    # rails decal on the approach
    rl = Canvas(34, 28)
    for k, y in enumerate(range(0, 27, 4)):
        rl.rect(5 + k // 3, y, 28 - k // 3, y + 1, QDEEP); rl.px(5 + k // 3, y, EARTH)
    for s_ in (-1, 1):
        for y in range(28): rl.px(17 + s_ * (9 + y // 6), y, QPAPER if y % 7 else QACCENT)
    items.append((495, rl.im, 1520 - 17 - X0, 519 - Y0, "rails"))
    decor = [
        (crate_stack(), 1486, 547, 1), (barrels(), 1462, 552, 1), (timber_pile(), 1436, 530, 1),
        (ore_pile(3), 1562, 548, 1), (cart_tipped(), 1584, 567, 1), (pick_rack(), 1556, 528, 1),
        (boulder(4, 34, 22), 1444, 566, 1), (boulder(9, 26, 18), 1620, 556, 1), (ore_pile(7, 22), 1470, 574, 1),
        (crate_stack(), 1596, 548, 1),
    ]
    for (cv_, fx, fy, _) in decor:
        items.append((fy, cv_.im, fx - cv_.w // 2 - X0, fy - cv_.h - Y0, "decor"))
    lam = load_sprite("lantern_294")
    for (fx, fy) in ((1494, 526), (1548, 526), (1494, 572), (1548, 572)):
        items.append((fy, lam, fx - lam.width // 2 - X0, fy - lam.height - Y0 + 3, "lamp"))
    items.sort(key=lambda t: t[0])
    for (_, im, x, y, tag) in items: g.alpha_composite(im, (int(x), int(y)))
    sg = sign(style)
    sx = 1520 - sg.w // 2 - X0
    sy = {"A": 404, "B": 414, "C": 399}[style] - Y0
    if night:
        a = g.convert("RGB")
        mult = Image.new("RGB", a.size, (62, 88, 150))
        from PIL import ImageChops
        dark = ImageChops.multiply(a, mult).point(lambda v: int(v * 1.35))
        # light pools: lantern lamps and the cave's ember glow (dither-free soft here, the game dithers them)
        glow = Image.new("RGB", a.size, (0, 0, 0)); gp = glow.load()
        def pool(cx, cy, rx, ry, col, k):
            for y in range(max(0, int(cy - ry)), min(a.size[1], int(cy + ry))):
                for x in range(max(0, int(cx - rx)), min(a.size[0], int(cx + rx))):
                    t = 1 - math.hypot((x - cx) / rx, (y - cy) / ry)
                    if t > 0:
                        t = t * t * k
                        p = gp[x, y]; gp[x, y] = tuple(min(255, int(p[i] + col[i] * t)) for i in range(3))
        for (fx, fy) in ((1494, 526), (1548, 526), (1494, 572), (1548, 572)):
            pool(fx - X0, fy - Y0 - 16, 46, 26, (255, 190, 100), 1.0)
        pool(1520 - X0, 500 - Y0, 62, 40, (255, 110, 50), 1.0)
        pool(1520 - X0, 420 - Y0, 90, 34, (255, 100, 40), .75 if style != "C" else .9)
        a = ImageChops.add(dark, glow)
        g = a.convert("RGBA")
        # self-lit: cave interior lamp area and the neon stay bright
        cv_n = Canvas(g.width, g.height); cv_n.im = g
        cvv2 = cvv.im
        for (x, y) in ((0, 0),):
            pass
    g.alpha_composite(sg.im, (int(sx), int(sy)))
    if style == "B":
        pass
    return g


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "mock":
        out = sys.argv[2]; os.makedirs(out, exist_ok=True)
        for st in "ABC":
            day = build_scene(st, False); night = build_scene(st, True)
            S = 3
            W, H = day.width * S, day.height * S
            sheet = Image.new("RGB", (W, H * 2 + 6), (20, 20, 24))
            sheet.paste(day.convert("RGB").resize((W, H), Image.NEAREST), (0, 0))
            sheet.paste(night.convert("RGB").resize((W, H), Image.NEAREST), (0, H + 6))
            sheet.save(os.path.join(out, "mock_%s.png" % st))
            print("wrote", st)
