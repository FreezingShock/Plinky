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
    return r <= 1 + noise1(th, 3)
mask = np.zeros((H, W), bool)
for y in range(H):
    for x in range(W): mask[y, x] = inside(x, y)

# ---------- path (polyline in screen space, wobbly) ----------
PATH = [(112, 258), (150, 264), (190, 258), (222, 236), (248, 212), (284, 204), (322, 208), (352, 190), (372, 160), (410, 150), (452, 134), (488, 118)]
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
            l = .32 + (hsh(x, y, 4) - .5) * .5 + (vnoise(x, y, 2, 9) - .5) * .3
            c.put(x, y, dith(PATHR, l, x, y), 1)
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


# ---------- back cliff wall: terraced rock with grass-capped ledges + crystals (layout idea from reference) ----------
top = {}
for x in range(W):
    ys = np.where(mask[:, x])[0]
    if len(ys): top[x] = ys.min()
cl = c.new(); STEP = 7
def cliff_h(x):
    t = (x - 90) / 470.0
    if t < 0 or t > 1: return 0
    env = math.sin(t * math.pi) ** .7
    return (28 + 26 * vnoise(x, 5, 7, 38) + 10 * math.sin(x * .05)) * env
for x, yt in top.items():
    h = int(cliff_h(x) // STEP) * STEP
    if h <= 0: continue
    for k in range(1, h + 1):
        y = yt + 2 - k
        if y < 0: break
        ledge = (k % STEP) >= STEP - 2 and k < h
        cap = k > h - 3
        if cap: v = dith([3, 4], .45 + (hsh(x, y, 3) - .5) * .5, x, y)
        elif ledge: v = dith([2, 3], .4 + (hsh(x, y, 4) - .5) * .5, x, y)
        else:
            l = .22 + (.2 if x < CX else 0) + ((k // 3 + (x >> 3)) & 1) * .12 + (hsh(x, y, 5) - .5) * .35 + (vnoise(x, y, 6, 9) - .5) * .2
            v = dith([1, 2, 6], l, x, y)
        c.put(x, y, v, cl)
# crystals at the cliff foot
def crystal(cx, base, hgt, w):
    cid = c.new()
    c.poly([(cx - w, base), (cx - w // 2, base - hgt * .55), (cx, base - hgt), (cx + w // 2, base - hgt * .6), (cx + w, base)],
           lambda x, y: dith([2, 4, 5, 7], .25 + (cx - x) * .05 * -1 + (base - y) / hgt * .35 + (hsh(x, y, 8) - .5) * .2, x, y), cid)
for (cx_, b_, h_, w_) in [(150, 150, 30, 7), (160, 152, 20, 5), (138, 154, 16, 4), (430, 98, 24, 6), (442, 100, 15, 4)]:
    crystal(cx_, b_, h_, w_)

# ---------- helpers: sprites (tile ground patched out) ----------
G.tile_ground = lambda *a, **k: None
placed = []; layer_shadow = []; layer_body = []
def render(fn, flip=False):
    t = Cv(110, 110); fn(t, 55, 80); i, o = t.i, t.o
    if flip: i, o = i[:, ::-1], o[:, ::-1]
    return i, o
def place(name, fn, x, y, flip=False, **meta):
    i, o = render(fn, flip); k = len(placed) + 1
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
def clear(x, y, grow=0): return 0 <= x < W and 0 <= y < H and mask[y, x] and not on_path(x, y, grow) and (abs(x - CX) / RX) ** 2 + (abs(y - CY) / RY) ** 2 < .93

# ---------- hand-composed layout ----------
S = []   # (kind, x, y, flip)
def add(kind, x, y, flip=False, **m): S.append((kind, x, y, flip, m))

# back-left grove: overlapping trunks and canopies, different depths
add('pine', 178, 128); add('oak', 214, 138); add('pine', 150, 150); add('oak', 238, 120, True); add('bush', 196, 152); add('bush', 262, 140)
add('pine', 132, 118) ; add('rock_s', 222, 158)
# back-right tall pair framing the gate area
add('oak', 520, 108); add('pine', 556, 122); add('bush', 540, 136); add('pine', 494, 100); add('rock_s', 566, 154)
# mid-back, loose singles
add('oak', 360, 98); add('pine', 400, 88); add('bush', 378, 112); add('rock_s', 330, 112)
# left edge
add('oak', 82, 196); add('bush', 70, 218); add('rock_big', 104, 214); add('rock_s', 124, 224); add('mush', 98, 232)
# right edge / foreground
add('rock_big', 548, 210); add('bush', 524, 224); add('rock_s', 508, 236); add('bush', 578, 206)
# foreground clutter, low so it never hides the path or pads
add('stump', 244, 262); add('mush', 268, 258); add('mush', 226, 272, True); add('bush', 372, 270); add('rock_s', 400, 262); add('rock_s', 386, 280)
add('bush', 160, 276); add('rock_big', 450, 256); add('rock_s', 470, 244); add('bush', 438, 270)

# pads (5 for zone 1), loosely arranged along the path, each offset off the line
PADS = [(206, 246, 'ready'), (262, 200, 'ready'), (336, 198, 'ready'), (392, 154, 'locked'), (456, 128, 'locked')]
# landmarks
add('sign', 130, 252); add('lantern', 300, 222); add('lantern', 430, 172)
add('gate', 500, 104 + 12, False)      # at the path end
add('shrine', 566, 176)

kinds = dict(
    oak=G.tree_oak, pine=G.tree_pine, bush=G.bush, stump=G.stump, sign=G.signpost, lantern=G.lantern,
    rock_big=lambda t, x, y: G.rock(t, x, y, 'meadow', True), rock_s=lambda t, x, y: G.rock(t, x, y, 'meadow', False),
    mush=G.mushrooms, gate=lambda t, x, y: G.gate(t, x, y, 'meadow', False), shrine=lambda t, x, y: G.shrine(t, x, y, 'meadow', False))

# shade pools under canopies (ground pass)
for (k, x, y, fl, m) in S:
    if k in ('oak', 'pine'):
        r = 22 if k == 'oak' else 14
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
for (kind, x, y, fl, m) in S: place(kind, kinds[kind], x, y, fl)
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
c.outline()

# ---------- vignette-free output ----------
im = c.image('meadow', None)
bg = tuple(int(G.PAL['meadow'][0][k:k + 2], 16) for k in (1, 3, 5))
im.save(os.path.join(HERE, 'meadow-scene-1x.png'))
im.resize((W * 3, H * 3), G.Image.NEAREST).save(os.path.join(HERE, 'meadow-scene.png'))
json.dump(dict(size=[W, H], pads=[dict(x=p[0], y=p[1], state=p[2]) for p in PADS], props=placed), open(os.path.join(HERE, 'placements.json'), 'w'), indent=1)
print('ok', len(placed), 'sprites', len(decals), 'decals')
