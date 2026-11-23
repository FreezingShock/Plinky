#!/usr/bin/env python3
"""Front-facing 2D props for the Ember Quarry ground (tools/art/gen_quarry.py places them). Every prop is drawn straight
on, lit from the top left, with the quarry's 8 palette indices only (qs.QPAL) so the ground's lava glow can shift
them along the ember ramp. make(kind, seed) -> (PIL RGBA image cropped to its pixels, foot x, foot y inside it)."""
import math
import numpy as np
from PIL import Image
from qs import Spr, qramp, h2

BASALT = qramp(0, 1, 1, 6, 5)
BASALT_HI = qramp(0, 1, 6, 5, 7)
HOT = qramp(2, 3, 4, 4, 7)
AMBER = qramp(1, 2, 3, 4, 7)
COPPER = qramp(1, 2, 3, 4, 4)
STONE = qramp(0, 1, 6, 5, 7)
WOOD = qramp(0, 1, 2, 3, 4)
IRON = qramp(0, 0, 1, 6, 5)

CW_, CH_ = 96, 112
BASE = CH_ - 3


def h2v(x, y, s=0):
    n = (x.astype(np.int64) * 374761393 + y.astype(np.int64) * 668265263 + np.int64(s) * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def new(seed):
    s = Spr(CW_, CH_, seed)
    ids = dict(basalt=s.ramp(BASALT), hi=s.ramp(BASALT_HI), hot=s.ramp(HOT), amber=s.ramp(AMBER), copper=s.ramp(COPPER),
               stone=s.ramp(STONE), wood=s.ramp(WOOD), iron=s.ramp(IRON))
    return s, ids


def col(s, ids, x, w, top, base, ramp='basalt', lean=0.0, seed=0, glow_base=True):
    """One basalt column: lit left face, dark right face, a slanted broken top, joints and a few ember cracks."""
    r = ids[ramp]
    rng = np.random.default_rng(seed)
    l, rr = x - w / 2, x + w / 2
    tl = top + rng.random() * 4; tr = top + 2 + rng.random() * 6
    mid = x - w * 0.12
    s.oid += 1
    pts = [(l, base), (l + lean * .2, tl), (mid + lean * .5, top - 2 - rng.random() * 3), (rr + lean * .2, tr), (rr, base)]
    m = s.poly_mask(pts)
    t = np.clip((s.yy - top) / max(base - top, 1), 0, 1)
    face_l = s.xx + .5 < mid + lean * (1 - t) * .5
    v = np.where(face_l, 0.78 - 0.45 * t, 0.42 - 0.3 * t)
    v += (h2v(s.xx, s.yy // 3, seed) - .5) * 0.12
    j = ((s.yy - int(top)) % 9 == 0) & (s.yy > top + 4)
    v = np.where(j, v - 0.3, v)
    s.paint(m, r, v, obj=False); s.O[m] = s.oid
    topm = m & (s.yy < tl + 2.5) & face_l
    s.V[topm] = 0.97
    if glow_base:
        g = m & (s.yy > base - 8) & (h2v(s.xx // 2, s.yy // 2, seed + 3) > 0.74)
        s.R[g] = ids['hot']; s.V[g] = (0.4 + 0.4 * h2v(s.xx, s.yy, seed))[g]; s.G[g] = True
    ck = m & (h2v(s.xx // 3, s.yy // 4, seed + 7) > 0.965) & (s.yy > top + 8)
    s.R[ck] = ids['hot']; s.V[ck] = 0.35; s.G[ck] = True


def columns(seed):
    s, ids = new(seed); rng = np.random.default_rng(seed)
    n = int(rng.integers(3, 6)); xs = np.linspace(26, 70, n) + rng.uniform(-3, 3, n)
    order = sorted(range(n), key=lambda i: -abs(i - (n - 1) / 2))
    for k, i in enumerate(order):
        hgt = rng.uniform(34, 66) if abs(i - (n - 1) / 2) < 1.1 else rng.uniform(18, 40)
        col(s, ids, xs[i], rng.uniform(9, 13), BASE - hgt, BASE - rng.uniform(0, 4) * (k % 2), 'basalt' if k % 2 else 'hi', rng.uniform(-3, 3), seed + i)
    return s


def boulder(seed, big=1.0):
    s, ids = new(seed); rng = np.random.default_rng(seed)
    rw = rng.uniform(12, 18) * big; rh = rng.uniform(11, 17) * big
    s.rock(48, BASE, rw, rh, ids['basalt'], seed, 6, glow_ramp=ids['hot'], crack_p=0.10)
    if rng.random() < .6:
        s.rock(48 + rw * .9, BASE, rw * .45, rh * .5, ids['hi'], seed + 1, 4)
    return s


def crystals(seed):
    s, ids = new(seed); rng = np.random.default_rng(seed)
    s.rock(48, BASE, 14, 7, ids['basalt'], seed, 5)
    n = int(rng.integers(3, 6))
    for i in range(n):
        x = 48 + (i - (n - 1) / 2) * rng.uniform(5, 7) + rng.uniform(-2, 2)
        h = rng.uniform(16, 40) * (1.0 - 0.25 * abs(i - (n - 1) / 2))
        s.crystal(x, BASE - 2 - rng.uniform(0, 3), rng.uniform(5, 8), h, ids['amber'], lean=rng.uniform(-3, 3), tipw=rng.uniform(0, 2), seed=seed + i, gl=True)
    return s


def ore_vein(seed):
    s, ids = new(seed); rng = np.random.default_rng(seed)
    s.rock(48, BASE, 15, 16, ids['basalt'], seed, 8)
    s.rock(60, BASE, 9, 9, ids['hi'], seed + 2, 5)
    for k in range(10):
        x = int(rng.uniform(38, 62)); y = int(BASE - rng.uniform(3, 20))
        if s.R[y, x] >= 0:
            s.paint(s.poly_mask([(x, y), (x + 2, y - 1), (x + 3, y + 1), (x + 1, y + 2)]) & (s.R >= 0), ids['copper'], 0.55 + 0.4 * rng.random(), obj=False)
    return s


def ruin(seed):
    """A broken wall: courses of cut blocks with staggered joints, ember light in the cracks."""
    s, ids = new(seed); rng = np.random.default_rng(seed)
    w = int(rng.integers(26, 38)); x0 = 48 - w // 2
    rows = int(rng.integers(3, 6))
    for r in range(rows):
        y1 = BASE - r * 8; y0 = y1 - 8
        xs = x0 + (r % 2) * 5; cut = int(rng.integers(0, 3)) * 4 if r >= 2 else 0
        x = xs
        while x < x0 + w - (cut if r >= rows - 1 else 0):
            bw = int(rng.integers(8, 13)); xe = min(x + bw, x0 + w)
            s.poly([(x, y1), (x, y0), (xe, y0 + int(rng.integers(-1, 2))), (xe, y1)], ids['stone'], 0.75 - 0.1 * r, 0.3)
            x = xe
    for k in range(5):
        x = int(rng.uniform(x0 + 2, x0 + w - 2)); y = int(BASE - rng.uniform(2, rows * 8 - 3))
        if s.R[y, x] >= 0:
            s.R[y, x] = ids['hot']; s.V[y, x] = 0.4; s.G[y, x] = True
    return s


def brazier(seed):
    s, ids = new(seed)
    s.poly([(46, BASE), (47, BASE - 22), (50, BASE - 22), (51, BASE)], ids['iron'], 0.6, 0.2)
    s.poly([(41, BASE), (44, BASE - 5), (53, BASE - 5), (56, BASE)], ids['iron'], 0.5, 0.15)
    s.poly([(38, BASE - 24), (40, BASE - 18), (57, BASE - 18), (59, BASE - 24)], ids['iron'], 0.7, 0.25)
    s.poly([(40, BASE - 24), (43, BASE - 34), (46, BASE - 27), (48, BASE - 40), (51, BASE - 28), (54, BASE - 35), (57, BASE - 24)], ids['hot'], 0.7, 0.95, glow=True)
    s.poly([(44, BASE - 24), (48, BASE - 33), (53, BASE - 24)], ids['hot'], 1.0, glow=True, obj=False)
    return s


def stele(seed):
    s, ids = new(seed); rng = np.random.default_rng(seed)
    h = rng.uniform(34, 50)
    s.poly([(38, BASE), (40, BASE - h), (46, BASE - h - 5), (56, BASE - h), (58, BASE)], ids['stone'], 0.85, 0.2)
    s.poly([(52, BASE), (52, BASE - h + 2), (56, BASE - h), (58, BASE)], ids['stone'], 0.4, 0.1, obj=False)
    cx = 47
    for i, yy_ in enumerate((0.7, 0.55, 0.4)):
        y = int(BASE - h * yy_)
        s.paint(s.poly_mask([(cx - 3, y), (cx + 3, y), (cx + 3, y + 1), (cx - 3, y + 1)]), ids['hot'], 0.8, glow=True, obj=False)
        s.paint(s.poly_mask([(cx - 3 + 5 * (i % 2), y), (cx - 2 + 5 * (i % 2), y), (cx - 2 + 5 * (i % 2), y + 4), (cx - 3 + 5 * (i % 2), y + 4)]), ids['hot'], 0.7, glow=True, obj=False)
    s.poly([(34, BASE), (36, BASE - 4), (60, BASE - 4), (62, BASE)], ids['basalt'], 0.6, 0.2)
    return s


def dead_tree(seed):
    s, ids = new(seed); rng = np.random.default_rng(seed)
    h = rng.uniform(46, 66)
    s.poly([(43, BASE), (45, BASE - h * .4), (46, BASE - h), (50, BASE - h * .5), (53, BASE)], ids['basalt'], 0.7, 0.15)
    s.poly([(49, BASE), (50, BASE - h * .5), (53, BASE)], ids['basalt'], 0.3, 0.1, obj=False)
    for i in range(int(rng.integers(3, 6))):
        by = BASE - h * rng.uniform(.3, .95); sd = rng.choice([-1, 1]); ln = rng.uniform(10, 22)
        pts = [(48, by), (48 + sd * ln * .5, by - ln * .45), (48 + sd * ln, by - ln * .5 - rng.uniform(2, 8)), (48 + sd * ln, by - ln * .5 - rng.uniform(2, 8) + 2.5), (48 + sd * ln * .5, by - ln * .45 + 3), (48, by + 3.5)]
        s.poly(pts, ids['basalt'], 0.55, 0.15, obj=False)
    return s


def stalag(seed):
    s, ids = new(seed); rng = np.random.default_rng(seed)
    for i in range(int(rng.integers(4, 8))):
        x = 48 + rng.uniform(-12, 12); h = rng.uniform(12, 32); w = rng.uniform(4, 7)
        s.poly([(x - w, BASE - rng.uniform(0, 3)), (x + rng.uniform(-1, 1), BASE - h), (x + w, BASE - rng.uniform(0, 3))], ids['hi'] if i % 2 else ids['basalt'], 0.8, 0.2)
    return s


def timber(seed):
    s, ids = new(seed)
    for x in (30, 62):
        s.poly([(x, BASE), (x + 1, BASE - 40), (x + 5, BASE - 40), (x + 6, BASE)], ids['wood'], 0.7, 0.25)
        s.poly([(x + 3, BASE), (x + 3, BASE - 40), (x + 5, BASE - 40), (x + 6, BASE)], ids['wood'], 0.35, 0.1, obj=False)
    s.poly([(26, BASE - 38), (27, BASE - 44), (70, BASE - 44), (71, BASE - 38)], ids['wood'], 0.8, 0.3)
    s.poly([(36, BASE - 38), (33, BASE - 30), (36, BASE - 30), (39, BASE - 38)], ids['wood'], 0.5, 0.2)
    s.poly([(58, BASE - 38), (61, BASE - 30), (64, BASE - 30), (61, BASE - 38)], ids['wood'], 0.5, 0.2)
    s.poly([(47, BASE - 38), (47, BASE - 33), (48, BASE - 33), (48, BASE - 38)], ids['iron'], 0.4, obj=False)
    s.poly([(45, BASE - 32), (46, BASE - 34), (49, BASE - 34), (50, BASE - 32), (50, BASE - 27), (45, BASE - 27)], ids['hot'], 0.8, 0.5, glow=True)
    return s


def cart(seed):
    s, ids = new(seed)
    s.poly([(32, BASE - 6), (34, BASE - 17), (62, BASE - 17), (64, BASE - 6)], ids['iron'], 0.7, 0.2)
    s.poly([(34, BASE - 17), (34, BASE - 20), (62, BASE - 20), (62, BASE - 17)], ids['iron'], 0.9, 0.5, obj=False)
    for x in (38, 58):
        s.rock(x, BASE, 5, 5, ids['iron'], seed + x, 4, sides=8)
    s.rock(46, BASE - 17, 9, 5, ids['copper'], seed, 4)
    s.rock(54, BASE - 17, 7, 4, ids['hot'], seed + 1, 3)
    return s


def lantern(seed):
    s, ids = new(seed)
    s.poly([(47, BASE), (48, BASE - 34), (50, BASE - 34), (51, BASE)], ids['iron'], 0.55, 0.2)
    s.poly([(42, BASE - 34), (44, BASE - 37), (55, BASE - 37), (57, BASE - 34)], ids['iron'], 0.7, 0.3)
    s.poly([(44, BASE - 34), (44, BASE - 26), (55, BASE - 26), (55, BASE - 34)], ids['hot'], 0.85, 0.55, glow=True)
    s.poly([(42, BASE - 26), (57, BASE - 26), (55, BASE - 23), (44, BASE - 23)], ids['iron'], 0.5, 0.2, obj=False)
    s.poly([(42, BASE), (44, BASE - 4), (55, BASE - 4), (57, BASE)], ids['basalt'], 0.6, 0.2)
    return s


def lava_rock(seed):
    s, ids = new(seed); rng = np.random.default_rng(seed)
    s.rock(48, BASE, rng.uniform(11, 16), rng.uniform(10, 15), ids['basalt'], seed, 6, glow_ramp=ids['hot'], crack_p=0.45)
    return s


def post(seed):
    s, ids = new(seed)
    s.poly([(46, BASE), (46, BASE - 16), (50, BASE - 18), (50, BASE)], ids['iron'], 0.7, 0.2)
    s.paint(s.poly_mask([(46, BASE - 14), (50, BASE - 14), (50, BASE - 12), (46, BASE - 12)]), ids['hot'], 0.8, glow=True, obj=False)
    return s


KINDS = {'columns': columns, 'boulder': boulder, 'crystals': crystals, 'ore_vein': ore_vein, 'ruin': ruin, 'brazier': brazier,
         'stele': stele, 'dead_tree': dead_tree, 'stalag': stalag, 'timber': timber, 'cart': cart, 'iron_lamp': lantern,
         'lava_rock': lava_rock, 'post': post, 'boulder_big': lambda seed: boulder(seed, 1.45)}
# footprint radius on the ground (ground units; 2r wide and r tall on screen): where the walker cannot stand
FOOT = {'columns': 7, 'boulder': 5, 'crystals': 5, 'ore_vein': 6, 'ruin': 6, 'brazier': 3, 'stele': 3, 'dead_tree': 3, 'stalag': 4,
        'timber': 5, 'cart': 5, 'iron_lamp': 2, 'lava_rock': 5, 'post': 1.5, 'boulder_big': 8}


def make(kind, seed, frame=0):
    s = KINDS[kind](seed)
    img = s.finish(frame)
    bb = img.getbbox()
    fx, fy = CW_ / 2 - bb[0], BASE + 1 - bb[1]
    return img.crop(bb), fx, fy


if __name__ == '__main__':
    import sys
    kinds = list(KINDS)
    sheet = Image.new('RGBA', (len(kinds) * 100, 130), (60, 30, 36, 255))
    for i, k in enumerate(kinds):
        im, fx, fy = make(k, 5 + i)
        sheet.paste(im, (i * 100 + 50 - int(fx), 120 - int(fy)), im)
    sheet.save(sys.argv[1] if len(sys.argv) > 1 else '/tmp/props.png')
