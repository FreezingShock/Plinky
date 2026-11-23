#!/usr/bin/env python3
"""Plinky walker atlas v3: the hooded walker, redrawn with more form and a pose set for the procedural animation.
Run: python3 tools/art/gen_walker.py   (needs Pillow + numpy; reuses the helpers in gen_v2.py)
Writes assets/art/walker/walker_atlas.png (RGBA, 256 wide, 64 px cells) and a preview sheet next to this file.

The old atlas carried its own baked ground shadow. This one has none: the cast shadow is SkyShadows' job, so it can
shrink while the walker is in the air. Colour roles follow docs/art-bible.md (0 ink ... 7 paper), light from upper left.

Cells (row, col):
  0: front, side, back, front blink          1: side walk 1-4
  2: front walk 1-2, back walk 1-2           3: press squash, crouch front, crouch side, slide
  4: jump rise front, jump fall front, jump rise side, jump fall side
"""
import os, sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from gen_v2 import Cv, PAL, CELL, dith, flat, sph, bay  # noqa: E402

REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
CLOAK = [1, 6, 5]             # deep green shadow -> terracotta -> cream-gold highlight
CLOAK_WARM = [1, 6, 5]
SCARF = [1, 2, 3]            # dark so it reads against the meadow grass
BOOT = [0, 1, 6]
SKIN = [5, 7, 7]


def lit(cx, x, t=0.0, base=0.6, slope=0.06):
    return base - (x - cx) * slope - t * 0.3


def walker(c, cx, cy, face='front', phase=0, bob=0, blink=False, crouch=0, arms='down', cape=0, lean=0,
           legs='walk', press=False):
    """cx = centre column, cy = ground row (boot soles end on row cy-1).
    crouch drops the shoulders (0..5); arms 'down' | 'up' | 'out'; cape lifts the hem (jump fall); lean shifts the head."""
    id = c.new()
    stride = [(0, 0), (-1, 1), (0, 0), (1, -1)][phase % 4]
    lift = [(0, 0), (0, 1), (0, 0), (1, 0)][phase % 4]
    cy2 = cy - bob
    side = face == 'side'
    # ---------- boots ----------
    if legs == 'slide':
        c.rect(cx - 6, cy2 - 4, cx - 2, cy2 - 1, flat(BOOT, .9, .1), id)                   # rear knee, tucked
        c.rect(cx - 2, cy2 - 4, cx + 6, cy2 - 2, flat(BOOT, .95, .1), id)                  # front leg stretched out
        c.rect(cx + 6, cy2 - 3, cx + 7, cy2 - 2, 0, id)                                    # toe
    elif legs == 'tuck':
        for k, ox in enumerate((-3, 1)):
            c.rect(cx + ox, cy2 - 3, cx + ox + 2, cy2 - 2, flat(BOOT, .75, .1), id)
    else:
        for k in range(2):
            ox = (-4 + stride[0] if k == 0 else 1 + stride[1]) if not side else (-3 + stride[0] * 2 if k == 0 else 1 - stride[0] * 2)
            lf = lift[k]
            x0 = cx + ox
            c.rect(x0, cy2 - 3 - lf, x0 + 2, cy2 - 1 - lf, lambda x, y: dith(BOOT, .5 + (cx - x) * .03 + (y - cy2) * .05, x, y), id)
            c.rect(x0, cy2 - 1 - lf, x0 + 2 + (1 if side else 0), cy2 - 1 - lf, 0, id)       # sole
    # ---------- cloak ----------
    drop = crouch
    top = cy2 - 13 + drop
    hem = cy2 - 3 - (0 if legs != 'tuck' else 1)
    wt, wb = 3 + (1 if crouch > 2 else 0), 6 + (1 if crouch else 0) + (1 if crouch > 3 else 0)
    lift_c = cape

    def body(x, y):
        t = (y - top) / max(1, hem - top)
        l = lit(cx, x, t)
        if (x - cx + 25) % 5 == 0 and t > .45: l -= .16                    # folds
        if t > .9 and (x + y) % 2 == 0: l -= .14                            # frayed hem
        return dith(CLOAK, l, x, y)
    poly = [(cx - wt, top), (cx + wt + 1, top), (cx + wb + 1, hem), (cx - wb, hem)]
    if side:
        poly = [(cx - 3, top), (cx + 3, top), (cx + 5, hem), (cx - 5 - lift_c, hem - lift_c)]
    c.poly(poly, body, id)
    if lift_c:
        c.poly([(cx - 5 - lift_c, hem - lift_c), (cx - 7 - lift_c * 2, hem - lift_c - 2), (cx - 5, hem - 2)], flat(CLOAK, .4, .1), id)
    # belt + buckle
    by = int(top + (hem - top) * .5)
    if not side:
        c.rect(cx - wt, by, cx + wt + 1, by, 1, id); c.rect(cx, by, cx + 1, by, 4, id)
    else:
        c.rect(cx - 3, by, cx + 3, by, 1, id); c.px(cx + 2, by, 4, id)
    # satchel + strap (identity: kept from v2)
    if face == 'front':
        c.poly([(cx - 3, top), (cx - 1, top), (cx + 5, hem - 2), (cx + 3, hem - 2)], lambda x, y: 1, id)
        c.rect(cx + 4, by + 1, cx + 7, by + 4, flat([1, 6, 5], .5, .3), id); c.px(cx + 5, by + 1, 5, id)
    elif side:
        c.rect(cx - 8, by - 1, cx - 4, by + 3, flat([1, 6, 5], .55, .3), id); c.rect(cx - 8, by - 1, cx - 4, by - 1, 1, id)
    else:
        c.rect(cx - 3, by - 5, cx + 3, by - 1, flat([1, 6, 5], .55, .3), id); c.rect(cx - 3, by - 5, cx + 3, by - 5, 1, id)
    # ---------- arms ----------
    for sx in (-1, 1):
        if side and sx == 1:
            continue
        ax = cx + sx * (wt + 2) if not side else cx - 1 + stride[0]
        ay = top + 1
        if arms == 'up':
            c.poly([(ax - 1, ay + 1), (ax + 1, ay + 1), (ax + sx * 3 + 1, ay - 5), (ax + sx * 3 - 1, ay - 5)], flat(CLOAK, .5, .2), id)
            c.px(ax + sx * 3, ay - 6, 7, id)
        elif arms == 'out':
            c.rect(min(ax, ax + sx * 4), ay + 1, max(ax, ax + sx * 4), ay + 2, flat(CLOAK, .5, .2), id)
            c.px(ax + sx * 5, ay + 2, 7, id)
        else:
            sw = stride[0] * (1 if sx < 0 else -1) if not side else stride[0]
            ln = 4 if not drop else 3
            c.rect(ax - 1, ay, ax, ay + ln + sw, flat(CLOAK, .45, .2), id)
            c.px(ax - (1 if sx < 0 else 0), ay + ln + 1 + sw, 7, id)
    # ---------- scarf ----------
    sy = top - 1
    c.rect(cx - 4, sy, cx + 5, sy + 1, lambda x, y: dith(SCARF, .42 + (y - sy) * -.15 + (cx - x) * .03, x, y), id)
    if side:
        w = (phase % 2)
        c.poly([(cx - 4, sy + 1), (cx - 9, sy + 2 - w), (cx - 12, sy + 6 - w * 2), (cx - 9, sy + 7), (cx - 4, sy + 4)], flat(SCARF, .45, .15), id)
    elif face == 'front':
        c.rect(cx + 2, sy + 2, cx + 4, sy + 6, flat(SCARF, .38, .2), id); c.px(cx + 3, sy + 7, 3, id)
    else:
        c.rect(cx - 3, sy + 2, cx - 1, sy + 7, flat(SCARF, .38, .2), id)
    # ---------- hood ----------
    hy = sy - 5 + lean * 0
    hx = cx + lean
    hood = sph(hx - 1, hy - 2, 7, 6.4, CLOAK_WARM, .02, 0.0)
    c.ell(hx + (1 if side else 0), hy, 6.4, 6, hood, id)
    if side:
        c.poly([(hx - 5, hy - 2), (hx - 10, hy - 6 + (phase % 2)), (hx - 4, hy - 5)], flat(CLOAK, .4, .2), id)   # hood tail
        c.poly([(hx + 1, hy - 5), (hx + 5, hy - 10), (hx + 5, hy - 4)], flat(CLOAK, .6, .1), id)              # peak
    else:
        c.poly([(hx - 1, hy - 5), (hx + 2, hy - 10), (hx + 4, hy - 5)], flat(CLOAK, .62, .1), id)             # peak
    # ---------- face (a glimpse under the hood) ----------
    if face == 'front':
        c.ell(hx, hy + 1, 4.2, 3.6, lambda x, y: dith([1, 6, 5], .12 + (y - hy) * .03, x, y), id)         # hood shadow
        c.ell(hx, hy + 1.6, 3.4, 2.8, lambda x, y: dith(SKIN, .85 - (y - hy) * .06 - (x - hx) * .04, x, y), id)
        ey = hy + 1
        if blink:
            c.rect(hx - 2, ey, hx - 1, ey, 0, id); c.rect(hx + 1, ey, hx + 2, ey, 0, id)
        else:
            c.rect(hx - 2, ey - 1, hx - 2, ey, 0, id); c.rect(hx + 2, ey - 1, hx + 2, ey, 0, id)
        c.px(hx - 3, ey + 1, 6, id); c.px(hx + 3, ey + 1, 6, id)                                          # cheeks
        if press: c.rect(hx - 1, ey + 2, hx + 1, ey + 2, 0, id)
    elif side:
        fx = hx + 3
        c.ell(fx - 1, hy, 4.2, 3.8, lambda x, y: dith([1, 6, 5], .12, x, y), id)
        c.ell(fx, hy + 1, 2.8, 3.1, lambda x, y: dith(SKIN, .9 - (x - fx) * .05, x, y), id)
        ey = hy + 1
        if blink: c.rect(fx, ey, fx + 1, ey, 0, id)
        else: c.rect(fx + 1, ey - 1, fx + 1, ey, 0, id)
        c.px(fx + 2, ey + 2, 6, id)
    else:   # back: seam and tassel
        for yy in range(hy - 4, hy + 5):
            if c.o[yy, hx] == id: c.px(hx, yy, 1 if yy % 2 else 0, id)
        c.px(hx, hy + 5, 4, id)


def build():
    c0 = lambda f: f
    cells = []
    W = lambda **k: (lambda c, x, y: walker(c, x, y, **k))
    cells += [W(face='front'), W(face='side'), W(face='back'), W(face='front', blink=True, bob=1)]
    cells += [W(face='side', phase=p, bob=1 if p % 2 else 0) for p in range(4)]
    cells += [W(face='front', phase=1, bob=1), W(face='front', phase=3, bob=1), W(face='back', phase=1, bob=1), W(face='back', phase=3, bob=1)]
    cells += [W(face='front', crouch=1, press=True), W(face='front', crouch=4), W(face='side', crouch=4),
              W(face='side', crouch=6, legs='slide', arms='out', lean=-1)]
    cells += [W(face='front', arms='up', legs='tuck', bob=1), W(face='front', arms='out', cape=1, legs='tuck'),
              W(face='side', arms='up', legs='tuck', bob=1), W(face='side', arms='out', cape=2, legs='tuck')]
    cols, rows = 4, 5
    atlas = Image.new('RGBA', (cols * CELL, rows * CELL), (0, 0, 0, 0))
    pal = [tuple(int(h[k:k + 2], 16) for k in (1, 3, 5)) for h in PAL['meadow']]
    for n, fn in enumerate(cells):
        c = Cv(CELL, CELL)
        fn(c, CELL // 2, CELL - 18)
        c.outline()
        arr = np.zeros((CELL, CELL, 4), np.uint8)
        for y in range(CELL):
            for x in range(CELL):
                if c.i[y, x] >= 0:
                    arr[y, x] = (*pal[c.i[y, x]], 255)
        atlas.paste(Image.fromarray(arr, 'RGBA'), ((n % cols) * CELL, (n // cols) * CELL))
    out = os.path.join(REPO, 'assets', 'art', 'walker', 'walker_atlas.png')
    atlas.save(out)
    bg = Image.new('RGBA', atlas.size, (*pal[3], 255))
    bg.alpha_composite(atlas)
    bg.resize((atlas.width * 4, atlas.height * 4), Image.NEAREST).convert('RGB').save(os.path.join(HERE, 'walker-sheet-v3.png'))
    print('wrote', out)


if __name__ == '__main__':
    build()
