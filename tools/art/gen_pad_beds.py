#!/usr/bin/env python3
"""Pad beds seen from above: the baked flower art for the meadow pads (texel_pad.gd, _draw_flowers).

Design: Nathan picked style A, "mounds" (2026-11-24), from the mockups in
plinky/pad-stage-mockups/ on the project files. Each stage is a small signed-distance scene
ray-marched from an elevated 2:1 view (1 world unit = 1 texel). Light comes from the upper left,
the bed shades in 4x4 Bayer steps, and every object has a 1 texel ink outline.

Output per stage, all 48 x 44 with the plate centre at (24, 27), so texel_pad.gd draws them at
(-24, top - 27):
  shade_s<n>.png            the plate's shadow from the bed (ink, translucent). Drawn on the plate.
  leaf_s<n>.png             leaves, stems and the crown, in their own colours. The same for every flower.
  <flower>_bloom_s<n>.png   the blooms in greyscale tones. texel_pad.gd multiplies them by the stat colour,
                            so colour-blind tints still apply at runtime.

Run from the repo root: python3 tools/art/gen_pad_beds.py
Needs numpy and Pillow. Stage 1 is one bloom, stage 5 the crowned bed.
"""
import math
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "art", "zone1", "pads"))

W, H = 48, 44
COL0, ROW0 = 24, 27           # plate centre (top face, z = 0) in the sprite
RS = 7.0                      # plate half side (a square projects to the 28 x 14 diamond)
T = 3.0                       # slab thickness
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
RAY = np.array([-1.0, -1.0, -1.0])
LIGHT = np.array([-0.55, 0.55, 1.0])
LIGHT = LIGHT / np.linalg.norm(LIGHT)

INK = np.array([0x14, 0x16, 0x1C]) / 255.0
WHITE = np.ones(3)
LEAF_HEX = "3f9a4a"
STEM_HEX = "2f6b55"
GOLD_HEX = "f2c14e"
PAPER_HEX = "f6efd9"

# The six meadow flowers, keyed as in texel_pad.gd FLOWERS.
FLOWER_HEX = {
    "sprout": "e4f1ff", "clover": "6be86b", "thistle": "7f9bff",
    "heather": "c27cff", "foxglove": "ffb62e", "starbloom": "ff7bff",
}

# Mound layout per stage, in world units (x, y). Positions on the screen are x - y and (x + y) / 2 - z.
POS = {
    1: [(0.0, 0.0)],
    2: [(-3.0, 1.0), (0.0, 0.0), (3.0, -1.0)],
    3: [(0.0, 0.0), (3.6, 0.0), (-3.6, 0.0), (0.0, 3.6), (0.0, -3.6)],
    4: [(0.0, 0.0), (3.8, 0.0), (-3.8, 0.0), (0.0, 3.8), (0.0, -3.8), (2.6, -2.6), (-2.6, 2.6)],
    5: [(x, y) for x in (-3.2, 0.0, 3.2) for y in (-3.2, 0.0, 3.2)],
}
HEAD_R = {1: 3.6, 2: 3.0, 3: 2.8, 4: 2.5, 5: 2.4}


def hexc(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], float) / 255.0


def mix(a, b, t):
    return a * (1.0 - t) + b * t


def ramp(c):
    """Five tone steps from shadow to light, built from one colour and ink or paper."""
    return np.stack([mix(c, INK, 0.65), mix(c, INK, 0.3), c, mix(c, WHITE, 0.35), mix(c, WHITE, 0.7)])


# Greyscale tones for the bloom layer. Level 3 and up are full strength, so the stat colour shows at its brightest.
BLOOM_GREY = np.array([0.42, 0.66, 0.86, 1.0, 1.0])
BLOOM_INK = 0.10


# ---------- signed distance primitives, vectorised over points P (N, 3) ----------

def sd_ell(P, p):
    Q = P - p["c"]
    ca, sa = math.cos(p["ang"]), math.sin(p["ang"])
    x = ca * Q[:, 0] + sa * Q[:, 1]
    y = -sa * Q[:, 0] + ca * Q[:, 1]
    z = Q[:, 2]
    rx, ry, rz = p["r"]
    k0 = np.sqrt((x / rx) ** 2 + (y / ry) ** 2 + (z / rz) ** 2)
    k1 = np.sqrt((x / rx ** 2) ** 2 + (y / ry ** 2) ** 2 + (z / rz ** 2) ** 2)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-6)


def sd_cap(P, p):
    a, b = p["a"], p["b"]
    ba = b - a
    pa = P - a
    h = np.clip(pa @ ba / (ba @ ba), 0.0, 1.0)
    return np.linalg.norm(pa - h[:, None] * ba[None, :], axis=1) - p["rad"]


def sd_plate(P):
    m = np.maximum(np.abs(P[:, 0]), np.abs(P[:, 1]))
    z = P[:, 2]
    return np.maximum(m - RS, np.maximum(z, -T - z))


def sd_prim(P, p):
    if p["kind"] == "ell":
        return sd_ell(P, p)
    if p["kind"] == "cap":
        return sd_cap(P, p)
    return sd_plate(P)


def scene(P, prims):
    best = np.full(len(P), 1e9)
    idx = np.zeros(len(P), int)
    for i, p in enumerate(prims):
        d = sd_prim(P, p)
        m = d < best
        best = np.where(m, d, best)
        idx = np.where(m, i, idx)
    return best, idx


class Builder:
    def __init__(self):
        self.prims = []
        self.g = 0

    def group(self):
        self.g += 1
        return self.g

    def ell(self, c, r, mat, g, ang=0.0, dither=True):
        self.prims.append(dict(kind="ell", c=np.array(c, float), r=np.array(r, float), ang=ang, mat=mat, grp=g, dither=dither))

    def cap(self, a, b, rad, mat, g):
        self.prims.append(dict(kind="cap", a=np.array(a, float), b=np.array(b, float), rad=rad, mat=mat, grp=g, dither=True))

    def plate(self):
        self.prims.append(dict(kind="plate", mat="soil", grp=0, dither=False))


def build(stage):
    """Style A, mounds: a leafy cushion with a ring of small blooms and a bloom on top, for each position."""
    b = Builder()
    b.plate()
    hr = HEAD_R[stage]
    mr = 3.6 if stage <= 3 else 3.0
    for (x, y) in POS[stage]:
        g = b.group()
        b.ell((x, y, 0.6), (mr, mr, mr * 0.55), "leaf", g)
        top = 0.6 + mr * 0.55
        gh = b.group()
        b.ell((x, y, top + hr * 0.45), (hr, hr, hr * 0.7), "petal", gh)
        b.ell((x, y, top + hr * 0.45 + hr * 0.6), (0.9, 0.9, 0.9), "heart", gh)
        for k in range(4 if stage >= 3 else 2):
            a = k * math.pi / 2 + 0.4
            b.ell((x + 2.6 * math.cos(a), y + 2.6 * math.sin(a), top + 0.3), (1.0, 1.0, 0.9), "petal", gh)
    if stage >= 5:
        gc = b.group()
        for k in range(6):
            a = k * math.pi / 3
            b.ell((1.7 * math.cos(a), 1.7 * math.sin(a), 6.4), (0.7, 0.7, 0.7), "gold", gc, dither=False)
    return b.prims


def render(prims):
    """Ray-march the scene. Returns per-pixel arrays for the three layers."""
    cc, rr = np.meshgrid(np.arange(W), np.arange(H))
    sx = (cc - COL0) + 0.5
    sy = (rr - ROW0) + 0.5
    Z0 = 40.0
    S = 2.0 * (sy + Z0)
    x0 = (S + sx) / 2.0
    y0 = (S - sx) / 2.0
    O = np.stack([x0.ravel(), y0.ravel(), np.full(W * H, Z0)], axis=1)
    N = len(O)

    hit = np.zeros(N, bool)
    tHit = np.full(N, np.inf)
    pidx = np.full(N, -1)
    for t in np.arange(0.0, 52.0, 0.12):
        ai = np.nonzero(~hit)[0]
        if len(ai) == 0:
            break
        d, idx = scene(O[ai] + t * RAY, prims)
        m = d <= 0.0
        hit[ai[m]] = True
        tHit[ai[m]] = t
        pidx[ai[m]] = idx[m]

    hi = np.nonzero(hit)[0]
    Ph = O[hi] + tHit[hi, None] * RAY
    e = 0.06
    nrm = np.zeros((len(hi), 3))
    for k in range(3):
        dp = np.zeros(3)
        dp[k] = e
        nrm[:, k] = scene(Ph + dp, prims)[0] - scene(Ph - dp, prims)[0]
    nrm /= np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-9)

    Ps = Ph + nrm * 0.35
    shadow = np.zeros(len(hi), bool)
    for s in np.arange(0.35, 30.0, 0.5):
        ok = np.nonzero(~shadow)[0]
        if len(ok) == 0:
            break
        d = scene(Ps[ok] + s * LIGHT, prims)[0]
        shadow[ok[d < 0.0]] = True

    v = 0.25 + 0.75 * np.clip(nrm @ LIGHT, 0.0, 1.0)
    v = np.where(shadow, v * 0.6, v)

    prim_kind = np.array([p["kind"] for p in prims])
    prim_mat = np.array([p["mat"] for p in prims])
    prim_dither = np.array([p["dither"] for p in prims])
    mat = prim_mat[pidx[hi]]
    dith = prim_dither[pidx[hi]]
    is_plate = prim_kind[pidx[hi]] == "plate"
    bloom_hit = np.isin(mat, ["petal", "heart"])
    layer = np.where(is_plate, 2, np.where(bloom_hit, 1, 0))  # 0 leaf, 1 bloom, 2 plate

    lf = np.clip((v - 0.2) / 0.8, 0.0, 0.999) * 4.0
    base = np.floor(lf)
    frac = lf - base
    thr = BAYER[(rr.ravel()[hi] % 4), (cc.ravel()[hi] % 4)]
    lvl = np.clip(base + ((frac > thr) & dith), 0, 4).astype(int)

    # Object-level tone index per pixel, plus the shadow flag, for the layers below.
    lvl_full = np.zeros(N, int)
    lvl_full[hi] = lvl
    layer_full = np.full(N, -1)
    layer_full[hi] = layer
    mat_full = np.full(N, "", dtype=object)
    mat_full[hi] = mat
    shadow_full = np.zeros(N, bool)
    shadow_full[hi] = shadow
    top_face = np.zeros(N, bool)
    top_face[hi] = nrm[:, 2] > 0.5

    # Ink outlines: the nearer pixel on each boundary between two objects, and against empty space.
    G = np.full(N, -1)
    G[hi] = pidx[hi]
    G = G.reshape(H, W)
    Tm = tHit.reshape(H, W)
    outline = np.zeros((H, W), bool)
    for axis in (1, 0):
        n = W - 1 if axis == 1 else H - 1
        A = np.take(G, np.arange(n), axis=axis)
        B = np.take(G, np.arange(1, n + 1), axis=axis)
        ta = np.take(Tm, np.arange(n), axis=axis)
        tb = np.take(Tm, np.arange(1, n + 1), axis=axis)
        diff = A != B
        near_a = ta <= tb
        mark_a = diff & near_a & (A >= 0)
        mark_b = diff & ~near_a & (B >= 0)
        if axis == 1:
            outline[:, :-1] |= mark_a
            outline[:, 1:] |= mark_b
        else:
            outline[:-1, :] |= mark_a
            outline[1:, :] |= mark_b
    outline = outline.ravel()
    outline &= layer_full >= 0
    outline &= layer_full != 2   # the plate draws its own outline in the game
    return dict(lvl=lvl_full, layer=layer_full, mat=mat_full, shadow=shadow_full, top=top_face, outline=outline)


def tone_rgb(mat, lvl):
    """Leaf-layer colour for one pixel: leaves, stems and gold in their own ramps."""
    if mat == "leaf":
        return ramp(hexc(LEAF_HEX))[lvl]
    if mat == "gold":
        return ramp(hexc(GOLD_HEX))[lvl]
    return ramp(hexc(STEM_HEX))[lvl]


def layers_for(r):
    """Build the three RGBA layers from one render. Returns (leaf, bloom, shade) as (H, W, 4) float arrays."""
    leaf = np.zeros((H * W, 4))
    bloom = np.zeros((H * W, 4))
    shade = np.zeros((H * W, 4))
    gray = BLOOM_GREY
    for i in range(H * W):
        L = r["layer"][i]
        if L == 0:
            if r["outline"][i]:
                leaf[i] = [INK[0], INK[1], INK[2], 1.0]
            elif r["mat"][i] != "":
                leaf[i, :3] = tone_rgb(r["mat"][i], r["lvl"][i])
                leaf[i, 3] = 1.0
        elif L == 1:
            if r["outline"][i]:
                bloom[i] = [BLOOM_INK, BLOOM_INK, BLOOM_INK, 1.0]
            else:
                g = gray[r["lvl"][i]]
                bloom[i] = [g, g, g, 1.0]
        elif L == 2 and r["top"][i] and r["shadow"][i]:
            shade[i] = [INK[0], INK[1], INK[2], 0.42]
    return (leaf.reshape(H, W, 4), bloom.reshape(H, W, 4), shade.reshape(H, W, 4))


def to_png(arr, path):
    img = Image.fromarray((np.clip(arr, 0.0, 1.0) * 255).round().astype(np.uint8), "RGBA")
    img.save(path)


def main():
    os.makedirs(OUT, exist_ok=True)
    for stage in range(1, 6):
        r = render(build(stage))
        # The leaf and shade layers are the same for every flower. The bloom layer is greyscale, tinted in the game.
        leaf, bloom, shade = layers_for(r)
        to_png(shade, os.path.join(OUT, "shade_s%d.png" % stage))
        to_png(leaf, os.path.join(OUT, "leaf_s%d.png" % stage))
        for flower in FLOWER_HEX:
            to_png(bloom, os.path.join(OUT, "%s_bloom_s%d.png" % (flower, stage)))
        print("stage", stage, "done")


if __name__ == "__main__":
    main()
