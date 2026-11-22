#!/usr/bin/env python3
"""Plinky v2 sprite generator. Detailed pixel + Bayer dither art, palette-index based.
Run: python3 gen_v2.py   (needs Pillow + numpy). Outputs PNG sheets next to this file.
Rules follow docs/art-bible.md: 4x4 Bayer, 3 light bands with dithered edges, index 0 outline,
light from upper left, shadow ellipse 9x4 dropping one band, role-indexed colours."""
import math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.dirname(os.path.abspath(__file__))
SC = 5          # sheet display scale
CELL = 64       # native cell size

PAL = {
 'meadow': ['#14161c', '#1f3b35', '#2f6b55', '#5fa36a', '#b7d978', '#f2e6a0', '#c2784e', '#f6efd9'],
 'quarry': ['#1a1116', '#4a1f2a', '#8a3a2e', '#d0602f', '#e9a845', '#b77a7a', '#5b3d5c', '#f1d9b5'],
}
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
def bay(x, y): return (BAYER[y & 3][x & 3] + 0.5) / 16

def hsh(x, y, s=0):
    n = (x * 374761393 + y * 668265263 + s * 2147483647) & 0xffffffff
    n = ((n ^ (n >> 13)) * 1274126177) & 0xffffffff
    return ((n ^ (n >> 16)) & 0xffff) / 65535

def dith(ramp, l, x, y):
    """Pick from ramp (dark->light) by l in 0..1. Band edges dithered with Bayer."""
    n = len(ramp) - 1
    l = min(max(l, 0), 0.9999)
    v = l * n; lo = int(v); f = v - lo
    f = min(max((f - 0.30) / 0.40, 0), 1)       # dither only in the transition zone
    return ramp[lo + 1] if (f > bay(x, y) and lo < n) else ramp[lo]

class Cv:
    def __init__(s, W=CELL, H=CELL):
        s.W, s.H = W, H
        s.i = np.full((H, W), -1, int); s.o = np.zeros((H, W), int); s.nid = 10
    def new(s): s.nid += 1; return s.nid
    def put(s, x, y, v, id):
        if 0 <= x < s.W and 0 <= y < s.H: s.i[y, x] = v; s.o[y, x] = id
    def get(s, x, y): return s.i[y, x] if 0 <= x < s.W and 0 <= y < s.H else -1
    def _fill(s, pts_yx, fn, id):
        id = id or s.new()
        f = fn if callable(fn) else (lambda x, y, v=fn: v)
        for y, x in pts_yx: s.put(int(x), int(y), f(int(x), int(y)), id)
        return id
    def poly(s, pts, fn, id=None):
        im = Image.new('L', (s.W, s.H), 0)
        ImageDraw.Draw(im).polygon([(float(a), float(b)) for a, b in pts], fill=1)
        return s._fill(np.argwhere(np.array(im) > 0), fn, id)
    def ell(s, cx, cy, rx, ry, fn, id=None):
        ys, xs = np.mgrid[0:s.H, 0:s.W]
        m = ((xs + .5 - cx) / rx) ** 2 + ((ys + .5 - cy) / ry) ** 2 <= 1
        return s._fill(np.argwhere(m), fn, id)
    def rect(s, x0, y0, x1, y1, fn, id=None):
        ys, xs = np.mgrid[0:s.H, 0:s.W]
        m = (xs >= x0) & (xs <= x1) & (ys >= y0) & (ys <= y1)
        return s._fill(np.argwhere(m), fn, id)
    def px(s, x, y, v, id=3): s.put(int(x), int(y), v, id)
    def outline(s):
        i, o = s.i.copy(), s.o.copy()
        for y in range(s.H):
            for x in range(s.W):
                if i[y, x] < 0 or s.o[y, x] < 10 and s.o[y, x] != 1: continue
                me = s.o[y, x]
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < s.W and 0 <= ny < s.H) or s.i[ny, nx] < 0: i[y, x] = 0; break
                    no = s.o[ny, nx]
                    if me >= 10 and no != me and no >= 10: i[y, x] = 0; break
                    if me >= 10 and no == 1 and False: pass
        s.i = i
    def image(s, pal, bg=None):
        arr = np.zeros((s.H, s.W, 3), np.uint8)
        cols = [tuple(int(h[k:k + 2], 16) for k in (1, 3, 5)) for h in PAL[pal]]
        arr[:] = cols[0] if bg is None else cols[bg]
        for y in range(s.H):
            for x in range(s.W):
                if s.i[y, x] >= 0: arr[y, x] = cols[s.i[y, x]]
        return Image.fromarray(arr)

# ---------- shading helpers ----------
LX, LY, LZ = -0.45, -0.6, 0.66
def sph(cx, cy, rx, ry, ramp, bias=0.0, grain=0.14, seed=0):
    def f(x, y):
        nx, ny = (x + .5 - cx) / rx, (y + .5 - cy) / ry
        z = math.sqrt(max(0, 1 - nx * nx - ny * ny))
        l = (nx * LX + ny * LY + z * LZ + 1) / 2 + bias + (hsh(x, y, seed) - .5) * grain
        return dith(ramp, l, x, y)
    return f
def vgrad(y0, y1, ramp, bias=0.0, grain=0.0):
    return lambda x, y: dith(ramp, (y1 - y) / max(1, y1 - y0) + bias + (hsh(x, y) - .5) * grain, x, y)
def flat(ramp, l, grain=0.1):
    return lambda x, y: dith(ramp, l + (hsh(x, y, 5) - .5) * grain, x, y)

def shadow(c, cx, cy, rx=9, ry=4):
    ys, xs = np.mgrid[0:c.H, 0:c.W]
    m = ((xs + .5 - cx) / rx) ** 2 + ((ys + .5 - cy) / ry) ** 2 <= 1
    for y, x in np.argwhere(m):
        if bay(x, y) < 0.6: c.put(int(x), int(y), 1, 2)

def diam(cx, cy, hw=16, hh=8): return [(cx, cy - hh), (cx + hw, cy), (cx, cy + hh), (cx - hw, cy)]

def stone(ramp, bw=8, bh=4, seed=1):
    """brick texture; returns fn(u, v) -> idx, with mortar and per-brick tone"""
    def f(u, v):
        row = v // bh; off = (row % 2) * (bw // 2); col = (u + off) // bw
        if v % bh == 0 or (u + off) % bw == 0: return ramp[0]
        t = hsh(col, row, seed)
        base = 1 + (1 if t > .45 else 0) + (1 if t > .85 and len(ramp) > 3 else 0)
        base = min(base, len(ramp) - 1)
        if v % bh == 1 and base < len(ramp) - 1 and (u + off) % bw > 1: base = min(base + 1, len(ramp) - 1)   # top-edge highlight
        if (hsh(u, v, 9) > .93): base = max(1, base - 1)
        return ramp[base]
    return f

def isobox(c, cx, by, hw, h, top, left, right, id=None):
    """iso box, ground diamond centre (cx, by), half width hw, height h. left/right fn(u,v)."""
    id = id or c.new(); hh = hw // 2
    c.poly([(cx - hw, by - h), (cx - .5, by - h + hh), (cx - .5, by + hh), (cx - hw, by)],
           lambda x, y: left(x - (cx - hw), int(y - (x - (cx - hw)) * .5)), id)
    c.poly([(cx + .5, by - h + hh), (cx + hw, by - h), (cx + hw, by), (cx + .5, by + hh)],
           lambda x, y: right(x - cx, int(y + (x - cx) * .5)), id)
    c.poly(diam(cx, by - h, hw, hh), top, id)
    return id

# ---------- tiles ----------
def tile_ground(c, cx, cy, zone, variant=0, id=1):
    seed = 3 + variant * 7
    if zone == 'meadow':
        ramp = [2, 3, 4]
        def f(x, y):
            l = 0.40 + (hsh(x >> 1, y >> 1, seed) - .5) * .5 + (hsh(x, y, seed + 1) - .5) * .25
            v = dith(ramp, l, x, y)
            return v
    else:
        ramp = [1, 2, 3, 4]
        def f(x, y):
            chk = ((x - cx) // 8 + (y - cy) // 4) & 1                      # warm checker like the mockup
            l = 0.34 + chk * .26 + (hsh(x >> 1, y >> 1, seed) - .5) * .35 + (hsh(x, y, seed + 1) - .5) * .2
            return dith(ramp, l, x, y)
    c.poly(diam(cx, cy), f, id)
    if zone == 'meadow':      # blades: dark base + light tip
        for k in range(11):
            x = cx + int((hsh(k, 1, seed) - .5) * 24); y = cy + int((hsh(k, 2, seed) - .5) * 10)
            if abs(x - cx) / 15 + abs(y - cy) / 7 < .85:
                c.put(x, y, 2, id); c.put(x, y - 1, 4, id)
                if k % 3 == 0: c.put(x + 1, y, 4, id)
    else:                      # tiny ember cracks
        for k in range(5):
            x = cx + int((hsh(k, 7, seed) - .5) * 22); y = cy + int((hsh(k, 8, seed) - .5) * 9)
            if abs(x - cx) / 15 + abs(y - cy) / 7 < .8:
                c.put(x, y, 4, id); c.put(x + 1, y + 1, 3, id)

def tile_path(c, cx, cy, zone, id=1):
    tile_ground(c, cx, cy, zone, 1)
    pr = [6, 5, 7] if zone == 'meadow' else [6, 5, 7]
    def inside(x, y):
        n = (hsh(x >> 1, y >> 1, 9) - .5) * .28
        return abs(x + .5 - cx) / 15 + abs(y + .5 - cy) / 7.5 < .74 + n
    c.poly(diam(cx, cy), lambda x, y: (dith(pr, .35 + (hsh(x, y, 4) - .5) * .5, x, y) if inside(x, y) else c.get(x, y)), id)
    for k in range(9):            # pebbles
        x = cx + int((hsh(k, 11) - .5) * 20); y = cy + int((hsh(k, 12) - .5) * 8)
        if inside(x, y): c.put(x, y, 7, id); c.put(x + 1, y, 5, id); c.put(x, y + 1, 1 if zone == 'meadow' else 1, id)

def plinth_edge(c, cx, cy, zone, id=None):
    id = id or c.new(); d = 10
    earth = [1, 6, 5] if zone == 'meadow' else [0, 6, 5]
    def side(lit):
        def f(x, y):
            strata = ((y + (x >> 2)) // 3) & 1
            l = (.38 if lit else .15) + strata * .2 + (hsh(x, y, 2) - .5) * .35
            return dith(earth, l, x, y)
        return f
    c.poly([(cx - 16, cy), (cx - .5, cy + 8), (cx - .5, cy + 8 + d), (cx - 16, cy + d)], side(True), id)
    c.poly([(cx + .5, cy + 8), (cx + 16, cy), (cx + 16, cy + d), (cx + .5, cy + 8 + d)], side(False), id)
    tile_ground(c, cx, cy, zone, 0, id)
    for k in range(6):   # embedded pebbles
        x = cx - 14 + int(hsh(k, 21) * 28); y = cy + 6 + int(hsh(k, 22) * 8) + (abs(x - cx) >> 1)
        if c.o[min(y, c.H - 1), x] == id and y > cy + 4: c.put(x, y, 7 if zone == 'meadow' else 4, id)

# ---------- walker ----------
def walker(c, cx, cy, face='front', phase=0, squash=0, blink=False, bob=0, zone='meadow'):
    cape = [6, 5, 5, 7]
    shadow(c, cx, cy, 7, 3)
    legs = [(0, 0), (-1, 1), (0, 0), (1, -1)][phase % 4]
    liftL = [0, 1, 0, 0][phase % 4]; liftR = [0, 0, 0, 1][phase % 4]
    cy2 = cy - bob
    id = c.new()
    # boots
    for k, (ox, lift) in enumerate(((-3 + legs[0], liftL), (1 + legs[1], liftR))):
        x0 = cx + ox
        if face == 'side': x0 = cx - 2 + (legs[0] if k == 0 else legs[1] * -1) * 1 + k * 2 - 1
        c.rect(x0, cy2 - 3 - lift, x0 + 2, cy2 - lift - 1, flat([1, 6], .35 + k * .2, .3), id)
        c.rect(x0 - (0 if face != 'side' else 0), cy2 - lift, x0 + 2, cy2 - lift, 1, id)
    # cape body
    top = cy2 - 11 + squash; bot = cy2 - 3
    wt, wb = 3 + (1 if squash else 0), 6 + (1 if squash else 0)
    def body(x, y):
        t = (y - top) / max(1, bot - top)
        l = .62 - (x - cx) / 14 - t * .22
        if (x - cx + 20) % 4 == 0 and t > .35: l -= .26           # cape folds
        return dith(cape, l, x, y)
    c.poly([(cx - wt, top), (cx + wt, top), (cx + wb, bot), (cx - wb, bot)], body, id)
    # belt + buckle
    by = int(top + (bot - top) * .45)
    c.rect(cx - wt - 1, by, cx + wt + 1, by, 6, id); c.rect(cx - 1, by, cx, by, 5, id)
    # satchel strap + bag
    if face != 'back':
        c.poly([(cx - 3, top), (cx - 1, top), (cx + 4, bot), (cx + 2, bot)], lambda x, y: 6, id)
    if face == 'side': c.rect(cx - 7, by - 1, cx - 4, by + 3, flat([1, 6, 5], .5, .3), id)
    if face == 'back': c.rect(cx - 2, by - 5, cx + 2, by - 1, flat([1, 6, 5], .55, .3), id)
    # arms
    sw = legs[0]
    for sx, d in ((-1, 1), (1, -1)):
        ax = cx + sx * (wt + 2)
        if face == 'side':
            if sx == 1: continue
            ax = cx - 1 + sw
        ay = top + 1 + (1 if squash else 0)
        c.rect(ax - 1, ay, ax, ay + 3 + (d * sw if face != 'side' else 0) // 1, flat(cape, .45, .2), id)
        c.px(ax - 1 if sx < 0 else ax, ay + 4 + (d * sw if face != 'side' else 0), 7, id)
    # scarf
    sy = top - 1
    c.rect(cx - 4, sy, cx + 4, sy + 1, flat([1, 2, 3], .55, .3), id)
    if face == 'side': c.rect(cx - 7, sy + 1, cx - 5, sy + 5 + (phase % 2), flat([1, 2, 3], .4, .3), id)
    elif face == 'front': c.rect(cx + 2, sy + 2, cx + 3, sy + 5, flat([1, 2, 3], .35, .3), id)
    # hood
    hy = sy - 5 + squash
    c.ell(cx + (1 if face == 'side' else 0), hy, 6, 5.6, sph(cx - (1 if face == 'side' else 0) - 1, hy - 1, 6, 5.6, cape, -.12, .1), id)
    if face == 'side': c.poly([(cx - 5, hy - 3), (cx - 9, hy - 7 + (phase % 2)), (cx - 3, hy - 5)], flat(cape, .45, .2), id)  # hood tail
    else: c.poly([(cx - 1, hy - 5), (cx + 3, hy - 9), (cx + 3, hy - 5)], flat(cape, .6, .15), id)      # hood peak
    # face
    if face == 'front':
        c.ell(cx, hy + 1, 3.6, 3.4, lambda x, y: dith([5, 7, 7], .95 - (y - hy) * .06 + (x - cx) * -.04, x, y), id)
        for xx in range(cx - 3, cx + 4):                                  # hood shadow over brow
            for yy in (hy - 2, hy - 1):
                if c.o[yy, xx] == id and c.i[yy, xx] in (5, 7) and (bay(xx, yy) < (.75 if yy == hy - 2 else .4)): c.px(xx, yy, 6, id)
        ey = hy + 1
        if blink: c.rect(cx - 2, ey, cx - 1, ey, 0, id); c.rect(cx + 1, ey, cx + 2, ey, 0, id)
        else:
            c.rect(cx - 2, ey - 1, cx - 2, ey, 0, id); c.rect(cx + 2, ey - 1, cx + 2, ey, 0, id)
            c.px(cx - 2, ey - 1, 0, id); c.px(cx + 2, ey - 1, 0, id)
        c.px(cx - 3, ey + 1, 6, id) if bay(cx, cy) < .9 else None; c.px(cx + 3, ey + 1, 6, id)
    elif face == 'side':
        fx = cx + 3
        c.ell(fx, hy + 1, 2.8, 3.3, lambda x, y: dith([5, 7, 7], .9 - (x - fx) * .05, x, y), id)
        ey = hy + 1
        if blink: c.rect(fx, ey, fx + 1, ey, 0, id)
        else: c.rect(fx + 1, ey - 1, fx + 1, ey, 0, id)
        c.px(fx + 2, ey + 2, 6, id)
    else:   # back: hood seam + tassel
        for yy in range(hy - 4, hy + 4): c.px(cx, yy, 6 if yy % 2 else 2, id) if c.o[yy, cx] == id else None
        c.px(cx, hy + 4, 5, id)

# ---------- pads ----------
def pad(c, cx, cy, state, zone):
    if zone == 'meadow': top_r = {'ready': [2, 3, 4], 'pressed': [1, 2, 3], 'locked': [1, 2, 6]}[state]
    else: top_r = {'ready': [2, 3, 4], 'pressed': [1, 2, 3], 'locked': [1, 6, 5]}[state]
    rim_r = [1, 6, 5] if zone == 'meadow' else [0, 6, 5]
    sink = 2 if state == 'pressed' else 0
    cy += sink; thick = 3 - sink + (1 if state != 'pressed' else 0)
    id = c.new()
    shadow(c, cx, cy + 3, 15, 5) if state != 'pressed' else None
    # side walls
    def wall(lit):
        return lambda x, y: dith(rim_r, (.55 if lit else .2) + (hsh(x, y, 4) - .5) * .25, x, y)
    c.poly([(cx - 15, cy), (cx - .5, cy + 7.5), (cx - .5, cy + 7.5 + thick), (cx - 15, cy + thick)], wall(True), id)
    c.poly([(cx + .5, cy + 7.5), (cx + 15, cy), (cx + 15, cy + thick), (cx + .5, cy + 7.5 + thick)], wall(False), id)
    # slab top (rim ring)
    c.poly(diam(cx, cy, 15, 7), lambda x, y: dith(rim_r, .62 - ((x - cx) * -.012) + (hsh(x, y, 6) - .5) * .25, x, y), id)
    # corner studs
    for sx, sy in ((cx - 12, cy), (cx + 12, cy), (cx, cy - 5), (cx, cy + 5)): c.px(sx, sy, 7 if zone == 'meadow' else 4, id)
    # inner face
    def inner(x, y):
        d = abs(x + .5 - cx) / 11 + abs(y + .5 - cy) / 5.5
        l = .55 - d * .18 + (cx - x) * .012 + (cy - y) * .02 + (hsh(x, y, 8) - .5) * .12
        return dith(top_r, l, x, y)
    c.poly(diam(cx, cy, 11, 5), inner, id)
    # lit rim of the inner dish (top-left edges lighter, bottom-right dark)
    for t in range(0, 12):
        x = cx - 11 + t; y = cy - int(t * .5 + .01) if t <= 11 else cy
        c.px(cx - 11 + t, cy - int(t * 5.5 / 11 + .5), top_r[-1], id) if c.get(cx - 11 + t, cy - int(t * 5.5 / 11 + .5)) >= 0 else None
        c.px(cx + t, cy + 5 - int(t * 5.5 / 11 + .5) + 1 - 1, top_r[0], id) if c.get(cx + t, cy + 5 - int(t * 5.5 / 11 + .5)) >= 0 else None
    # centre glyph
    if state == 'locked':
        k = 0 if zone == 'meadow' else 0
        c.rect(cx - 2, cy - 1, cx + 2, cy + 2, 7 if zone == 'meadow' else 7, id)
        c.rect(cx - 1, cy - 3, cx - 1, cy - 1, 7, id); c.rect(cx + 1, cy - 3, cx + 1, cy - 1, 7, id); c.px(cx, cy - 3, 7, id)
        c.px(cx, cy, 0, id); c.px(cx, cy + 1, 0, id)
    else:
        gl = {'ready': 5, 'pressed': 6}[state]
        c.poly(diam(cx, cy, 5, 2.5), lambda x, y: gl if state == 'pressed' else (7 if (x + y) % 3 == 0 else 5), id)
        if state == 'ready': c.px(cx, cy, 7, id); c.px(cx - 1, cy, 7, id)
    if state == 'ready':   # glow dither ring on the ground
        for y in range(cy - 10, cy + 13):
            for x in range(cx - 22, cx + 23):
                d = abs(x + .5 - cx) / 21 + abs(y + .5 - cy) / 10.5
                if 0.93 < d < 1.0 and bay(x, y) < .45 and c.get(x, y) < 0: c.put(x, y, 4 if zone == 'quarry' else 4, 3)

def pad_hot(c, cx, cy):
    pad(c, cx, cy, 'ready', 'quarry')
    c.poly(diam(cx, cy, 11, 5), lambda x, y: dith([3, 4, 7], .55 + (cy - y) * .06 + (hsh(x, y, 1) - .5) * .35, x, y), c.o[cy, cx])
    for k, (dx, dy, v) in enumerate([(-9, 4, 3), (-12, 6, 3), (11, 3, 3), (8, 6, 3), (14, 5, 4), (-5, 8, 3)]): c.px(cx + dx, cy + dy, v, 3)
    for k, (dx, dy) in enumerate([(-6, -10), (3, -13), (8, -9), (-1, -16)]): c.px(cx + dx, cy + dy, 4 if k % 2 else 5, 3)   # rising embers
    c.px(cx - 6, cy - 9, 3, 3); c.px(cx + 3, cy - 12, 3, 3)

# ---------- structures ----------
def gate(c, cx, cy, zone, opened=False):
    sr = [0, 1, 2, 5] if zone == 'meadow' else [0, 6, 5, 7]
    id = c.new()
    tile_ground(c, cx, cy + 2, zone, 0, 1)
    shadow(c, cx, cy + 2, 16, 5)
    if opened:  # floor light cast forward
        for y in range(cy + 2, cy + 8):
            for x in range(cx - 12, cx + 13):
                if abs(x - cx) / 12 + (y - cy - 2) / 6 < 1 and bay(x, y) < .55: c.put(x, y, 4 if zone == 'meadow' else 4, 3)
    # portal
    px0, px1, ptop = cx - 10, cx + 10, cy - 24
    arch = lambda x, y: y >= ptop + 3 or (abs(x - cx) < 8)
    pid = c.new()
    def barrier(x, y):
        d = abs(x - cx) / 10
        if opened:
            l = .55 + (cy - y) * .006 - d * .55 + (hsh(x, y, 3) - .5) * .15
            return dith([2, 3, 4, 7] if zone == 'meadow' else [3, 4, 7], l, x, y)
        sh = ((y // 2) + (x * 1)) % 8 < 1
        l = .28 + (hsh(x >> 1, y >> 1) - .5) * .3 + (d * .12)
        return 3 if sh and zone == 'meadow' else dith([1, 2, 6] if zone == 'meadow' else [1, 6, 2], l, x, y)
    c.rect(px0, ptop, px1, cy + 1, barrier, pid)
    c.rect(px0, ptop, px1, ptop + 1, 0, pid)
    # pillars
    for sx in (-1, 1):
        x0 = cx + sx * 14 - 4; x1 = x0 + 8
        id2 = c.new()
        c.rect(x0, cy - 27, x1 - 1, cy + 2, lambda x, y, xx=x0: (lambda v: v)(
            stone(sr, 8, 4, 2)(x - xx, y)) if (x - xx) > 0 else sr[3], id2)
        c.rect(x0 - 1, cy - 29, x1, cy - 27, flat(sr, .62, .2), id2)              # capital
        c.rect(x0 - 1, cy - 1, x1, cy + 3, flat(sr, .35, .25), id2)               # footing
        c.rect(x0 + (3 if sx > 0 else 1), cy - 22, x0 + 4, cy - 12, sr[1], id2)   # rune slot
    # lintel
    lid = c.new()
    c.rect(cx - 19, cy - 35, cx + 19, cy - 29, stone(sr, 10, 3, 4), lid)
    c.rect(cx - 21, cy - 37, cx + 21, cy - 35, flat(sr, .66, .2), lid)
    c.poly([(cx - 4, cy - 29), (cx + 4, cy - 29), (cx + 2, cy - 24), (cx - 2, cy - 24)], flat(sr, .5, .2), lid)     # keystone
    gl = (5 if zone == 'meadow' else 4) if opened else (6 if zone == 'meadow' else 6)
    for k in range(-3, 4): c.px(cx + k * 5, cy - 32, gl, lid) if abs(k) > 0 else None   # runes
    c.px(cx, cy - 27, gl, lid)
    if opened:
        for k, (dx, dy) in enumerate([(-6, -14), (5, -20), (2, -9), (-3, -26)]): c.px(cx + dx, cy + dy, 7, 3)
    else:   # chain + lock
        c.rect(cx - 3, cy - 12, cx + 3, cy - 6, flat([6, 5, 7], .55, .3), pid)
        c.rect(cx - 2, cy - 17, cx - 2, cy - 12, 7, pid); c.rect(cx + 2, cy - 17, cx + 2, cy - 12, 7, pid); c.rect(cx - 1, cy - 18, cx + 1, cy - 18, 7, pid)
        c.px(cx, cy - 10, 0, pid); c.px(cx, cy - 9, 0, pid)

def shrine(c, cx, cy, zone, charged=False):
    sr = [0, 1, 2, 5] if zone == 'meadow' else [0, 6, 5, 7]
    tile_ground(c, cx, cy + 2, zone, 0, 1)
    shadow(c, cx, cy + 2, 13, 4)
    isobox(c, cx, cy - 2, 14, 5, flat(sr, .7, .15), stone(sr, 7, 3, 2), lambda u, v: stone(sr, 7, 3, 5)(u + 3, v) if True else 0)
    isobox(c, cx, cy - 7, 9, 5, flat(sr, .72, .15), stone(sr, 6, 3, 7), stone(sr, 6, 3, 8))
    # inlay rings on top step
    for k in range(10): c.px(cx - 4 + k, cy - 12 + int(abs(k - 4.5) * .5), 7 if charged else 5, 3) if False else None
    cc = cy - 25 + (0 if not charged else -1)
    top_r, mid_r = ([3, 4, 7], [2, 3, 4]) if zone == 'meadow' else ([4, 7, 7], [3, 4, 7])
    if charged: top_r = [4, 7, 7]; mid_r = [3, 4, 7]
    cid = c.new()
    pts = lambda hw, h1, h2: (cc - h1, cc, cc + h2)
    T, M, B = cc - 10, cc, cc + 10
    def facet(side):
        def f(x, y):
            u = abs(x + .5 - cx) / 6
            base = (.78 if side == 'L' else .42) - u * .1 - (y - T) / 40 + (hsh(x, y, 2) - .5) * .12
            if charged: base += .2
            return dith(top_r if side == 'L' else mid_r, base + (.1 if side == 'L' else 0), x, y)
        return f
    c.poly([(cx - .5, T), (cx - 6, M), (cx - .5, B)], facet('L'), cid)
    c.poly([(cx + .5, T), (cx + 6, M), (cx + .5, B)], facet('R'), cid)
    c.poly([(cx - .5, M - 6), (cx - 3, M), (cx - .5, M + 4)], lambda x, y: 7, cid)       # glint
    c.px(cx - 4, M - 1, 7, cid) if False else None
    # glow ring below crystal
    for y in range(cy - 14, cy + 6):
        for x in range(cx - 14, cx + 15):
            d = abs(x + .5 - cx) / 12 + abs(y + .5 - (cy - 3)) / 6
            if (0.82 < d < 1.0 and bay(x, y) < (.6 if charged else .3)) and c.get(x, y) < 0: c.put(x, y, 5 if zone == 'meadow' else 4, 3)
    # floating shards
    for sx, sy in ((cx - 12, M + 1), (cx + 12, M - 4), (cx + 9, M + 7) if charged else (cx - 9, M - 8)):
        c.poly([(sx, sy - 3), (sx + 2, sy), (sx, sy + 3), (sx - 2, sy)], lambda x, y: top_r[1] if x < sx else mid_r[0 if len(mid_r) else 0], c.new())
    if charged:
        for k in range(8):
            a = k * math.pi / 4
            for r in (13, 15):
                c.px(cx + round(math.cos(a) * r), M + round(math.sin(a) * r * .55), 7 if k % 2 else 5, 3)

# ---------- zone 1 props ----------
def tree_oak(c, cx, cy):
    tile_ground(c, cx, cy, 'meadow', 0, 1)
    shadow(c, cx + 2, cy + 1, 12, 4)
    tid = c.new()
    c.poly([(cx - 2, cy - 18), (cx + 2, cy - 18), (cx + 3, cy - 3), (cx + 6, cy + 1), (cx + 2, cy), (cx - 2, cy), (cx - 6, cy + 1), (cx - 3, cy - 3)],
           lambda x, y: dith([1, 6, 6, 5], .3 + (x - cx) * -.06 + (hsh(x, y, 3) - .5) * .3, x, y), tid)
    for y in range(cy - 12, cy - 3, 3): c.px(cx - 1 + (y % 2), y, 1, tid)
    c.rect(cx - 2, cy - 12, cx + 2, cy - 10, 6, tid)    # bark marks
    ramp = [1, 2, 3, 4]
    lid = c.new()
    clumps = [(cx + 6, cy - 21, 8, 7), (cx - 6, cy - 22, 8, 7), (cx, cy - 27, 9, 8), (cx - 9, cy - 15, 6, 5), (cx + 9, cy - 15, 6, 5), (cx, cy - 14, 9, 6)]
    for k, (x, y, rx, ry) in enumerate(clumps):
        c.ell(x, y, rx, ry, sph(x - 1, y - 2, rx, ry, ramp, .02, .22, k), lid)
    for k in range(34):   # leaf specks
        x = cx - 12 + int(hsh(k, 31) * 24); y = cy - 33 + int(hsh(k, 32) * 22)
        if c.o[y, x] == lid:
            c.put(x, y, 4 if y < cy - 24 else 2, lid)
            if k % 4 == 0: c.put(x + 1, y, 5, lid)
    for k, (dx, dy) in enumerate([(-5, -17), (4, -14), (8, -22)]): c.put(cx + dx, cy + dy, 6, lid)   # apples

def tree_pine(c, cx, cy):
    tile_ground(c, cx, cy, 'meadow', 1, 1)
    shadow(c, cx + 2, cy + 1, 10, 3)
    tid = c.new(); c.rect(cx - 1, cy - 6, cx + 1, cy, lambda x, y: dith([1, 6], .35 + (cx - x) * .2, x, y), tid)
    lid = c.new()
    for k, (y, hw) in enumerate([(cy - 3, 11), (cy - 10, 9), (cy - 17, 7), (cy - 23, 5)]):
        c.poly([(cx, y - 11), (cx + hw, y), (cx - hw, y)],
               lambda x, y2, yy=y: dith([1, 2, 3, 4], .45 + (cx - x) * .035 - (y2 - (yy - 11)) * .01 + (hsh(x, y2, k) - .5) * .35, x, y2), lid)
    for k in range(18):
        x = cx - 8 + int(hsh(k, 41) * 16); y = cy - 30 + int(hsh(k, 42) * 26)
        if c.o[y, x] == lid and x < cx: c.put(x, y, 4, lid)

def rock(c, cx, cy, zone, big=True, mossy=True):
    shadow(c, cx + 1, cy + 1, 10 if big else 7, 3)
    ramp = [1, 6, 5, 7] if zone == 'meadow' else [0, 6, 5, 7]
    rid = c.new()
    pts = [(cx - 9, cy), (cx - 8, cy - 6), (cx - 3, cy - 11), (cx + 4, cy - 10), (cx + 9, cy - 5), (cx + 10, cy), (cx + 5, cy + 2), (cx - 5, cy + 2)]
    if not big: pts = [(cx + (x - cx) * .6, cy + (y - cy) * .6) for x, y in pts]
    def f(x, y):
        s = 1 if big else .6
        l = .5 + ((cx - x) * .05 + (cy - 5 - y) * .05) / s + (hsh(x >> 1, y >> 1, 4) - .5) * .25
        return dith(ramp, l * .85, x, y)
    c.poly(pts, f, rid)
    if big:
        for (x0, y0, x1, y1) in [(cx - 2, cy - 9, cx + 1, cy - 3), (cx + 3, cy - 6, cx + 5, cy)]:     # cracks
            c.px(x0, y0, ramp[0], rid); c.px(x0 + 1, y0 + 2, ramp[0], rid); c.px(x1, y1, ramp[0], rid)
    if mossy and zone == 'meadow':
        for y in range(cy - 12, cy - 4):
            for x in range(cx - 10, cx + 5):
                if c.o[y, x] == rid and hsh(x, y, 6) > .55 and y < cy - 5 - (x - cx) * .2: c.put(x, y, 3 if hsh(x, y, 7) > .4 else 4, rid)
    if zone == 'quarry':   # ember seams
        for k in range(5): c.put(cx - 4 + k * 2, cy - 4 + (k % 2) * 2, 3 if k % 2 else 4, rid)

def tuft(c, cx, cy, zone='meadow'):
    tile_ground(c, cx, cy, zone, 2, 1)
    shadow(c, cx, cy + 1, 5, 2)
    gid = c.new()
    blades = [(-5, 5, 'L'), (-3, 8, 'L'), (-1, 6, 'M'), (1, 9, 'R'), (3, 6, 'R'), (5, 4, 'R'), (0, 4, 'M')]
    for dx, h, d in blades:
        for k in range(h):
            xx = cx + dx + (0 if k < h * .6 else (-1 if d == 'L' else 1 if d == 'R' else 0))
            c.put(xx, cy - k, [2, 3, 3, 4][min(3, k * 4 // h)], gid)

def bush(c, cx, cy):
    tile_ground(c, cx, cy, 'meadow', 0, 1)
    shadow(c, cx + 1, cy + 1, 10, 3)
    bid = c.new()
    for k, (x, y, rx, ry) in enumerate([(cx - 5, cy - 5, 6, 5), (cx + 5, cy - 5, 6, 5), (cx, cy - 8, 7, 6)]):
        c.ell(x, y, rx, ry, sph(x - 1, y - 2, rx, ry, [1, 2, 3, 4], 0, .25, k + 20), bid)
    for (dx, dy) in [(-6, -4), (2, -9), (6, -3), (-1, -6)]: c.put(cx + dx, cy + dy, 6, bid); c.put(cx + dx + 1, cy + dy, 5, bid)    # berries

def flowers(c, cx, cy, variant=0):
    tile_ground(c, cx, cy, 'meadow', 1 + variant, 1)
    cols = [(5, 6), (7, 5), (6, 5)] if variant == 0 else [(5, 7), (6, 6), (7, 6)]
    spots = [(-8, -1), (-3, 3), (3, -2), (7, 2), (0, -4), (-6, 4)]
    for k, (dx, dy) in enumerate(spots):
        x, y = cx + dx, cy + dy; a, b = cols[k % 3]
        fid = c.new()
        c.put(x, y + 1, 2, fid); c.put(x, y + 2, 2, fid)
        c.put(x - 1, y, a, fid); c.put(x + 1, y, a, fid); c.put(x, y - 1, a, fid); c.put(x, y, b, fid)

def mushrooms(c, cx, cy):
    tile_ground(c, cx, cy, 'meadow', 2, 1)
    shadow(c, cx, cy + 1, 7, 2)
    for (dx, dy, r) in [(-3, 1, 4), (4, 0, 3), (1, 3, 2)]:
        x = cx + dx; y = cy + dy - 2
        sid = c.new(); c.rect(x - 1, y - 2, x, y + 1, flat([6, 5, 7], .6, .1), sid)
        mid = c.new()
        c.ell(x, y - 3, r, r * .65, sph(x - 1, y - 4, r, r * .65, [6, 3, 5], 0, .1), mid)
        c.put(x - 1, y - 4, 7, mid); c.put(x + 1, y - 3, 7, mid) if r > 2 else None

def stump(c, cx, cy):
    tile_ground(c, cx, cy, 'meadow', 1, 1)
    shadow(c, cx, cy + 1, 9, 3)
    sid = c.new()
    c.poly([(cx - 6, cy - 6), (cx - 6, cy - 1), (cx - 3, cy + 2), (cx + 3, cy + 2), (cx + 6, cy - 1), (cx + 6, cy - 6)],
           lambda x, y: dith([1, 6, 6, 5], .28 + (cx - x) * .02 + (hsh(x, y, 4) - .5) * .3, x, y), sid)
    c.ell(cx, cy - 6, 6.5, 3.2, lambda x, y: (5 if int(math.hypot((x + .5 - cx), (y + .5 - (cy - 6)) * 2)) % 3 == 1 else 7), sid)
    for y in range(cy - 4, cy + 2, 2): c.put(cx - 3, y, 1, sid); c.put(cx + 2, y + 1, 1, sid)
    c.put(cx + 6, cy - 1, 3, sid); c.put(cx + 5, cy - 2, 4, sid)

def signpost(c, cx, cy):
    tile_ground(c, cx, cy, 'meadow', 0, 1)
    shadow(c, cx, cy + 1, 8, 3)
    pid = c.new(); c.rect(cx - 1, cy - 14, cx, cy, lambda x, y: dith([1, 6], .5 + (cx - x) * .4, x, y), pid)
    bid = c.new()
    c.poly([(cx - 9, cy - 14), (cx + 6, cy - 14), (cx + 9, cy - 11), (cx + 6, cy - 8), (cx - 9, cy - 8)], stone([1, 6, 5], 16, 6, 1) if False else flat([6, 5, 7], .5, .3), bid)
    for k in range(5): c.put(cx - 6 + k * 2, cy - 11, 1, bid)
    c.put(cx + 4, cy - 11, 1, bid); c.put(cx + 5, cy - 11, 1, bid) if False else None

def lantern(c, cx, cy):
    tile_ground(c, cx, cy, 'meadow', 0, 1)
    shadow(c, cx, cy + 1, 6, 2)
    pid = c.new(); c.rect(cx - 1, cy - 12, cx, cy, flat([1, 6], .4, .2), pid)
    c.rect(cx - 4, cy - 17, cx + 3, cy - 12, flat([6, 5], .6, .1), pid)
    c.rect(cx - 3, cy - 16, cx + 2, cy - 13, lambda x, y: 7 if (x + y) % 2 == 0 else 5, pid)
    c.rect(cx - 5, cy - 19, cx + 4, cy - 18, 1, pid)
    for (dx, dy) in [(-7, -16), (6, -14), (-5, -21), (4, -20)]: c.px(cx + dx, cy + dy, 5 if dy < -16 else 4)

def shadow_cell(c, cx, cy):
    tile_ground(c, cx, cy, 'meadow', 0, 1)
    shadow(c, cx, cy, 9, 4)

# ---------- zone 2 props ----------
def lava_tile(c, cx, cy):
    tile_ground(c, cx, cy, 'quarry', 1, 1)
    def crack(x, y):
        d = abs(((x - cx) * .5 + (y - cy)) + math.sin((x - cx) * .45) * 3)
        return d < 1.3
    c.poly(diam(cx, cy), lambda x, y: (dith([3, 4, 7], .45 + (hsh(x, y, 2) - .5) * .5, x, y) if crack(x, y) else c.get(x, y)), 1)
    for x in range(cx - 16, cx + 16):    # dark hot rim around the seam
        for y in range(cy - 8, cy + 8):
            if c.o[y, x] == 1 and not crack(x, y) and any(crack(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))) and hsh(x, y, 1) > .4: c.put(x, y, 2, 1)

def slag_path(c, cx, cy):
    tile_ground(c, cx, cy, 'quarry', 0, 1)
    def inside(x, y): return abs(x + .5 - cx) / 15 + abs(y + .5 - cy) / 7.5 < .72 + (hsh(x >> 1, y >> 1, 9) - .5) * .25
    c.poly(diam(cx, cy), lambda x, y: (dith([0, 6, 5], .4 + (hsh(x, y, 4) - .5) * .5, x, y) if inside(x, y) else c.get(x, y)), 1)
    for k in range(10):
        x = cx + int((hsh(k, 11) - .5) * 20); y = cy + int((hsh(k, 12) - .5) * 8)
        if inside(x, y): c.put(x, y, 5, 1); c.put(x + 1, y, 6, 1); c.put(x, y + 1, 0, 1)
    for (dx, dy) in [(-4, 1), (5, -1)]: c.put(cx + dx, cy + dy, 3, 1)

def boulder(c, cx, cy):
    tile_ground(c, cx, cy, 'quarry', 0, 1)
    rock(c, cx, cy, 'quarry', True)

def spire(c, cx, cy):
    tile_ground(c, cx, cy, 'quarry', 2, 1)
    shadow(c, cx + 3, cy + 1, 11, 4)
    sid = c.new()
    ramp = [0, 6, 5, 7]
    for k, (dx, h, w) in enumerate([(-7, 14, 4), (6, 11, 3), (0, 29, 6)]):
        base = cy + (1 if k < 2 else 2); id2 = c.new()
        top = base - h
        c.poly([(cx + dx - w, base), (cx + dx - w + 1, top + 5), (cx + dx, top), (cx + dx + w - 1, top + 5), (cx + dx + w, base)],
               lambda x, y, dx=dx, w=w, top=top: dith(ramp, .55 - (x - (cx + dx)) / (w * 3.2) + (hsh(x >> 1, y, 3) - .5) * .25 - (y - top) * .004, x, y), id2)
        # hex facet seams
        for y in range(top + 6, base, 4): c.put(cx + dx - 1, y, 0, id2) if k == 2 else None
        c.put(cx + dx, top + 3, 4, id2)
    for (dx, dy) in [(-2, -18), (2, -22), (-1, -9), (3, -14)]: c.put(cx + dx, cy + dy, 3, sid) if c.o[cy + dy, cx + dx] >= 10 else None
    for y in range(cy - 4, cy + 2): c.put(cx - 1, y, 3 if y % 2 else 4, sid) if c.o[y, cx - 1] >= 10 and hsh(cx, y) > .3 else None

def column_cluster(c, cx, cy):
    tile_ground(c, cx, cy, 'quarry', 0, 1)
    shadow(c, cx + 2, cy + 1, 12, 4)
    ramp = [0, 6, 5, 7]
    for k, (dx, h) in enumerate([(-8, 9), (-3, 14), (3, 11), (8, 7), (0, 6)]):
        base = cy + (k % 2) + (2 if k == 4 else 0); id2 = c.new()
        w = 3
        c.poly([(cx + dx - w, base - 2), (cx + dx - w, base - h + 2), (cx + dx, base - h), (cx + dx + w, base - h + 2), (cx + dx + w, base - 2), (cx + dx, base + 1)],
               lambda x, y, dx=dx, h=h, base=base: dith(ramp, (.8 if x <= cx + dx else .4) - (y - (base - h)) * .006 + (hsh(x, y, 2) - .5) * .2, x, y), id2)
        c.put(cx + dx, base - h + 1, 4, id2) if True else None

def ember_vent(c, cx, cy):
    tile_ground(c, cx, cy, 'quarry', 0, 1)
    vid = c.new()
    c.ell(cx, cy + 1, 8, 4, sph(cx - 1, cy, 8, 4, [0, 6, 5], 0, .2), vid)
    c.ell(cx, cy, 5, 2.4, lambda x, y: dith([2, 3, 4, 7], .5 + (cy - y) * .1 + (hsh(x, y, 6) - .5) * .4, x, y), vid)
    for k, (dx, dy, v) in enumerate([(-1, -5, 4), (2, -8, 3), (-2, -11, 5), (1, -14, 6), (3, -17, 6), (-1, -4, 7)]): c.px(cx + dx, cy + dy, v, 3)
    for dy, w in ((-8, 2), (-12, 2), (-16, 3)):   # smoke puffs, dithered
        for y in range(cy + dy - 2, cy + dy + 3):
            for x in range(cx - w - 1, cx + w + 2):
                if (x - cx) ** 2 / (w + 1) ** 2 + (y - cy - dy) ** 2 / 6 <= 1 and bay(x, y) < .55 and c.get(x, y) < 0: c.put(x, y, 5, 3)

def forge_stack(c, cx, cy):
    tile_ground(c, cx, cy, 'quarry', 1, 1)
    shadow(c, cx + 3, cy + 1, 12, 4)
    sr = [0, 1, 2, 5]
    isobox(c, cx, cy - 1, 11, 5, flat(sr, .62, .1), stone(sr, 6, 3, 3), stone(sr, 6, 3, 4))
    id = c.new()
    c.poly([(cx - 7, cy - 6), (cx - 5, cy - 26), (cx + 5, cy - 26), (cx + 7, cy - 6)],
           lambda x, y: stone(sr, 6, 4, 6)(x - cx + 7, y), id)
    c.rect(cx - 7, cy - 29, cx + 7, cy - 26, flat(sr, .6, .15), id)
    c.rect(cx - 5, cy - 27, cx + 5, cy - 27, 0, id)
    c.ell(cx, cy - 28, 4.5, 1.6, lambda x, y: dith([3, 4, 7], .55 + (hsh(x, y, 9) - .5), x, y), id)      # fire mouth
    c.poly([(cx - 3, cy - 10), (cx + 3, cy - 10), (cx + 3, cy - 5), (cx - 3, cy - 5)], vgrad(cy - 10, cy - 5, [2, 3, 4], .1, .3), c.new())  # glowing furnace door
    for k, (dx, dy, v) in enumerate([(-1, -32, 4), (1, -35, 3), (-2, -38, 5), (2, -41, 6), (0, -44, 6)]): c.px(cx + dx, cy + dy, v, 3)
    c.px(cx - 4, cy - 31, 3, 3); c.px(cx + 4, cy - 33, 4, 3)

def anvil(c, cx, cy):
    tile_ground(c, cx, cy, 'quarry', 2, 1)
    shadow(c, cx, cy + 1, 9, 3)
    id = c.new()
    r = [0, 6, 5, 7]
    c.rect(cx - 4, cy - 3, cx + 3, cy, flat(r, .4, .2), id)
    c.rect(cx - 2, cy - 7, cx + 1, cy - 3, flat(r, .45, .2), id)
    c.poly([(cx - 8, cy - 11), (cx + 7, cy - 11), (cx + 5, cy - 7), (cx - 4, cy - 7)], lambda x, y: dith(r, .85 - (x - cx) * .04 - (y - cy + 11) * .06, x, y), id)
    c.poly([(cx - 8, cy - 11), (cx - 12, cy - 10), (cx - 8, cy - 8)], flat(r, .75, .1), id)
    c.rect(cx - 5, cy - 11, cx + 3, cy - 11, 7, id)
    c.px(cx + 1, cy - 14, 4, 3); c.px(cx + 4, cy - 15, 3, 3); c.px(cx - 3, cy - 13, 5, 3)

def ore_cart(c, cx, cy):
    tile_ground(c, cx, cy, 'quarry', 1, 1)
    shadow(c, cx, cy + 1, 11, 3)
    id = c.new()
    c.poly([(cx - 9, cy - 11), (cx + 9, cy - 11), (cx + 7, cy - 3), (cx - 7, cy - 3)], lambda x, y: dith([0, 6, 5, 7], .45 + (cx - x) * .02 + (cy - 8 - y) * .04, x, y), id)
    c.rect(cx - 9, cy - 11, cx + 9, cy - 10, 5, id)
    for k in range(0, 18, 4): c.put(cx - 8 + k, cy - 7, 0, id)
    for (wx) in (cx - 5, cx + 5):
        c.ell(wx, cy - 1, 2.6, 2.6, lambda x, y: 0 if (x == wx or y == cy - 2) else 5, id)
    oid = c.new()
    c.ell(cx, cy - 12, 8, 3.5, sph(cx - 1, cy - 13, 8, 3.5, [2, 3, 4], 0, .4), oid)
    c.put(cx - 3, cy - 13, 7, oid); c.put(cx + 3, cy - 12, 5, oid)

def dead_tree(c, cx, cy):
    tile_ground(c, cx, cy, 'quarry', 2, 1)
    shadow(c, cx + 2, cy + 1, 9, 3)
    id = c.new()
    r = [0, 6, 5]
    bark = lambda x, y: dith(r, .45 + (cx - x) * .08 + (hsh(x, y, 4) - .5) * .3, x, y)
    c.poly([(cx - 3, cy), (cx - 2, cy - 14), (cx + 1, cy - 14), (cx + 3, cy)], bark, id)
    c.poly([(cx - 2, cy - 11), (cx - 9, cy - 19), (cx - 8, cy - 21), (cx - 1, cy - 14)], bark, id)
    c.poly([(cx + 1, cy - 9), (cx + 8, cy - 15), (cx + 9, cy - 17), (cx + 1, cy - 12)], bark, id)
    c.poly([(cx - 1, cy - 14), (cx - 3, cy - 24), (cx - 1, cy - 24), (cx + 1, cy - 14)], bark, id)
    for (dx, dy) in [(0, -5), (-1, -9), (1, -7)]: c.put(cx + dx, cy + dy, 3, id)   # glowing cracks
    c.put(cx - 8, cy - 20, 4, 3)

# ---------- sheet assembly ----------
def build(name, cells, cols, pal_default='meadow', cw=CELL, ch=CELL, note=None):
    rows = (len(cells) + cols - 1) // cols
    lab = 11
    W, H = cols * cw * SC, rows * (ch * SC + lab * 2)
    sheet = Image.new('RGB', (W, H), tuple(int(PAL[pal_default][0][k:k + 2], 16) for k in (1, 3, 5)))
    atlas = Image.new('RGB', (cols * cw, rows * ch))
    try: font = ImageFont.load_default(size=13)
    except Exception: font = ImageFont.load_default()
    d = ImageDraw.Draw(sheet)
    for n, (label, fn, pal) in enumerate(cells):
        c = Cv(cw, ch); fn(c, cw // 2, ch - 18); c.outline()
        im = c.image(pal, 1 if False else None)
        atlas.paste(im, ((n % cols) * cw, (n // cols) * ch))
        big = im.resize((cw * SC, ch * SC), Image.NEAREST)
        x0, y0 = (n % cols) * cw * SC, (n // cols) * (ch * SC + lab * 2)
        sheet.paste(big, (x0, y0))
        hexc = PAL[pal][7]
        d.text((x0 + 6, y0 + ch * SC + 4), label, fill=hexc, font=font)
    sheet.save(os.path.join(OUT, name + '.png'))
    atlas.save(os.path.join(OUT, name + '-1x.png'))
    return sheet

def main():
    M, Q = 'meadow', 'quarry'
    w = lambda face, **k: (lambda c, x, y: walker(c, x, y, face, **k))
    build('walker-sheet-v2', [
        ('front', w('front'), M), ('side', w('side'), M), ('back', w('back'), M), ('idle (blink)', w('front', blink=True, bob=1), M),
        ('walk 1', w('side', phase=0), M), ('walk 2', w('side', phase=1, bob=1), M), ('walk 3', w('side', phase=2), M), ('walk 4', w('side', phase=3, bob=1), M),
        ('walk front 1', w('front', phase=1, bob=1), M), ('walk front 2', w('front', phase=3, bob=1), M), ('press squash', w('front', squash=2), M), ('zone 2 recolour', w('front'), Q),
    ], 4)
    pads = []
    for st in ('ready', 'pressed', 'locked'):
        pads.append(('zone 1 ' + st, (lambda s: lambda c, x, y: (tile_ground(c, x, y - 1, M, 0, 1), pad(c, x, y, s, M)))(st), M))
    for st in ('ready', 'pressed', 'locked'):
        pads.append(('zone 2 ' + st, (lambda s: lambda c, x, y: (tile_ground(c, x, y - 1, Q, 0, 1), pad(c, x, y, s, Q)))(st), Q))
    pads.append(('zone 2 hot (heat 5+)', lambda c, x, y: (tile_ground(c, x, y - 1, Q, 0, 1), pad_hot(c, x, y)), Q))
    build('pads-sheet-v2', pads, 3)
    build('structures-sheet-v2', [
        ('gate locked', lambda c, x, y: gate(c, x, y, M, False), M), ('gate open', lambda c, x, y: gate(c, x, y, M, True), M),
        ('shrine', lambda c, x, y: shrine(c, x, y, M, False), M), ('shrine charged', lambda c, x, y: shrine(c, x, y, M, True), M),
        ('zone 2 gate locked', lambda c, x, y: gate(c, x, y, Q, False), Q), ('zone 2 gate open', lambda c, x, y: gate(c, x, y, Q, True), Q),
        ('zone 2 shrine', lambda c, x, y: shrine(c, x, y, Q, False), Q), ('zone 2 shrine charged', lambda c, x, y: shrine(c, x, y, Q, True), Q),
    ], 4)
    build('zone1-props-sheet-v2', [
        ('grass tile', lambda c, x, y: tile_ground(c, x, y, M, 0), M), ('grass tile b', lambda c, x, y: tile_ground(c, x, y, M, 3), M),
        ('path tile', lambda c, x, y: tile_path(c, x, y, M), M), ('plinth edge', lambda c, x, y: plinth_edge(c, x, y - 4, M), M),
        ('oak tree', tree_oak, M), ('pine tree', tree_pine, M), ('rock', lambda c, x, y: (tile_ground(c, x, y, M, 0), rock(c, x, y, M)), M),
        ('small rock', lambda c, x, y: (tile_ground(c, x, y, M, 2), rock(c, x, y, M, False)), M),
        ('bush', bush, M), ('flowers a', lambda c, x, y: flowers(c, x, y, 0), M), ('flowers b', lambda c, x, y: flowers(c, x, y, 1), M),
        ('grass tuft', tuft, M), ('mushrooms', mushrooms, M), ('stump', stump, M), ('signpost', signpost, M), ('lantern', lantern, M),
    ], 4)
    build('zone2-props-sheet-v2', [
        ('quarry tile', lambda c, x, y: tile_ground(c, x, y, Q, 0), Q), ('lava seam tile', lava_tile, Q),
        ('slag path', slag_path, Q), ('plinth edge', lambda c, x, y: plinth_edge(c, x, y - 4, Q), Q),
        ('slag rock', boulder, Q), ('basalt spire', spire, Q), ('basalt columns', column_cluster, Q), ('ember vent', ember_vent, Q),
        ('forge stack', forge_stack, Q), ('anvil', anvil, Q), ('ore cart', ore_cart, Q), ('scorched tree', dead_tree, Q),
    ], 4)

if __name__ == '__main__':
    main()
