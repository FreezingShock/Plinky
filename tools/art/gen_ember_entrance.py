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


def neon_layer(cv, cells, ox, oy, glow=1.0, off=False, dim=False):
    """Draw neon tubes at (ox, oy) into cv: hot top-left edge, amber body, dithered ember halo around them."""
    S = set((ox + x, oy + y) for x, y in cells)
    if off:
        for (x, y) in S: cv.px(x, y, QSHADOW if (x + y) & 1 else QEARTH)
        return
    R = 8
    for (x, y) in list(S):
        for dy in range(-R, R + 1):
            for dx in range(-R, R + 1):
                px_, py_ = x + dx, y + dy
                if (px_, py_) in S: continue
                d = math.hypot(dx, dy)
                if d > R: continue
                t = (1 - d / (R + .5)) * glow
                if bayer(px_, py_) < t * 0.95:
                    cur = cv.get(px_, py_)
                    lvl = QBASE if d <= 1.5 else QDEEP if d <= 3.5 else QSHADOW
                    if cur[3] == 0 or cur[:3] in (QINK[:3], QSHADOW[:3], QEARTH[:3], QDEEP[:3], QBASE[:3]):
                        cv.px(px_, py_, lvl)
    for (x, y) in S:
        hot = ((x - 1, y) not in S) or ((x, y - 1) not in S)
        cv.px(x, y, (QLIGHT if hot else QBASE) if dim else (QPAPER if hot else QLIGHT))


def sign(style, dim=False):
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
    g_ = .35 if dim else 1.0
    neon_layer(cv, cells, ox, oy, g_, dim=dim)
    neon_layer(cv, arr, 10, (H - ah) // 2, g_, dim=dim)
    neon_layer(cv, arr, W - 10 - aw, (H - ah) // 2, g_, dim=dim)
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
    # ---- interior. The world is a 2:1 elevated orthographic view with the cliff facing the camera, like the gateway and
    # tower sprites: width never converges, depth only moves things UP the screen (one texel of depth is half a texel up).
    gx, gy = cx, 47
    for y in range(H):
        for x in range(W):
            if not in_open(x, y): continue
            dd = math.hypot((x - gx) / 17.0, (y - gy) / 9.0)
            t = max(0.0, 1 - dd) * (1.25 if style == "C" else 1.0)
            lv = t * 4.2 + (bayer(x, y) - .5) * .9
            c = QINK
            if lv > 3.4: c = QLIGHT
            elif lv > 2.4: c = QBASE
            elif lv > 1.5: c = QDEEP
            elif lv > .7: c = QSHADOW
            cv.px(x, y, c)
    fl_top, fl_bot = 52, base
    fh = cr - 1                                    # floor half width: constant, no vanishing point
    for y in range(fl_top, fl_bot + 1):
        for x in range(W):
            if not in_open(x, y) or abs(x + .5 - cx) > fh: continue
            near = (y - fl_top) / float(fl_bot - fl_top)
            warm = max(0.0, near * 1.1 - abs(x - cx) / 44.0)
            lv = warm * 2.6 + (bayer(x, y) - .5) * .9
            c = QSHADOW
            if lv > 1.9: c = QDEEP
            elif lv > .9: c = QEARTH if near > .5 else QSHADOW
            if lv > 2.5: c = QBASE
            cv.px(x, y, c)
    for y in range(fl_top, fl_bot + 1, 2):         # packed-earth speckle so the floor plane reads
        for x in range(cx - fh, cx + fh):
            if in_open(x, y) and hsh(x, y, 5) > .93 and cv.get(x, y)[:3] != QBASE[:3]: cv.px(x, y, QINK if y < 66 else QSHADOW)
    # rails: parallel lines, sleepers every 4 rows (half-foreshortened: 2 texels thick)
    for y in range(fl_bot - 3, fl_top, -4):
        cv.rect(cx - 12, y, cx + 12, y + 1, QDEEP if y > 66 else QSHADOW)
        cv.rect(cx - 12, y, cx + 12, y, EARTH if y > 70 else QEARTH)
        cv.px(cx - 13, y, QSHADOW); cv.px(cx + 13, y, QSHADOW)
    for y in range(fl_top + 1, fl_bot + 1):
        for sx_ in (-8, 8):
            cv.px(cx + sx_, y, QPAPER if y > 62 else QACCENT); cv.px(cx + sx_ + (1 if sx_ > 0 else -1), y, QEARTH if y > 62 else QSHADOW)
    # mine cart, front on: box, top rim strip, wheels
    cy_ = 70
    cv.rect(cx - 8, cy_ - 8, cx + 8, cy_ + 1, QEARTH); cv.rect(cx - 8, cy_ - 11, cx + 8, cy_ - 9, QPAPER)
    cv.rect(cx - 8, cy_ - 8, cx - 8, cy_ + 1, QACCENT); cv.rect(cx + 7, cy_ - 8, cx + 8, cy_ + 1, QSHADOW)
    for i in range(-6, 7, 3): cv.rect(cx + i, cy_ - 7, cx + i, cy_ - 2, QDEEP)
    for ox_ in (-5, 4): cv.ell(cx + ox_ + .5, cy_ + 2, 2.6, 2.2, QINK); cv.px(cx + ox_, cy_ + 2, QACCENT)
    for (ox_, oy_, r_) in ((-5, -12, 3), (0, -14, 4), (5, -12, 3), (-2, -11, 3)):   # ore heap, ember in the cracks
        cv.ell(cx + ox_, cy_ + oy_, r_ + .6, r_ * .8 + .5, QINK)
        cv.ell(cx + ox_, cy_ + oy_ - .3, r_ - .4, r_ * .6, QEARTH)
        cv.px(cx + ox_ - 1, cy_ + oy_ - 1, QACCENT)
    for (ox_, oy_) in ((-3, -13), (2, -15), (5, -12), (-6, -11)): cv.px(cx + ox_, cy_ + oy_, QLIGHT)
    cv.px(cx + 1, cy_ - 13, QBASE)
    # timber frames, far to near. Same width at every depth, each one up the screen by half its depth. Every post
    # stands on a stone footing block and a sill beam ties the post feet together.
    frames = [(58, 0), (67, 1), (77, 2), (86, 3)]
    for (fy, i) in frames:
        pw = 4; hw_ = fh - 2
        dark = i < 2
        body, hi, lo = ((QDEEP, QEARTH, QSHADOW) if dark else (EARTH, ACCENT, QDEEP))
        ht = 44; top = fy - ht
        for sgn in (-1, 1):
            x0 = cx + sgn * hw_ - (pw if sgn < 0 else 0)
            for y in range(top, fy - 3):
                for x in range(x0, x0 + pw):
                    if in_open(x, y): cv.px(x, y, lo if x == x0 + pw - 1 else hi if x == x0 else body)
            # stone footing: wider than the post, front face plus a lit top strip
            for y in range(fy - 3, fy + 1):
                for x in range(x0 - 1, x0 + pw + 1):
                    if in_open(x, y):
                        cv.px(x, y, QACCENT if y == fy - 3 else QEARTH if x < x0 + pw else QSHADOW)
            cv.rect(x0 - 1, fy, x0 + pw, fy, QINK)
            cv.px(x0 + pw // 2, fy - 2, QINK)             # mortar notch
        for x in range(cx - hw_ + pw, cx + hw_ - pw + 1):  # sill beam between the footings
            if in_open(x, fy - 1): cv.px(x, fy - 2, hi); cv.px(x, fy - 1, body)
        for y in range(top, top + 4):
            for x in range(cx - hw_ - pw - 1, cx + hw_ + pw + 1):
                if in_open(x, y): cv.px(x, y, hi if y == top else body if y < top + 3 else lo)
        if i == 3:             # corner braces on the near frame
            for sgn in (-1, 1):
                for k in range(9):
                    xx = cx + sgn * (hw_ - pw - k * 1 + (0 if sgn > 0 else 3)); yy = top + 4 + k
                    cv.px(xx, yy, body); cv.px(xx, yy + 1, lo)
    # hanging lamp inside the near frame
    lx, ly = cx - 11, 54
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
    if style == "B":      # timber headframe outside: two posts on stone footings, braces, crossbeam, pulley
        for sgn in (-1, 1):
            x0 = cx + sgn * 38 - 2
            cv.rect(x0, 8, x0 + 4, base - 4, QDEEP); cv.rect(x0, 8, x0, base - 4, ACCENT); cv.rect(x0 + 4, 8, x0 + 4, base - 4, QSHADOW)
            # footing: a stone plinth (front face and lit top strip) with a base plate and two iron straps
            cv.rect(x0 - 3, base - 8, x0 + 7, base - 7, QACCENT)                 # top face, seen from above
            cv.rect(x0 - 3, base - 6, x0 + 7, base + 1, QEARTH)                  # front face
            cv.rect(x0 - 3, base - 6, x0 - 3, base + 1, QACCENT); cv.rect(x0 + 7, base - 6, x0 + 7, base + 1, QSHADOW)
            for yy in (base - 3,): cv.rect(x0 - 3, yy, x0 + 7, yy, QSHADOW)      # course line
            cv.rect(x0 - 1, base - 9, x0 + 5, base - 8, QPAPER)                   # iron base plate
            for yy in (base - 14, base - 22): cv.rect(x0, yy, x0 + 4, yy, QPAPER)
            cv.rect(x0 - 3, base + 2, x0 + 7, base + 2, QINK)
            for k in range(14):        # diagonal brace to the cliff
                cv.px(x0 + (5 + k if sgn < 0 else -k), 20 + k, EARTH); cv.px(x0 + (5 + k if sgn < 0 else -k), 21 + k, QSHADOW)
        cv.rect(cx - 44, 4, cx + 44, 9, QDEEP); cv.rect(cx - 44, 4, cx + 44, 4, ACCENT); cv.rect(cx - 44, 9, cx + 44, 9, QSHADOW)
        cv.ell(cx, 15, 6, 6, QINK); cv.ell(cx, 15, 4.5, 4.5, QEARTH); cv.ell(cx, 15, 1.6, 1.6, QINK)
        for k in range(12): cv.px(cx - 5, 15 + k, QACCENT)
    return cv


# ---------------------------------------------------------------- decor
def lit(cv, c_light, c_mid, c_dark): return c_light, c_mid, c_dark


def front_box(cv, cx, base_y, w, h, top, front, side, d=6):
    """Front-facing box in the world's elevated view: the front face is a plain rectangle, the top is a strip d/2 texels
    tall straight above it (depth only moves up the screen), and a sliver of right side shows the light from the left."""
    x0, x1 = cx - w // 2, cx + w // 2
    cv.rect(x0, base_y - h, x1, base_y, front)
    cv.rect(x0, base_y - h - d // 2, x1, base_y - h - 1, top)
    cv.rect(x1 - 1, base_y - h, x1, base_y, side)
    cv.rect(x0, base_y, x1, base_y, side)


def crate(cv, cx, cy, hw, h, glow=False):
    w = hw * 2
    front_box(cv, cx, cy, w, h, ACCENT, EARTH, QDEEP, d=7)
    x0, x1 = cx - hw, cx + hw
    cv.rect(x0, cy - h, x1, cy - h, QDEEP); cv.rect(x0, cy - h // 2, x1, cy - h // 2, QDEEP)   # plank seams
    cv.line(x0, cy, x1, cy - h, QDEEP) if h > 8 else None                                      # cross brace
    cv.rect(x0, cy - h - 3, x0, cy, PAPER if False else ACCENT)
    cv.rect(x0, cy - h - 3, x1, cy - h - 3, PAPER)
    if glow:
        cv.rect(cx - 3, cy - h - 2, cx + 3, cy - h - 1, QINK)
        for i in range(-2, 3, 2): cv.px(cx + i, cy - h - 2, QLIGHT if i else QBASE)
    cv.outline(QINK)


def crate_stack():
    cv = Canvas(36, 36)
    crate(cv, 12, 33, 10, 12); crate(cv, 27, 34, 8, 9, glow=True); crate(cv, 13, 20, 8, 9)
    return cv


def timber_pile():
    cv = Canvas(40, 22)
    for row, (y, n) in enumerate(((16, 4), (10, 3), (5, 2))):
        for i in range(n):
            x = 6 + i * 8 + (4 if row == 1 else 6 if row == 2 else 0) - (0 if row == 0 else 0)
            cv.rect(x, y - 3, x + 22, y + 2, EARTH); cv.rect(x, y - 3, x + 22, y - 3, ACCENT); cv.rect(x, y + 2, x + 22, y + 2, QDEEP)
            cv.rect(x, y - 3, x + 1, y + 2, ACCENT)
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


def dirt_apron(g, X0, Y0):
    """Worn, trampled dirt and spoil around the mine mouth, thinning into the grass by 4x4 dither. The sand path stays."""
    sand = ACCENT[:3]
    for y in range(g.height):
        for x in range(g.width):
            wx, wy = x + X0, y + Y0
            # main apron under the cliff foot, plus a lobe that follows the path south
            e1 = math.hypot((wx - 1520) / 118.0, (wy - 540) / 36.0)
            e2 = math.hypot((wx - 1522) / 40.0, (wy - 580) / 30.0)
            e = min(e1, e2 * 1.05) + (vnoise(wx / 6.0, wy / 4.0, 31) - .5) * .35
            if e > 1.0 or wy < 506: continue
            t = 1.0 - e                      # 0 at the rim, 1 in the middle
            if t < .2 and bayer(wx, wy) > t / .2: continue
            cur = g.getpixel((x, y))
            if cur[:3] == sand: continue
            n = vnoise(wx / 2.0, wy / 1.6, 33)
            c = EARTH
            if n > .70: c = ACCENT if bayer(wx, wy) < .45 else EARTH
            elif n < .30: c = QDEEP
            if hsh(wx, wy, 7) > .965: c = QEARTH           # pebbles
            if t < .45 and n > .5 and c == EARTH: c = QDEEP if bayer(wx, wy) < .3 else EARTH   # darker trampled rim
            g.putpixel((x, y), c)


LAMPS = ((1484, 528), (1560, 528))   # lantern feet, 76 apart (ordinary lamps keep 75 texels apart), nothing on the walk lane
CAVE_AT = (1456, 431)        # cave sprite top-left; its ground contact is y 522
SIGN_Y = 414


def decor_list():
    """(canvas, foot x, foot y, kind). Everything sits at least 20 texels off the path lane (x 1503..1540)."""
    return [
        (crate_stack(), 1450, 547, "crates"), (barrels(), 1424, 562, "barrels"), (timber_pile(), 1408, 534, "timber"),
        (ore_pile(3), 1580, 556, "ore"), (cart_tipped(), 1598, 574, "cart"), (pick_rack(), 1586, 526, "rack"),
        (boulder(4, 34, 22), 1438, 580, "boulder"), (boulder(9, 26, 18), 1644, 566, "boulder"),
        (ore_pile(7, 22), 1470, 580, "ore"), (crate_stack(), 1620, 544, "crates"),
    ]


def build_scene(style, night):
    X0, Y0, X1, Y1 = 1380, 372, 1660, 600
    g = Image.open(LK + "ground_fg.png").convert("RGBA").crop((X0, Y0, X1, Y1))
    sc = Canvas(X1 - X0, Y1 - Y0); sc.im = g; sc.d = ImageDraw.Draw(g)
    dirt_apron(g, X0, Y0)
    items = []     # (sort_y, Image, x, y, tag)
    d = json.load(open(LK + "placements3d.json"))
    for s in d["sprites"]:
        fx, fy = s["foot"]
        if X0 - 30 < s["x"] < X1 and Y0 - 40 < s["y"] < Y1 + 30 and s["kind"] in ("gateway", "tower", "rock", "lantern", "crystals"):
            items.append((fy, Image.open(LK + s["file"]).convert("RGBA"), s["x"] - X0, s["y"] - Y0, s["kind"]))
    cvv = cave(style); items.append((470, cvv.im, CAVE_AT[0] - X0, CAVE_AT[1] - Y0, "cave"))
    # rails decal on the approach
    rl = Canvas(34, 28)
    for y in range(0, 27, 4): rl.rect(4, y, 29, y + 1, QDEEP); rl.rect(4, y, 29, y, EARTH)
    for x_ in (9, 25):
        for y in range(28): rl.px(x_, y, QPAPER if y % 7 else QACCENT); rl.px(x_ + 1, y, QEARTH)
    items.append((495, rl.im, 1520 - 17 - X0, 519 - Y0, "rails"))
    decor = decor_list()
    for (cv_, fx, fy, _) in decor:
        items.append((fy, cv_.im, fx - cv_.w // 2 - X0, fy - cv_.h - Y0, "decor"))
    lam = load_sprite("lantern_294")
    for (fx, fy) in LAMPS:
        items.append((fy, lam, fx - lam.width // 2 - X0, fy - lam.height - Y0 + 3, "lamp"))
    items.sort(key=lambda t: t[0])
    for (_, im, x, y, tag) in items: g.alpha_composite(im, (int(x), int(y)))
    sg = sign(style)
    sx = 1520 - sg.w // 2 - X0
    sy = {"A": 404, "B": SIGN_Y, "C": 399}[style] - Y0
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
        for (fx, fy) in LAMPS:
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


def dirt_decal():
    """The dirt apron as an alpha sprite over the baked ground (sand path pixels and grass outside stay untouched)."""
    X0, Y0, X1, Y1 = 1370, 506, 1670, 620
    g = Image.open(LK + "ground_fg.png").convert("RGBA").crop((X0, Y0, X1, Y1))
    before = g.copy()
    dirt_apron(g, X0, Y0)
    out = Image.new("RGBA", g.size, CLEAR)
    for y in range(g.height):
        for x in range(g.width):
            if g.getpixel((x, y)) != before.getpixel((x, y)): out.putpixel((x, y), g.getpixel((x, y)))
    return out, X0, Y0


def export():
    out = os.path.join(LK, "entrance"); os.makedirs(out, exist_ok=True)
    sprites = []
    def add(im, name, fx, fy, kind, x=None, y=None):
        im.save(os.path.join(out, name + ".png"))
        w, h = im.size
        x = fx - w // 2 if x is None else x; y = fy - h if y is None else y
        sprites.append(dict(file="entrance/%s.png" % name, kind=kind, x=int(x), y=int(y), w=w, h=h, foot=[float(fx), float(fy)], sort_y=float(fy)))
    dimg, dx, dy = dirt_decal(); add(dimg, "dirt", 1520, 455, "ember_flat", dx, dy)
    cv = cave("B"); add(cv.im, "cave", 1520, 470, "ember_flat", CAVE_AT[0], CAVE_AT[1])
    rl = Canvas(34, 28)
    for y in range(0, 27, 4): rl.rect(4, y, 29, y + 1, QDEEP); rl.rect(4, y, 29, y, EARTH)
    for x_ in (9, 25):
        for y in range(28): rl.px(x_, y, QPAPER if y % 7 else QACCENT); rl.px(x_ + 1, y, QEARTH)
    add(rl.im, "rails", 1520, 495, "ember_flat", 1503, 519)
    counts = {}
    glints = [[1520, 489], [1503, 497], [1538, 495], [1513, 480], [1529, 484], [1508, 506], [1534, 508]]
    for (cvv, fx, fy, tag) in decor_list():
        counts[tag] = counts.get(tag, 0) + 1
        add(cvv.im, "%s_%d" % (tag, counts[tag]), fx, fy, "ember_prop")
        if tag in ("ore", "cart", "boulder", "crates"):
            glints += [[fx - 5, fy - 9], [fx + 5, fy - 6], [fx, fy - 13]]
    lam = [s for s in json.load(open(LK + "placements3d.json"))["sprites"] if s["file"] == "sprites/lantern_294.png"][0]
    for (fx, fy) in LAMPS:
        sprites.append(dict(file=lam["file"], nrm=lam["nrm"], kind="lantern", x=fx - 10, y=fy - 26, w=19, h=29, foot=[float(fx), float(fy)], sort_y=float(fy)))
    on, dim = sign("B"), sign("B", dim=True)
    on.save(os.path.join(out, "sign_on.png")); dim.save(os.path.join(out, "sign_dim.png"))
    sx = 1520 - on.w // 2
    data = dict(sprites=sprites, glints=glints,
                sign=dict(x=sx, y=SIGN_Y, w=on.w, h=on.h, on="entrance/sign_on.png", dim="entrance/sign_dim.png"),
                glow=dict(cave=[1520, 496, 46, 30], sign=[1520, SIGN_Y + 14, on.w // 2 + 16, 24]))
    json.dump(data, open(os.path.join(out, "entrance.json"), "w"), indent=1)
    print("exported", len(sprites), "sprites,", len(glints), "glints")


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "export": export(); sys.exit(0)
    if cmd == "mock":
        out = sys.argv[2]; os.makedirs(out, exist_ok=True)
        for st in (sys.argv[3] if len(sys.argv) > 3 else "ABC"):
            day = build_scene(st, False); night = build_scene(st, True)
            S = 3
            W, H = day.width * S, day.height * S
            sheet = Image.new("RGB", (W, H * 2 + 6), (20, 20, 24))
            sheet.paste(day.convert("RGB").resize((W, H), Image.NEAREST), (0, 0))
            sheet.paste(night.convert("RGB").resize((W, H), Image.NEAREST), (0, H + 6))
            sheet.save(os.path.join(out, "mock_%s.png" % st))
            print("wrote", st)
