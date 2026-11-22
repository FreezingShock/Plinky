#!/usr/bin/env python3
"""Plinky zone 1 meadow scene composer. Uses the v2 sprite generators, places props
off-grid on an organic island, y-sorts, outlines per object. Needs Pillow + numpy.
Run: python3 gen_meadow.py  -> meadow-scene-1x.png (640x360) and meadow-scene.png (3x)
Also writes placements.json (the data the Godot scene loads)."""
import sys, os, json, math, random
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import numpy as np
import gen_v2 as G
from gen_v2 import Cv, hsh, dith, bay, sph, shadow

W, H = 640, 360
CX, CY = 320, 188          # island centre (screen texels)
RX, RY = 262, 124          # island half extents
rnd = random.Random(11)
c = Cv(W, H)

# ---------- island shape: noisy radius, 2:1 iso aspect ----------
def noise1(t, s):
    return sum(math.sin(t * k + s * 1.7 + k) / k for k in (2, 3, 5, 7)) * 0.07
def inside(x, y):
    dx, dy = (x + .5 - CX) / RX, (y + .5 - CY) / RY
    th = math.atan2(dy, dx); r = math.hypot(dx, dy)
    n = noise1(th, 3) * 1.6 + 0.05 * math.sin(th * 4 + 1)
    if (x - 478) ** 2 / 82 ** 2 + (y - 270) ** 2 / 36 ** 2 < 1: return False   # front-right cove (water)
    return r <= 1 + n
WATER = (lambda x, y: (x - 478) ** 2 / 82 ** 2 + (y - 270) ** 2 / 36 ** 2 < 1)
mask = np.zeros((H, W), bool)
for y in range(H):
    for x in range(W): mask[y, x] = inside(x, y)

# ---------- path (polyline in screen space, wobbly) ----------
PATH = [(112, 258), (150, 264), (190, 258), (222, 240), (252, 222), (290, 214), (334, 208), (368, 188), (378, 160), (362, 136), (338, 118), (330, 104)]
def seg_dist(px, py):
    best = 1e9
    for (x0, y0), (x1, y1) in zip(PATH, PATH[1:]):
        vx, vy = x1 - x0, (y1 - y0) * 2; wx, wy = px - x0, (py - y0) * 2
        t = max(0, min(1, (wx * vx + wy * vy) / (vx * vx + vy * vy)))
        best = min(best, math.hypot(wx - vx * t, wy - vy * t))
    return best
def on_path(x, y, grow=0): return seg_dist(x, y) < 7 + grow + (hsh(x >> 1, y >> 1, 9) - .5) * 5 + math.sin(x * .09) * 1.8

# ---------- ground ----------
def vnoise(x, y, s, sc):
    gx, gy = x / sc, y / sc; x0, y0 = int(math.floor(gx)), int(math.floor(gy)); fx, fy = gx - x0, gy - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = hsh(x0, y0, s); b = hsh(x0 + 1, y0, s); d = hsh(x0, y0 + 1, s); e = hsh(x0 + 1, y0 + 1, s)
    return (a * (1 - fx) + b * fx) * (1 - fy) + (d * (1 - fx) + e * fx) * fy
GRASS = [2, 3, 4]; PATHR = [6, 5, 7]
for y in range(H):
    for x in range(W):
        if not mask[y, x]: continue
        if on_path(x, y):
            worn = vnoise(x, y, 14, 26)
            l = .30 + (hsh(x, y, 4) - .5) * .5 + (vnoise(x, y, 2, 9) - .5) * .3 + (worn - .5) * .55
            if abs(seg_dist(x, y) - 3.2) < .9 and hsh(x >> 2, y >> 1, 6) > .35: l -= .25      # wheel ruts
            c.put(x, y, dith(PATHR if worn > .38 else [6, 6, 5, 7], l, x, y), 1)
        else:
            l = .33 + (vnoise(x, y, 5, 40) - .5) * .5 + (vnoise(x, y, 6, 11) - .5) * .32 + (hsh(x >> 1, y >> 1, 3) - .5) * .22 + (hsh(x, y, 4) - .5) * .12
            c.put(x, y, dith(GRASS, l, x, y), 1)
# path edge fringe: grass bits creeping in, pebbles inside
for y in range(H):
    for x in range(W):
        if mask[y, x] and c.i[y, x] in (6, 5, 7):
            if hsh(x, y, 12) > .985: c.put(x, y, 7, 1); c.put(x + 1, y, 5, 1)
            if hsh(x, y, 13) > .993: c.put(x, y, 1, 1)

# ---------- plinth (ragged earth sides) ----------
D = 18
bottom = {}
for x in range(W):
    ys = np.where(mask[:, x])[0]
    if len(ys): bottom[x] = ys.max()
pl = c.new()
earth = [1, 6, 5]
for x, yb in bottom.items():
    depth = D + int((hsh(x >> 2, 1, 8) - .5) * 5) + int(abs(x - CX) / RX * -6 + 3)
    # sides are lit left, dark right; fade darker toward bottom strata
    lit = x < CX
    for k in range(1, depth + 1):
        y = yb + k
        if y >= H: break
        strata = ((k + (x >> 2)) // 3) & 1
        l = (.40 if lit else .17) + strata * .2 + (hsh(x, y, 2) - .5) * .35 - k / depth * .1
        c.put(x, y, dith(earth, l, x, y), pl)
# hanging roots / pebbles in the plinth
for k in range(60):
    x = rnd.randrange(W); y = bottom.get(x, 0) + rnd.randint(3, 8)
    if x in bottom and c.o[y, x] == pl: c.put(x, y, 7 if k % 3 else 5, pl)


# ---------- mountain wall: jagged faceted rock, strata, moss, ivy, waterfall ----------
top = {}
for x in range(W):
    ys = np.where(mask[:, x])[0]
    if len(ys): top[x] = ys.min()
cl = c.new()
rr = random.Random(5)
cps = [(x, 0) for x in range(30, 640, 34)]
cps = [(x + rr.randint(-8, 8), 0) for x, _ in cps]
def env(x):
    t = (x - 50) / 540.0
    return 0 if (t < 0 or t > 1) else math.sin(t * math.pi) ** .5
peaks = [(x, (22 + rr.random() * 36) * env(x)) for x, _ in cps]
def ridge(x):
    for (x0, h0), (x1, h1) in zip(peaks, peaks[1:]):
        if x0 <= x <= x1: return h0 + (h1 - h0) * (x - x0) / max(1, x1 - x0)
    return 0
WF_X = 470                      # waterfall column
foot_shadow = []
for x, yt in top.items():
    h = int(ridge(x))
    if h <= 2: continue
    sl = ridge(x + 2) - ridge(x - 2)
    lit = sl >= 0
    band0 = (x >> 4) * 3
    for k in range(1, h + 1):
        y = yt + 2 - k
        if y < 0: break
        band = (k + band0 * 2) // 7
        ledge = (k + band0 * 2) % 7 == 0
        l = (.62 if lit else .30) + ((band * 37) % 5) * .035 + (hsh(x, y, 5) - .5) * .30 + (vnoise(x, y, 6, 7) - .5) * .25 - (1 - k / h) * .10
        v = dith([1, 2, 6, 5], l, x, y)
        if ledge: v = 1 if hsh(x, band, 9) > .25 else v
        if hsh(x >> 1, band, 11) > .93 and (k + band0 * 2) % 7 in (1, 2, 3): v = 1       # vertical cracks
        if (k > h - 2) : v = dith([3, 4], .5 + (hsh(x, y, 3) - .5) * .5, x, y) if hsh(x >> 2, 4, 5) > .35 else v   # moss cap
        if ledge and hsh(x >> 1, band, 12) > .55: v = dith([3, 4], .5 + (hsh(x, y, 13) - .5) * .6, x, y)           # mossy ledge
        c.put(x, y, v, cl)
    # ivy / moss drips
    if hsh(x, 14, 3) > .93:
        for k in range(h - 1, max(1, h - 4 - int(hsh(x, 15) * 14)), -1):
            y = yt + 2 - k
            if y >= 0: c.put(x, y, 2 if k % 3 else 3, cl)
    for k in range(1, 5):      # soft shadow where the wall meets the grass
        for xx in (x,):
            y = yt + 2 + k
            if 0 <= y < H and mask[y, xx] and (bay(xx, y) < .62 - k * .12): foot_shadow.append((xx, y))
for (x, y) in foot_shadow:
    if c.o[y, x] == 1 and c.i[y, x] in (3, 4): c.put(x, y, c.i[y, x] - 1, 1)
# waterfall: bright dithered streaks down the face
wf_top = None
for x in range(WF_X - 5, WF_X + 6):
    if x in top:
        h = int(ridge(x)); yt = top[x]
        for k in range(2, h + 1):
            y = yt + 2 - k
            if y < 0: break
            w = 5 - abs(x - WF_X) + (1 if hsh(x, y >> 2, 20) > .6 else 0)
            if abs(x - WF_X) <= w - 1 or abs(x - WF_X) <= 2:
                f = ((y * 2 + (x * 3) + (y >> 3) * 5) % 9) / 9.0
                c.put(x, y, 7 if f > .72 else 4 if f > .35 else 3, cl)
        for k in range(0, 6):      # splash foam at the foot
            for dx in range(-7, 8):
                xx, yy = WF_X + dx, yt + 2 + k // 2
                if abs(dx) < 7 - k and bay(xx, yy) < .55 and 0 <= yy < H and c.o[yy, xx] == 1: c.put(xx, yy, 7, 1)

# crystals: faceted prisms, 3 visible faces with ink between them
def crystal(cx, base, hgt, w, lean=0):
    tx = cx + lean; tipy = base - hgt; sh = base - hgt * .52
    c.poly([(cx - w, base), (cx - w, sh), (tx, tipy), (tx, base + 1)], lambda x, y: dith([4, 5, 5, 7], .45 + (base - y) / hgt * .25 + (x - cx + w) * -.02 + (hsh(x, y, 8) - .5) * .12, x, y))
    c.poly([(tx + .5, base + 1), (tx + .5, tipy), (cx + w, sh), (cx + w, base)], lambda x, y: dith([1, 2, 3], .25 + (base - y) / hgt * .35 + (hsh(x, y, 9) - .5) * .12, x, y))
    for k in range(3): c.px(cx - w + 1, int(sh) + 2 + k * 2, 7)          # glint on the lit face
CRYSTALS = [(105, 186, 22, 6, -1), (116, 190, 34, 8, 1), (130, 189, 16, 5, 2), (142, 192, 24, 6, -1),
            (420, 232, 20, 5, 1), (432, 235, 32, 7, -1), (446, 234, 14, 4, 2),
            (262, 96, 18, 5, 0), (274, 98, 26, 6, 1)]
for (cx_, b_, h_, w_, l_) in CRYSTALS: crystal(cx_, b_, h_, w_, l_)
for (cx_, b_, h_, w_, l_) in CRYSTALS:          # tiny sparkles
    c.px(cx_ + 6, b_ - h_ - 3, 7); c.px(cx_ + 5, b_ - h_ - 2, 5); c.px(cx_ + 7, b_ - h_ - 2, 5)

# ---------- water: cove (cut from the island), pond, stream, with depth bands, shore, foam, lily pads, reeds ----------
STREAM = [(WF_X, 112), (484, 134), (468, 160), (486, 192), (470, 222), (478, 250)]
def stream_d(x, y):
    best = 1e9
    for (x0, y0), (x1, y1) in zip(STREAM, STREAM[1:]):
        vx, vy = x1 - x0, (y1 - y0) * 2; wx, wy = x - x0, (y - y0) * 2
        t = max(0, min(1, (wx * vx + wy * vy) / (vx * vx + vy * vy)))
        best = min(best, math.hypot(wx - vx * t, wy - vy * t))
    return best
POND = lambda x, y: ((x - 196) / 34.0) ** 2 + ((y - 206) / 13.0) ** 2 + (hsh(x >> 1, y >> 1, 77) - .5) * .25 < 1
STRM = lambda x, y: y > 112 and stream_d(x, y) < 5.5 + math.sin(y * .2) * 1.2 and mask[y, x]
wm = np.zeros((H, W), bool)
for y in range(H):
    for x in range(W):
        if WATER(x, y) or (mask[y, x] and (POND(x, y) or STRM(x, y))): wm[y, x] = True
def shift(a, dx, dy):
    r = np.zeros_like(a)
    ys, xs = slice(max(dy, 0), H + min(dy, 0)), slice(max(dx, 0), W + min(dx, 0))
    yd, xd = slice(max(-dy, 0), H + min(-dy, 0)), slice(max(-dx, 0), W + min(-dx, 0))
    r[ys, xs] = a[yd, xd]; return r
NB = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)]
land = mask & ~wm
# depth into water (erosion count), distance of land from water
depth = np.zeros((H, W), int); cur = wm.copy()
for k in range(1, 10):
    nxt = cur.copy()
    for dx, dy in NB: nxt &= shift(cur, dx, dy)
    depth[nxt] = k; cur = nxt
shoredist = np.full((H, W), 99); cur = wm.copy()
for k in range(1, 6):
    nxt = cur.copy()
    for dx, dy in NB: nxt |= shift(cur, dx, dy)
    shoredist[nxt & ~cur & land] = k; cur = nxt
for y in range(H):
    for x in range(W):
        if not wm[y, x]: continue
        d = depth[y, x]
        l = .38 + (vnoise(x, y, 31, 16) - .5) * .3 + d * .06
        if d >= 1: l = .50 - min(d, 7) * .045 + (vnoise(x, y, 33, 12) - .5) * .25
        v = dith([1, 2, 2, 3, 3], max(0, min(.99, 1 - (min(d, 8) / 8.0) * .75 + (vnoise(x, y, 31, 14) - .5) * .3 - .15)), x, y)
        if d <= 1 and (x + y) % 2 == 0 and hsh(x, y, 61) > .35: v = 7       # foam line
        elif d == 2 and bay(x, y) < .25: v = 4
        # ripples / glints, stepped
        if d >= 2 and y % 3 == 0 and hsh(x >> 2, y, 40) > .94: v = 4
        if d >= 3 and hsh(x >> 1, y, 41) > .985: v = 7
        c.put(x, y, v, 1)
# sandy shoreline band + dark wet edge
for y in range(H):
    for x in range(W):
        sd = shoredist[y, x]
        if sd <= 4 and land[y, x] and c.o[y, x] in (1, cl) and c.o[y, x] == 1:
            if sd == 1: v = dith([6, 5], .45 + (hsh(x, y, 42) - .5) * .5, x, y)
            elif sd == 2: v = dith([6, 5, 5], .55 + (hsh(x, y, 43) - .5) * .6, x, y)
            elif sd == 3: v = 5 if hsh(x, y, 44) > .62 else c.i[y, x]
            else: v = 5 if hsh(x, y, 45) > .9 else c.i[y, x]
            c.put(x, y, v, 1)
# pebbles on the shore
for _ in range(120):
    x, y = rnd.randrange(W), rnd.randrange(H)
    if 1 <= shoredist[y, x] <= 3 and land[y, x] and c.o[y, x] == 1: c.put(x, y, 7 if hsh(x, y, 46) > .5 else 6, 1); c.put(x + 1, y, 5, 1)
# lily pads (round pad, notch, highlight) with a few flowers
def lily(cx, cy, r, flower=False, seed=0):
    ang = hsh(cx, cy, seed) * 6.283
    for dy in range(-r, r + 1):
        for dx in range(-2 * r, 2 * r + 1):
            if (dx / (2.0 * r)) ** 2 + (dy / float(r)) ** 2 > 1: continue
            x, y = cx + dx, cy + dy
            if not (0 <= x < W and 0 <= y < H) or not wm[y, x] or depth[y, x] < 2: continue
            a = math.atan2(dy * 2, dx)
            if abs((a - ang + 3.14159) % 6.28318 - 3.14159) < .22 and dx * dx + dy * dy > 1: continue     # notch
            edge = (dx / (2.0 * r)) ** 2 + (dy / float(r)) ** 2 > .62
            c.put(x, y, 2 if edge else (4 if (dx + dy * 2) < -r else 3), 1)
    if flower and 0 <= cx < W:
        for (dx, dy, v) in ((0, -1, 5), (-1, 0, 5), (1, 0, 5), (0, 1, 5), (0, 0, 7), (-1, -1, 6), (1, -1, 6)):
            if 0 <= cx + dx < W and 0 <= cy + dy < H and wm[cy + dy, cx + dx]: c.put(cx + dx, cy + dy, v, 1)
lr = random.Random(21)
for _ in range(100):
    x, y = lr.randint(380, 600), lr.randint(225, 330)
    if wm[y, x] and depth[y, x] >= 3 and len([1 for p in range(0)]) == 0: lily(x, y, lr.choice((2, 2, 3, 3, 4)), lr.random() < .22, lr.randint(1, 9))
for _ in range(40):
    x, y = lr.randint(160, 232), lr.randint(194, 218)
    if wm[y, x] and depth[y, x] >= 2: lily(x, y, lr.choice((2, 2, 3)), lr.random() < .25, lr.randint(1, 9))
for _ in range(40):
    x, y = lr.randint(440, 500), lr.randint(128, 250)
    if wm[y, x] and depth[y, x] >= 2: lily(x, y, 2, lr.random() < .15, lr.randint(1, 9))
# water rocks and reeds at the bank (reeds drawn after props, see decals)
reed_spots = []
for _ in range(900):
    x, y = rnd.randrange(W), rnd.randrange(H)
    if shoredist[y, x] == 2 and land[y, x] and not on_path(x, y, 6): reed_spots.append((x, y))
WATERMASK = wm

# ---------- helpers: sprites (tile ground patched out) ----------
G.tile_ground = lambda *a, **k: None
placed = []; layer_shadow = []; layer_body = []
def stretch(i, o):      # taller conifer: repeat foliage rows, keep base anchored
    ys = []
    for y in range(110):
        ys.append(y)
        if y < 74 and y % 4 == 0: ys.append(y)
    extra = sum(1 for y in ys if y < 80) - 80
    ys = ys[extra: extra + 110] if len(ys) >= 110 + extra else ys
    ys = (ys + [109] * 110)[:110]
    return i[ys], o[ys]
def shrink(f):
    def tf(i, o):
        yy, xx = np.mgrid[0:110, 0:110]
        sy = np.clip((80 + (yy - 80) / f).round().astype(int), 0, 109); sx = np.clip((55 + (xx - 55) / f).round().astype(int), 0, 109)
        return i[sy, sx], o[sy, sx]
    return tf
TF = dict(pine_tall=stretch, pine_small=shrink(.72), oak_small=shrink(.7))
def render(fn, flip=False, tf=None):
    t = Cv(110, 110); fn(t, 55, 80); i, o = t.i, t.o
    if tf: i, o = tf(i, o)
    if flip: i, o = i[:, ::-1], o[:, ::-1]
    return i, o
def place(name, fn, x, y, flip=False, **meta):
    i, o = render(fn, flip, TF.get(name)); k = len(placed) + 1
    placed.append(dict(name=name, x=x, y=y, flip=flip, **meta))
    for yy in range(110):
        for xx in range(110):
            if i[yy, xx] < 0: continue
            X, Y = x + xx - 55, y + yy - 80
            if not (0 <= X < W and 0 <= Y < H): continue
            (layer_shadow if o[yy, xx] == 2 else layer_body).append((y, k, X, Y, int(i[yy, xx]), int(o[yy, xx]) + (k * 100 if o[yy, xx] >= 10 else 0)))
def blit(layer):
    for (_, _, X, Y, v, id) in sorted(layer, key=lambda t: (t[0], t[1])):
        c.put(X, Y, v, id)

# ---------- procedural cover ----------
def tuft2(t, cx, cy, seed=0, n=5, h=6):
    r = random.Random(seed); gid = t.new()
    for _ in range(n):
        dx = r.randint(-3, 3); hh = max(3, h + r.randint(-2, 2)); d = r.choice((-1, 0, 1))
        for k in range(hh):
            xx = cx + dx + (d if k > hh * .6 else 0); t.put(xx, cy - k, [2, 3, 3, 4][min(3, k * 4 // hh)], gid)
def flower(t, cx, cy, a, b):
    fid = t.new(); t.put(cx, cy + 1, 2, fid); t.put(cx, cy + 2, 2, fid)
    t.put(cx - 1, cy, a, fid); t.put(cx + 1, cy, a, fid); t.put(cx, cy - 1, a, fid); t.put(cx, cy, b, fid)
COLS = [(5, 6), (7, 5), (6, 5), (5, 7), (7, 6)]
def clear(x, y, grow=0): return 0 <= x < W and 0 <= y < H and mask[y, x] and not WATERMASK[y, x] and shoredist[y, x] > 5 and not on_path(x, y, grow) and (abs(x - CX) / RX) ** 2 + (abs(y - CY) / RY) ** 2 < .93

# ---------- hand-composed layout ----------
S = []   # (kind, x, y, flip)
def add(kind, x, y, flip=False, **m): S.append((kind, x, y, flip, m))

# back-left grove: overlapping trunks and canopies, different depths
add('pine_tall', 178, 128); add('oak', 214, 138); add('oak_small', 196, 166); add('pine_small', 150, 152); add('oak', 238, 120, True); add('bush', 196, 152); add('bush', 262, 140)
add('pine', 132, 118) ; add('rock_s', 222, 158)
# back-right tall pair framing the gate area
add('oak', 520, 108); add('pine', 556, 122); add('bush', 540, 136); add('pine_tall', 494, 108); add('rock_s', 566, 154)
# mid-back, loose singles
add('oak', 420, 104); add('pine_tall', 452, 98); add('bush', 404, 124); add('pine_small', 282, 108)
# left edge
add('oak', 82, 196); add('bush', 70, 218); add('rock_big', 104, 214); add('rock_s', 124, 224); add('mush', 98, 232)
# right edge / foreground
add('rock_big', 548, 210); add('bush', 524, 224); add('rock_s', 508, 236); add('bush', 578, 206)
# foreground clutter, low so it never hides the path or pads
add('stump', 244, 262); add('mush', 268, 258); add('mush', 226, 272, True); add('bush', 372, 270); add('rock_cl', 396, 256)
add('bush', 160, 276); add('oak_small', 590, 232); add('rock_cl', 556, 240)

# pads (5 for zone 1), loosely arranged along the path, each offset off the line
PADS = [(204, 248, 'ready'), (258, 224, 'ready'), (338, 206, 'ready'), (380, 168, 'locked'), (350, 128, 'locked')]
# landmarks
add('sign', 130, 252); add('lantern', 300, 222); add('lantern', 408, 176)
add('gate', 330, 100, False)      # far end of the path, centred against the cliff
add('shrine', 568, 190)

kinds = dict(
    oak=G.tree_oak, pine=G.tree_pine, pine_tall=G.tree_pine, pine_small=G.tree_pine, oak_small=G.tree_oak, bush=G.bush, stump=G.stump, sign=G.signpost, lantern=G.lantern,
    rock_big=lambda t, x, y: G.rock(t, x, y, 'meadow', True), rock_s=lambda t, x, y: G.rock(t, x, y, 'meadow', False),
    mush=G.mushrooms, gate=lambda t, x, y: G.gate(t, x, y, 'meadow', False), shrine=lambda t, x, y: G.shrine(t, x, y, 'meadow', False))

# shade pools under canopies (ground pass)
for (k, x, y, fl, m) in S:
    if k in ('oak', 'pine', 'pine_tall', 'oak_small', 'pine_small'):
        r = 22 if k == 'oak' else 14 if k != 'oak_small' else 14
        for yy in range(y - 6, y + 9):
            for xx in range(x - r, x + r + 1):
                if 0 <= xx < W and 0 <= yy < H and mask[yy, xx] and c.o[yy, xx] == 1 and ((xx - x) / r) ** 2 + ((yy - y) / (r * .38)) ** 2 < 1 and bay(xx, yy) < .55 and c.i[yy, xx] in (3, 4):
                    c.put(xx, yy, c.i[yy, xx] - 1, 1)

# ground cover: tufts + flower drifts, clustered not uniform
decals = []
def scatter_cluster(cx, cy, n, spread, kind):
    for _ in range(n):
        a = rnd.random() * 6.283; r = abs(rnd.gauss(0, spread))
        x = int(cx + math.cos(a) * r * 1.6); y = int(cy + math.sin(a) * r * .8)
        if clear(x, y, 2): decals.append((y, kind, x, y))
for _ in range(34): scatter_cluster(rnd.randint(70, 570), rnd.randint(90, 280), rnd.randint(3, 8), 14, 'tuft')
for _ in range(16): scatter_cluster(rnd.randint(90, 560), rnd.randint(110, 280), rnd.randint(5, 11), 12, 'flower')
# flowers hugging the path edge and pad rings
for (px, py, _) in PADS: scatter_cluster(px, py, 6, 24, 'tuft'); scatter_cluster(px + 6, py + 6, 4, 22, 'flower')

# draw order: shadows (ground-level), decals, pads, then y-sorted bodies
for (kind, x, y, fl, m) in S:
    if kind != 'gate' and x in top: y = int(max(y, top[x] + {'oak': 46, 'oak_small': 34, 'pine': 56, 'pine_tall': 70, 'pine_small': 40, 'bush': 18}.get(kind, 20)))      # nothing stands on the mountain wall
    if not (0 <= x < W and 0 <= y < H and mask[y, x]) or WATERMASK[y, x] or shoredist[y, x] <= 3: continue
    if kind == 'rock_cl':
        for dx, dy, k2 in ((0, 0, 'rock_big'), (-14, 4, 'rock_s'), (11, 5, 'rock_s')): place(k2, kinds[k2], x + dx, y + dy, fl)
    else: place(kind, kinds[kind], x, y, fl)
for (px, py, st) in PADS:
    place('pad_' + st, lambda t, x, y, s=st: G.pad(t, x, y, s, 'meadow'), px, py)
# walker standing on the path near the start
place('walker', lambda t, x, y: G.walker(t, x, y, 'front'), 164, 264)
blit(layer_shadow)
dd = []
for (y, kind, x, yy) in sorted(decals):
    t = Cv(40, 40)
    if kind == 'tuft': tuft2(t, 20, 30, seed=x * 31 + yy, n=rnd.randint(3, 6), h=rnd.randint(4, 8))
    else: a, b = rnd.choice(COLS); flower(t, 20, 30, a, b)
    for ty in range(40):
        for tx in range(40):
            if t.i[ty, tx] >= 0:
                X, Y = x + tx - 20, yy + ty - 30
                if 0 <= X < W and 0 <= Y < H and c.o[Y, X] == 1: c.put(X, Y, int(t.i[ty, tx]), 1)
blit(layer_body)
rrd = random.Random(8)
for (x, y) in reed_spots:
    if rrd.random() > .22 or c.o[y, x] != 1: continue
    for dx in (-2, 0, 2):
        h = rrd.randint(5, 10); xx = x + dx
        for k in range(h):
            if 0 <= xx < W and 0 <= y - k < H and c.o[y - k, xx] in (1, 0): c.put(xx + (1 if k > h * .7 else 0), y - k, 2 if k < h - 3 else 3, 1)
        if h > 6: c.put(xx + 1, y - h, 6, 1); c.put(xx + 1, y - h - 1, 6, 1)
c.outline()

# ---------- vignette-free output ----------
im = c.image('meadow', None)
bg = tuple(int(G.PAL['meadow'][0][k:k + 2], 16) for k in (1, 3, 5))
im.save(os.path.join(HERE, 'meadow-scene-1x.png'))
im.resize((W * 3, H * 3), G.Image.NEAREST).save(os.path.join(HERE, 'meadow-scene.png'))
json.dump(dict(size=[W, H], pads=[dict(x=p[0], y=p[1], state=p[2]) for p in PADS], props=placed), open(os.path.join(HERE, 'placements.json'), 'w'), indent=1)
print('ok', len(placed), 'sprites', len(decals), 'decals')
