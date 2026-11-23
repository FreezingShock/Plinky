#!/usr/bin/env python3
"""Ember Quarry ladder art, v3: front-facing detailed 2D sprites (Nathan: "more detailed 2D, facing the screen", not
isometric voxels). One object per tier, viewed straight on and lit from the top left, built with tools/art/qs.py:
faceted rock, crystals, a crucible, stacked bars, an anvil and a heart gem, each with its tier colour ramp (tier
colour follows rarity) and a hot glow ramp that flickers over 3 frames. Output per tier, same names as before:
  <tier>_hero.png + _hero_f0..2   2x the pad sprite
  <tier>_game.png + _game_f0..2   the pad sprite (about 34 px wide)
  <tier>_32.png <tier>_16.png <tier>_8.png   UI icons fitted from the game sprite
Usage: python3 tools/art/gen_quarry_ladder.py [outdir]"""
import math, os, sys
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from qs import Spr, rgb, h2

TIERS = {
 "cinder": dict(body=["1a1416","332a2c","54484a","7e7070","b8a89c"], sec=["14100f","2a2220","443836","665655","8e7c74"], glow=["8a2a1e","d0602f","e9a845","f8e0a0"]),
 "ore": dict(body=["0e2218","1d4630","2f7a4a","5fb26a","b8f0a0"], sec=["0a1810","15301f","224f35","357a50","58a870"], glow=["8a4a1e","c8793a","f0b060","fff0c0"]),
 "slag": dict(body=["0c1428","1a3260","2c5fa0","58a8e0","c0eeff"], sec=["080e1c","121e3c","1e3a6a","305a98","4a82c0"], glow=["a0301c","f0602a","ffb040","fff0b0"]),
 "ingot": dict(body=["1a0e2e","3a2866","6a4ca8","a07ee0","e6d2ff"], sec=["120a22","271a48","44307a","6a52ac","9a86d0"], glow=["6a2a8a","b060e0","f0a0ff","ffffff"]),
 "alloy": dict(body=["2a1808","68420e","b07a1c","e8b43a","fff0a0"], sec=["1a1008","3a3438","68646c","9c98a4","d0ccd8"], glow=["c04010","f08020","ffd060","ffffff"]),
 "ember": dict(body=["2a0618","701040","c02070","ff5aa0","ffd0e8"], sec=["1a0410","3e0a28","7a1a50","b02e78","d85aa0"], glow=["c01848","ff4060","ffa0b0","fffff0"]),
}
W, H = 38, 40


def ramps(s, t):
    T = TIERS[t]
    return s.ramp([rgb(c) for c in T["body"]]), s.ramp([rgb(c) for c in T["sec"]]), s.ramp([rgb(c) for c in T["glow"]])


def sparks(s, g, pts, frame):
    for i, (x, y) in enumerate(pts):
        yy = y - ((frame + i) % 3)
        if 0 <= yy < s.h and 0 <= x < s.w:
            s.R[yy, x] = g; s.V[yy, x] = 0.95 if (frame + i) % 2 else 0.6; s.O[yy, x] = 99; s.G[yy, x] = False


def cinder(frame):
    s = Spr(W, H, 11); b, c, g = ramps(s, "cinder")
    s.poly([(3, 38), (2, 30), (6, 24), (12, 22), (16, 27), (17, 38)], c, 0.55, 0.2)          # back left lump
    s.rock(12, 36, 11, 14, b, 3, 7, glow_ramp=g, crack_p=0.30)                              # main heap, left
    s.rock(26, 36, 10, 12, c, 5, 6, glow_ramp=g, crack_p=0.34)                              # right heap
    s.rock(19, 28, 8, 12, b, 9, 6, glow_ramp=g, crack_p=0.42, bright=0.06)                  # top chunk
    s.rock(7, 38, 4, 5, c, 2, 3); s.rock(33, 38, 3, 4, b, 6, 3)                              # pebbles
    # an ember bed glowing between the lumps
    m = s.ell_mask(19, 36.5, 7, 2.2) & (s.R >= 0)
    s.paint(m, g, 0.45 + 0.45 * np.where((s.xx + frame) % 3 == 0, 1, 0.3), glow=True, obj=False)
    sparks(s, g, [(15, 18), (22, 14), (18, 9), (26, 20)], frame)
    return s.finish(frame)


def ore(frame):
    s = Spr(W, H, 21); b, c, g = ramps(s, "ore")
    s.rock(17, 38, 15, 15, c, 4, 8)                                        # dark host rock
    s.rock(28, 38, 8, 8, c, 8, 5)
    for (x, y, w, h, lean, tip) in ((9, 29, 6, 17, -2, 1), (17, 27, 8, 24, 1, 2), (24, 30, 6, 15, 3, 1), (13, 33, 4, 9, -1, 0), (29, 33, 4, 8, 2, 0)):
        s.crystal(x, y, w, h, b, lean, tip, seed=x, gl=False)
    # gold flecks in the host rock and a lit seam
    for (x, y) in ((6, 35), (12, 36), (21, 36), (30, 36), (8, 32), (26, 34)):
        if s.R[y, x] >= 0:
            s.R[y, x] = g; s.V[y, x] = 0.7 + 0.3 * ((frame + x) % 2); s.G[y, x] = True
    s.paint(s.poly_mask([(15, 29), (17, 14), (18, 14), (18, 29)]) & (s.R == b), g, 0.5, glow=True, obj=False)
    sparks(s, g, [(17, 10), (20, 7)], frame)
    return s.finish(frame)


def slag(frame):
    s = Spr(W, H, 31); b, c, g = ramps(s, "slag")
    s.poly([(7, 38), (5, 31), (9, 18), (29, 18), (33, 31), (31, 38)], b, 0.7, 0.18)          # crucible body
    s.poly([(4, 18), (4, 14), (34, 14), (34, 18)], c, 0.75, 0.35)                           # lip
    s.poly([(5, 40), (5, 36), (11, 36), (11, 40)], c, 0.5, 0.2)                              # feet
    s.poly([(27, 40), (27, 36), (33, 36), (33, 40)], c, 0.5, 0.2)
    for y in (22, 29):                                                                       # riveted bands
        s.paint(s.poly_mask([(6, y), (32, y), (32, y + 2), (6, y + 2)]) & (s.R >= 0), c, 0.28, obj=False)
        for x in range(8, 31, 4):
            s.R[y + 1, x] = b; s.V[y + 1, x] = 0.95
    # molten slag over the lip, drips down the front
    s.paint(s.poly_mask([(6, 13), (32, 13), (30, 11), (8, 11)]), g, 0.7, glow=True)
    for (x, ln) in ((10, 8), (17, 14), (23, 6), (28, 10)):
        s.paint(s.poly_mask([(x, 14), (x + 2, 14), (x + 2, 14 + ln), (x + 1, 15 + ln), (x, 14 + ln - 1)]), g, 0.5 + 0.1 * (x % 3), glow=True, obj=False)
    sparks(s, g, [(12, 8), (19, 5), (26, 8)], frame)
    # blue flame licking up behind the lip
    for i, x in enumerate((11, 15, 19, 23, 27)):
        hh = 3 + ((frame + i) % 3) + (i % 2) * 2
        s.paint(s.poly_mask([(x - 1, 11), (x + 1, 11), (x, 11 - hh)]) & (s.R < 0), b, 0.9 - 0.1 * (i % 2), obj=False)
    return s.finish(frame)


def ingot(frame):
    s = Spr(W, H, 41); b, c, g = ramps(s, "ingot")

    def bar(x0, y0, w, h, ramp=b, hot=False):
        ins = 3
        s.poly([(x0, y0 + h), (x0 + ins, y0), (x0 + w - ins, y0), (x0 + w, y0 + h)], ramp, 0.62, 0.18)
        s.paint(s.poly_mask([(x0 + ins + 1, y0 + 1), (x0 + w - ins - 1, y0 + 1), (x0 + w - ins - 1, y0 + 2), (x0 + ins + 1, y0 + 2)]) & (s.R >= 0), ramp, 0.95, obj=False)
        if hot:
            s.paint(s.poly_mask([(x0 + ins + 1, y0 + 1), (x0 + w - ins - 1, y0 + 1), (x0 + w - ins - 1, y0 + 3), (x0 + ins + 1, y0 + 3)]), g, 0.8, glow=True, obj=False)
    bar(1, 31, 17, 8); bar(20, 31, 17, 8)
    bar(8, 24, 22, 8, c)
    bar(2, 17, 16, 8, c) if False else None
    bar(11, 17, 16, 8, b)
    bar(13, 10, 13, 8, b, hot=True)
    for (x, y) in ((8, 35), (28, 35), (19, 28), (19, 21)):                                    # stamped marks
        s.paint(s.poly_mask([(x, y), (x + 2, y), (x + 2, y + 2), (x, y + 2)]) & (s.R >= 0), c, 0.15, obj=False)
    sparks(s, g, [(17, 6), (21, 4), (14, 7)], frame)
    return s.finish(frame)


def alloy(frame):
    s = Spr(W, H, 51); b, c, g = ramps(s, "alloy")
    s.poly([(7, 39), (9, 33), (29, 33), (31, 39)], c, 0.55, 0.15)                              # base
    s.poly([(12, 33), (14, 25), (24, 25), (26, 33)], c, 0.5, 0.2)                              # waist
    s.poly([(2, 24), (5, 17), (36, 17), (36, 20), (30, 25), (6, 25)], c, 0.9, 0.35)           # face and horn
    s.poly([(2, 24), (6, 22), (6, 25)], c, 0.4)                                                 # horn underside
    s.paint(s.poly_mask([(8, 17), (30, 17), (30, 18), (8, 18)]) & (s.R >= 0), c, 1.0, obj=False)  # polished face
    s.poly([(10, 17), (11, 13), (27, 13), (28, 17)], b, 0.85, 0.35)                            # the alloy bar on the face
    s.paint(s.poly_mask([(11, 13), (27, 13), (27, 15), (11, 15)]), g, 0.75, glow=True, obj=False)
    s.paint(s.poly_mask([(15, 14), (23, 14), (23, 14.9), (15, 14.9)]), g, 1.0, glow=True, obj=False)
    sparks(s, g, [(12, 10), (19, 7), (25, 9), (31, 12), (7, 12)], frame)
    return s.finish(frame)


def ember(frame):
    s = Spr(W, H, 61); b, c, g = ramps(s, "ember")
    # iron cradle: three prongs and a ring
    s.poly([(6, 39), (9, 29), (11, 29), (9, 39)], c, 0.4, 0.08)
    s.poly([(32, 39), (29, 29), (27, 29), (29, 39)], c, 0.4, 0.08)
    s.poly([(17, 39), (18, 31), (21, 31), (22, 39)], c, 0.35, 0.08)
    s.poly([(7, 31), (8, 28), (30, 28), (31, 31)], c, 0.62, 0.2)
    # heart gem, faceted
    cx, cy = 19.0, 15.5
    pts = []
    for i in range(48):
        t = i / 48 * math.tau
        x = 16 * math.sin(t) ** 3; y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((cx + x * 0.58, cy - y * 0.64))
    m = s.poly_mask(pts)
    rng = np.random.default_rng(7)
    cs = np.array([[cx + (rng.random() * 2 - 1) * 9, cy + (rng.random() * 2 - 1) * 8] for _ in range(9)])
    d = (s.xx[..., None] + .5 - cs[:, 0]) ** 2 + (s.yy[..., None] + .5 - cs[:, 1]) ** 2
    fid = np.argmin(d, -1)
    tone = np.array([float(np.clip(0.5 + 0.45 * ((cs[k, 0] - cx) * -0.06 + (cs[k, 1] - cy) * -0.05) + (rng.random() - .5) * .2, 0, 1)) for k in range(9)])
    s.paint(m, b, tone[fid] * 0.85 + 0.1)
    core = ((s.xx + .5 - cx) ** 2 + ((s.yy + .5 - cy) * 1.2) ** 2 < 14 + 3 * ((frame % 3) - 1)) & m
    s.paint(core, g, 0.55 + 0.1 * frame, glow=True, obj=False)
    s.paint(((s.xx + .5 - cx) ** 2 + ((s.yy + .5 - cy) * 1.2) ** 2 < 4.5) & m, g, 1.0, glow=True, obj=False)
    sparks(s, g, [(6, 12), (32, 10), (19, 3), (10, 5), (28, 5)], frame)
    return s.finish(frame)


MODELS = {"cinder": cinder, "ore": ore, "slag": slag, "ingot": ingot, "alloy": alloy, "ember": ember}


def fit(im, size):
    w, h_ = im.size; sc = min((size - 2) / w, (size - 2) / h_)
    nw, nh = max(1, round(w * sc)), max(1, round(h_ * sc))
    r = im.resize((nw, nh), Image.NEAREST)
    c = Image.new("RGBA", (size, size), (0, 0, 0, 0)); c.paste(r, ((size - nw) // 2, size - nh - 1), r); return c


def main(out):
    os.makedirs(out, exist_ok=True)
    # the pad draws every frame bottom-centre, so all three frames of a tier share one crop box
    rows = []
    for n, fn in MODELS.items():
        fr = [fn(f) for f in range(3)]
        box = fr[0].getbbox()
        for f in fr[1:]:
            bb = f.getbbox(); box = (min(box[0], bb[0]), min(box[1], bb[1]), max(box[2], bb[2]), max(box[3], bb[3]))
        game = [f.crop(box) for f in fr]
        hero = [g.resize((g.width * 2, g.height * 2), Image.NEAREST) for g in game]
        for f in range(3):
            game[f].save(f"{out}/{n}_game_f{f}.png"); hero[f].save(f"{out}/{n}_hero_f{f}.png")
        game[0].save(f"{out}/{n}_game.png"); hero[0].save(f"{out}/{n}_hero.png")
        for sz in (32, 16, 8):
            fit(game[0], sz).save(f"{out}/{n}_{sz}.png")
        rows.append((n, game))
    pv = Image.new("RGB", (len(rows) * 120, 250), (26, 17, 22))
    for i, (n, game) in enumerate(rows):
        x0 = i * 120 + 6
        for f in range(3):
            pv.paste(game[f], (x0 + f * 38, 6), game[f])
        big = game[0].resize((game[0].width * 3, game[0].height * 3), Image.NEAREST); pv.paste(big, (x0, 60), big)
        for j, sz in enumerate((32, 16, 8)):
            ic = Image.open(f"{out}/{n}_{sz}.png"); pv.paste(ic, (x0 + (0, 36, 56)[j], 200), ic)
    pv.save(f"{out}/ladder_preview.png")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "assets/art/zone2/ladder")
