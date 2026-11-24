#!/usr/bin/env python3
"""Ember Quarry tier art seen from above, as decor for each terrace (2026-11-24).

The original tier sprites (assets/art/zone2/ladder/<tier>_game.png, front-facing, about 38 px) stay as they are on the
forge pads. This module reperspectives each one: column c stands as high as the sprite's silhouette in that column, the
top takes the sprite's own colour, and the relief runs back DEPTH texels. It is ray-marched from the same elevated 2:1
view the meadow beds use (sx = x - y, sy = 0.5 (x + y) - z), lit from the upper left, with a 1 texel ink outline.

relief_rgba(tier) -> float RGBA array (H, W, 4) in 0..1, 1 texel per canvas pixel, the ground centre at (COL0, ROW0).
relief_sprite(tier) -> (PIL RGBA image cropped to its pixels, foot x, foot y inside it), the form tools/art/qprops.py uses.

Run on its own to write a 4x review sheet: python3 tools/art/qrelief.py [outdir]
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
LADDER = os.path.join(HERE, '..', '..', 'assets', 'art', 'zone2', 'ladder')
TIERS = ['cinder', 'ore', 'slag', 'ingot', 'alloy', 'ember']   # terrace rows 0 to 5, Cinder to Emberheart
DEPTH = 6            # how far the relief runs back, in texels
HEIGHT_SCALE = 0.55  # sprite rows to texels of height
LIGHT = np.array([-0.55, 0.55, 1.0])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
INK = np.array([0x14, 0x16, 0x1C]) / 255.0
GROUND = np.array([0x4A, 0x1F, 0x2A]) / 255.0
W, H = 64, 64
COL0, ROW0 = 32, 40
RAY = np.array([-1.0, -1.0, -1.0])
NX = np.array([1.0, 0.0, 0.0])   # the wall that faces the viewer on the +x side
NY = np.array([0.0, 1.0, 0.0])   # the wall on the +y side
NZ = np.array([0.0, 0.0, 1.0])   # the top
ALT_STAGE = 2                    # the second copy on a terrace draws the tier's stage-2 sprite, a different silhouette
Z0 = 70.0
_cache: dict = {}


def load_relief(tier, stage=None):
    """Heightfield columns and colours from the original sprite (its stage-n variant if one is given)."""
    name = '%s_game.png' % tier if stage is None else '%s_s%d_game_f0.png' % (tier, stage)
    im = np.array(Image.open(os.path.join(LADDER, name)).convert('RGBA')).astype(float) / 255.0
    rows, cols = im.shape[0], im.shape[1]
    alpha = im[..., 3] > 0.5
    top = np.array([np.nonzero(alpha[:, c])[0].min() if alpha[:, c].any() else rows for c in range(cols)])
    base = np.array([np.nonzero(alpha[:, c])[0].max() if alpha[:, c].any() else -1 for c in range(cols)])
    bottom = int(base.max())
    height = np.where(top < rows, (bottom - top + 1) * HEIGHT_SCALE, 0.0)
    colour = np.zeros((cols, 3))
    lum = im[..., :3] @ np.array([0.3, 0.59, 0.11])
    for c in range(cols):
        if top[c] < rows:
            # the body colour: the 60th percentile of the column's lit pixels, skipping the dark ink outline at the top
            ys = np.nonzero(alpha[:, c])[0]
            order = ys[np.argsort(lum[ys, c])]
            colour[c] = im[order[int(len(order) * 0.6)], c, :3]
    return height, colour, cols


def render(height, colour, cols):
    cc, rr = np.meshgrid(np.arange(W), np.arange(H))
    sx = (cc - COL0) + 0.5
    sy = (rr - ROW0) + 0.5
    S = 2.0 * (sy + Z0)
    x0 = (S + sx) / 2.0
    y0 = (S - sx) / 2.0
    O = np.stack([x0.ravel(), y0.ravel(), np.full(W * H, Z0)], axis=1)
    N = len(O)
    # The relief occupies x in [0, cols), y in [0, DEPTH), standing on the ground at z = 0.
    ox, oy = -cols / 2.0, -DEPTH / 2.0

    def field(P):
        x = P[:, 0] - ox
        y = P[:, 1] - oy
        inside = (x >= 0) & (x < cols) & (y >= 0) & (y < DEPTH)
        ci = np.clip(np.floor(x).astype(int), 0, cols - 1)
        h = height[ci]
        # Solid only above the ground plane and below the column top. A ray under z = 0 has passed beneath the
        # relief, so it must not register a hit there (that was the bottom clipping in the first sheet).
        solid = inside & (h > 0) & (P[:, 2] >= 0.0)
        d = np.where(solid, P[:, 2] - h, 1e9)
        return d, ci

    hit = np.zeros(N, bool)
    tHit = np.full(N, np.inf)
    ci_hit = np.full(N, -1)
    for t in np.arange(0.0, Z0 + 1.0, 0.2):
        ai = np.nonzero(~hit)[0]
        if len(ai) == 0:
            break
        d, ci = field(O[ai] + t * RAY)
        m = d <= 0.0
        hit[ai[m]] = True
        tHit[ai[m]] = t
        ci_hit[ai[m]] = ci[m]
    img = np.zeros((H * W, 4))
    hi = np.nonzero(hit)[0]
    if len(hi) == 0:
        return img.reshape(H, W, 4)
    # Which face the ray entered through. Rays move toward -x, -y, -z, so the sample just before the hit is nearer the
    # viewer: if it was past the back of the footprint the face is the +y wall, if it was in the next column over the
    # face is the +x wall, otherwise it is the top.
    Pp = O[hi] + (tHit[hi, None] - 0.2) * RAY
    xr = Pp[:, 0] - ox
    yr = Pp[:, 1] - oy
    ci = ci_hit[hi]
    side_y = yr >= DEPTH
    side_x = (~side_y) & (np.floor(xr).astype(int) != ci)
    normal_shade = np.where(side_y, 0.45 + 0.55 * np.clip(NY @ LIGHT, 0, 1),
                            np.where(side_x, 0.45 + 0.55 * np.clip(NX @ LIGHT, 0, 1), 0.45 + 0.55 * np.clip(NZ @ LIGHT, 0, 1)))
    hmax = max(float(height.max()), 1e-6)
    v = normal_shade * (0.6 + 0.4 * height[ci] / hmax)
    col = colour[ci] * v[:, None]
    img[hi, :3] = np.clip(col, 0, 1)
    img[hi, 3] = 1.0
    img = img.reshape(H, W, 4)
    # Ink silhouette against empty ground.
    a = img[..., 3] > 0
    edge = np.zeros((H, W), bool)
    edge[:, :-1] |= a[:, :-1] != a[:, 1:]
    edge[:, 1:] |= a[:, :-1] != a[:, 1:]
    edge[:-1, :] |= a[:-1, :] != a[1:, :]
    edge[1:, :] |= a[:-1, :] != a[1:, :]
    edge &= a
    img[edge] = [INK[0], INK[1], INK[2], 1.0]
    return img


def relief_rgba(tier, stage=None):
    key = (tier, stage)
    if key not in _cache:
        height, colour, cols = load_relief(tier, stage)
        _cache[key] = render(height, colour, cols)
    return _cache[key]


def relief_sprite(tier, stage=None):
    """Cropped RGBA image and its foot (the ground centre) inside it, as qprops.make returns them."""
    img = relief_rgba(tier, stage)
    a8 = (np.clip(img, 0, 1) * 255).astype(np.uint8)
    pil = Image.fromarray(a8, 'RGBA')
    left, top, right, bottom = pil.getbbox()
    return pil.crop((left, top, right, bottom)), float(COL0 - left), float(ROW0 - top)


def review_sheet(outdir):
    scale = 4
    cw, ch = W * scale, H * scale
    pad, label_w = 10, 26
    out = Image.new('RGB', (label_w + 6 * cw + 7 * pad, ch + 2 * pad + 24), (0x14, 0x16, 0x1C))
    d = ImageDraw.Draw(out)
    for c, tier in enumerate(TIERS):
        img = relief_rgba(tier)
        a = img[..., 3:4]
        rgb = img[..., :3] * a + GROUND[None, None, :] * (1 - a)
        cell = Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), 'RGB').resize((cw, ch), Image.NEAREST)
        out.paste(cell, (label_w + pad + c * (cw + pad), 24 + pad))
        d.text((label_w + pad + c * (cw + pad), 6), tier.capitalize(), fill=(0xF6, 0xEF, 0xD9))
    os.makedirs(outdir, exist_ok=True)
    path = os.path.join(outdir, 'quarry_tiers_above_x4.png')
    out.save(path)
    return path


if __name__ == '__main__':
    print(review_sheet(sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', '..', 'shots')))
