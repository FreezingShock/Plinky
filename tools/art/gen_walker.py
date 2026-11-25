#!/usr/bin/env python3
"""Plinky walker atlas v4: the hooded walker in the elevated, looking-down view (Nathan picked mockup B, 2026-11-24),
with 8 facings: N NE E SE S SW W NW.

Run: python3 tools/art/gen_walker.py   (needs Pillow + numpy; reuses the helpers in gen_v2.py)
Writes assets/art/walker/walker_atlas.png (RGBA, 8 columns x 7 rows of 64 px cells = 512 x 448) and a preview
sheet next to this file.

Five facings are drawn: E (side), SE (three-quarter front), S (front), NE (three-quarter back), N (back).
The other three are mirrors drawn at runtime with a flip, so they are not in the atlas:
SW = SE flipped, W = E flipped, NW = NE flipped. Light stays upper left, as in docs/art-bible.md.

Cell index (row-major, 8 per row). BASE is E, SE, S, NE, N in that order (b = 0..4):
  0..4    idle, one per base facing
  5       blink (front)
  6..25   walk: 6 + b*4 + phase
  26..45  sprint: 26 + b*4 + phase
  46      press (front)      47 press (side)
  48      crouch (front)     49 crouch (side)     50 slide (side)
  51      jump rise front    52 jump fall front   53 jump rise side   54 jump fall side
The GDScript side (world/walker_pose.gd) uses the same numbers. Change both together.
"""
import os, sys
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from gen_v2 import Cv, PAL, CELL, dith  # noqa: E402

REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
CLOAK = [1, 6, 6, 5]        # deep green edge -> terracotta -> cream highlight
HOOD = [1, 6, 6, 5]
SCARF = [1, 2, 3]
BOOT = [1, 2, 6]
SKIN = [5, 7, 7]
BASE = ['E', 'SE', 'S', 'NE', 'N']
FEET_Y = 46                 # ground row (WalkerBody FEET.y - 1)
CX = 32                     # centre column (WalkerBody FEET.x)
COLS, ROWS = 8, 7
ELEVATION = 1.0             # mockup B: full looking-down view
TAIL = 1


def walker(c, face='S', p=0, bob=0, blink=False, crouch=0, arms='swing', cape=0, lean=0,
           sprint=False, press=False, slide=False, air=None):
    """face: 'E' side, 'SE' three-quarter front, 'S' front, 'NE' three-quarter back, 'N' back."""
    cx, cy = CX, FEET_Y - bob
    id = c.new()
    side = face == 'E'
    back = face in ('N', 'NE')
    three = face in ('SE', 'NE')
    sh = 2 if three else 0                  # the three-quarter views shift the body toward the facing
    amp = 2 if sprint else 1
    st = [(0, 0), (-1, 1), (0, 0), (1, -1)][p % 4]
    st = (st[0] * amp, st[1] * amp)
    lf = [(0, 0), (0, 1), (0, 0), (1, 0)][p % 4]

    def bootfn(y0):
        return lambda x, y: dith(BOOT, 0.62 + (cx - x) * 0.03 - (y - y0) * 0.05, x, y)

    # ---------------- legs and boots ----------------
    if slide:
        c.rect(cx - 7, cy - 4, cx - 3, cy - 2, bootfn(cy - 2), id)
        c.rect(cx - 3, cy - 3, cx + 6, cy - 1, bootfn(cy - 1), id)
        c.rect(cx + 6, cy - 2, cx + 7, cy - 1, 0, id)
    elif air:
        for ox in (-3, 1):
            c.rect(cx + ox, cy - 5, cx + ox + 2, cy - 2, bootfn(cy - 2), id)
            c.rect(cx + ox, cy - 1, cx + ox + 2, cy - 1, 0, id)
    else:
        for k in (0, 1):
            if side:
                ox = (-3 + 2 * st[0]) if k == 0 else (1 - 2 * st[0])
            elif three:
                ox = (-3 + st[0]) if k == 0 else (2 + st[1])
            else:
                ox = (-4 + st[0]) if k == 0 else (1 + st[1])
            sole = cy - lf[k]
            x0 = cx + ox
            c.rect(x0, sole - 3, x0 + 2, sole - 1, bootfn(sole - 1), id)
            c.px(x0 + (2 if side else 1), sole - 3, 5, id)          # lit toe cap, seen from above
            c.rect(x0, sole, x0 + 2 + (1 if side else 0), sole, 0, id)

    # ---------------- cloak ----------------
    top = cy - 13 + crouch
    hem = cy - 4 - (1 if air else 0)
    wt = 3 + (1 if crouch > 2 else 0)
    wb = 6 + (1 if crouch else 0) + (1 if crouch > 3 else 0)

    def cloak_fn(x, y):
        t = (y - top) / max(1, hem - top)
        l = 0.66 - (x - cx) * 0.05 - t * 0.22
        if back:
            l -= 0.2
        if (x - cx + 25) % 5 == 0 and t > 0.45:
            l -= 0.16
        if t > 0.9 and (x + y) % 2 == 0:
            l -= 0.14
        return dith(CLOAK, l, x, y)

    if side:
        poly = [(cx - 3, top), (cx + 3, top), (cx + 5, hem), (cx - 5 - cape, hem - cape)]
    else:
        poly = [(cx - wt + sh, top), (cx + wt + 1 + sh, top), (cx + wb + 1 + sh, hem), (cx - wb + sh, hem)]
    c.poly(poly, cloak_fn, id)
    if cape:
        c.poly([(cx - 5 - cape, hem - cape), (cx - 8 - cape * 2, hem - cape - 2), (cx - 5, hem - 2)],
               lambda x, y: dith(CLOAK, 0.35, x, y), id)
    # shoulder top plane: the elevated view shows the shoulders' top as a lit lip
    if not side:
        sid = c.new()
        c.ell(cx + sh, top + 0.4, wt + 1.8, 1.5,
              lambda x, y: dith([6, 5, 7], 0.8 - (x - cx) * 0.07 - (y - top) * 0.1, x, y), sid)
    else:
        sid = c.new()
        c.ell(cx, top + 0.4, 3.6, 1.4, lambda x, y: dith([6, 5, 7], 0.8 - (x - cx) * 0.06, x, y), sid)
    by = int(top + (hem - top) * 0.5)
    if side:
        c.rect(cx - 3, by, cx + 3, by, 1, id)
        c.px(cx + 2, by, 4, id)
    else:
        c.rect(cx - wt + sh, by, cx + wt + 1 + sh, by, 1, id)
        c.rect(cx + sh, by, cx + 1 + sh, by, 4, id)

    # satchel and strap
    if face == 'S' or face == 'SE':
        c.poly([(cx - 3 + sh, top), (cx - 1 + sh, top), (cx + 5 + sh, hem - 2), (cx + 3 + sh, hem - 2)], lambda x, y: 1, id)
        c.rect(cx + 4 + sh, by + 1, cx + 7 + sh, by + 4, lambda x, y: dith([1, 6, 5], 0.55 - (y - by) * 0.05, x, y), id)
        c.rect(cx + 4 + sh, by + 1, cx + 7 + sh, by + 1, 5, id)
    elif side:
        c.rect(cx - 8, by - 1, cx - 4, by + 3, lambda x, y: dith([1, 6, 5], 0.5, x, y), id)
        c.rect(cx - 8, by - 1, cx - 4, by - 1, 5, id)
    else:
        c.rect(cx - 3 + sh, by - 5, cx + 3 + sh, by - 1, lambda x, y: dith([1, 6, 5], 0.48, x, y), id)
        c.rect(cx - 3 + sh, by - 5, cx + 3 + sh, by - 5, 1, id)

    # ---------------- arms ----------------
    if air and not side:
        for sx in (-1, 1):
            ax = cx + sx * (wt + 2) + sh
            if arms == 'up':
                c.poly([(ax - 1, top + 1), (ax + 1, top + 1), (ax + sx * 3 + 1, top - 4), (ax + sx * 3 - 1, top - 4)],
                       lambda x, y: dith(CLOAK, 0.55, x, y), id)
                c.px(ax + sx * 3, top - 5, 7, id)
            else:
                c.rect(min(ax, ax + sx * 4), top + 2, max(ax, ax + sx * 4), top + 3, lambda x, y: dith(CLOAK, 0.5, x, y), id)
                c.px(ax + sx * 5, top + 3, 7, id)
    elif side:
        ax = cx - 1 + st[0] // 2
        sw = st[0]
        c.rect(ax - 1, top + 1, ax, top + 5 + sw, lambda x, y: dith(CLOAK, 0.46 - (y - top) * 0.02, x, y), id)
        c.px(ax - 1, top + 6 + sw, 7, id)
    else:
        for sx in (-1, 1):
            ax = cx + sx * (wt + 2) + sh
            sw = st[0] if sx < 0 else -st[1]          # the arm opposite each leg
            ln = 4 if not crouch else 3
            c.rect(ax - 1, top + 1, ax, top + 1 + ln + sw, lambda x, y: dith(CLOAK, 0.5 - (y - top) * 0.02, x, y), id)
            c.px(ax - (1 if sx < 0 else 0), top + 2 + ln + sw, 7, id)

    # ---------------- scarf ----------------
    sy = top - 1
    c.rect(cx - 4 + sh, sy, cx + 5 + sh, sy + 1, lambda x, y: dith(SCARF, 0.42 - (y - sy) * 0.1 + (cx - x) * 0.03, x, y), id)
    if side:
        flutter = [0, 1, 2, 1][p % 4] * (2 if sprint else TAIL)
        w = (p % 2) if sprint else 0
        c.poly([(cx - 4, sy + 1), (cx - 9 - flutter, sy + 2), (cx - 12 - flutter * 2, sy + 5 - w),
                (cx - 8, sy + 5), (cx - 4, sy + 3)], lambda x, y: dith(SCARF, 0.45, x, y), id)
    elif not back:
        c.rect(cx + 2 + sh, sy + 2, cx + 4 + sh, sy + 6, lambda x, y: dith(SCARF, 0.4, x, y), id)
        c.px(cx + 3 + sh, sy + 7, 3, id)
    else:
        c.rect(cx - 3 + sh, sy + 2, cx - 1 + sh, sy + 7, lambda x, y: dith(SCARF, 0.4, x, y), id)

    # ---------------- hood ----------------
    hy = sy - 5
    hx = cx + lean + sh
    dome_ry = 5.6 + 0.6 * ELEVATION
    hood_id = c.new()
    c.ell(hx + (1 if side else 0), hy, 6.2, dome_ry,
          lambda x, y: dith(HOOD, 0.46 - (y - hy) * 0.07 - (x - hx) * 0.04, x, y), hood_id)
    if side:
        c.poly([(hx - 5, hy - 2), (hx - 10 - (p % 2 if sprint else 0), hy - 6), (hx - 4, hy - 5)],
               lambda x, y: dith(CLOAK, 0.4, x, y), hood_id)
        c.poly([(hx + 1, hy - 5), (hx + 5, hy - 10), (hx + 5, hy - 4)], lambda x, y: 5 if x > hx + 2 else 6, hood_id)
    else:
        c.poly([(hx - 1, hy - 5), (hx + 2, hy - 10), (hx + 4, hy - 5)], lambda x, y: 7 if x < hx + 2 else 5, hood_id)

    # face: a glimpse under the hood, set lower and flatter by the elevated view
    fy = hy + 2.2 + 0.5 * ELEVATION
    if face in ('S', 'SE'):
        fx0 = hx + (1 if three else 0)
        c.ell(fx0, fy - 0.2, 4.4, 3.4, lambda x, y: dith([1, 1, 6], 0.3 + (y - fy) * 0.04, x, y), id)
        c.ell(fx0, fy + 0.3, 3.5, 2.7, lambda x, y: dith(SKIN, 0.9 - (y - fy) * 0.06 - (x - fx0) * 0.04, x, y), id)
        ey = int(round(fy - 0.4))
        if blink:
            c.rect(fx0 - 2, ey, fx0 - 1, ey, 0, id)
            c.rect(fx0 + 1, ey, fx0 + 2, ey, 0, id)
        elif press:
            c.rect(fx0 - 2, ey, fx0 - 1, ey, 0, id)
            c.rect(fx0 + 1, ey, fx0 + 2, ey, 0, id)
            c.rect(fx0 - 1, ey + 2, fx0 + 1, ey + 2, 0, id)
        else:
            c.rect(fx0 - 2, ey - 1, fx0 - 2, ey, 0, id)
            c.rect(fx0 + 2, ey - 1, fx0 + 2, ey, 0, id)
        c.px(fx0 - 3, ey + 1, 6, id)
        c.px(fx0 + 3, ey + 1, 6, id)
    elif side:
        fx = hx + 3
        c.ell(fx - 1, fy, 3.0, 2.8, lambda x, y: dith([1, 6, 5], 0.14, x, y), id)
        c.ell(fx, fy + 0.4, 2.0, 2.1, lambda x, y: dith(SKIN, 0.9 - (x - fx) * 0.05, x, y), id)
        ey = int(round(fy - 0.4))
        if blink:
            c.rect(fx, ey, fx + 1, ey, 0, id)
        else:
            c.rect(fx + 1, ey - 1, fx + 1, ey, 0, id)
        c.px(fx + 1, ey + 2, 6, id)
    else:   # back and back three-quarter: seam and tassel
        seam_x = hx + (1 if three else 0)
        for yy in range(hy - 4, hy + 5):
            if c.o[yy, seam_x] == hood_id:
                c.px(seam_x, yy, 1 if yy % 2 else 0, hood_id)
        c.px(seam_x, hy + 5, 4, id)


def draw_cell(**kw):
    c = Cv(CELL, CELL)
    walker(c, **kw)
    c.outline()
    return c


def build_cells():
    """Returns the 55 cells in atlas order (see the module doc)."""
    cells = []
    W = draw_cell
    cells += [W(face=f) for f in BASE]                                                  # 0..4 idle
    cells += [W(face='S', blink=True, bob=1)]                                           # 5 blink
    for f in BASE:                                                                      # 6..25 walk
        cells += [W(face=f, p=p, bob=1 if p % 2 else 0) for p in range(4)]
    for f in BASE:                                                                      # 26..45 sprint
        cells += [W(face=f, p=p, sprint=True, lean=1 if f == 'E' else 0, bob=1 if p % 2 else 0) for p in range(4)]
    cells += [W(face='S', crouch=2, press=True, arms='out'),                            # 46 press front
              W(face='E', crouch=2, press=True),                                        # 47 press side
              W(face='S', crouch=4),                                                    # 48 crouch front
              W(face='E', crouch=4),                                                    # 49 crouch side
              W(face='E', crouch=6, slide=True, lean=-1),                               # 50 slide
              W(face='S', air='rise', arms='up', bob=1),                                # 51 jump rise front
              W(face='S', air='fall', arms='out', cape=1),                              # 52 jump fall front
              W(face='E', air='rise', arms='up', bob=1),                                # 53 jump rise side
              W(face='E', air='fall', arms='out', cape=2)]                              # 54 jump fall side
    return cells


def build():
    cells = build_cells()
    assert len(cells) == 55, len(cells)
    atlas = Image.new('RGBA', (COLS * CELL, ROWS * CELL), (0, 0, 0, 0))
    pal = [tuple(int(h[k:k + 2], 16) for k in (1, 3, 5)) for h in PAL['meadow']]
    for n, c in enumerate(cells):
        arr = np.zeros((CELL, CELL, 4), np.uint8)
        ys, xs = np.nonzero(c.i >= 0)
        for y, x in zip(ys, xs):
            arr[y, x] = (*pal[c.i[y, x]], 255)
        atlas.paste(Image.fromarray(arr, 'RGBA'), ((n % COLS) * CELL, (n // COLS) * CELL))
    out = os.path.join(REPO, 'assets', 'art', 'walker', 'walker_atlas.png')
    atlas.save(out)
    bg = Image.new('RGBA', atlas.size, (*pal[3], 255))
    bg.alpha_composite(atlas)
    bg.resize((atlas.width * 3, atlas.height * 3), Image.NEAREST).convert('RGB').save(os.path.join(HERE, 'walker-sheet-v4.png'))
    print('wrote', out, atlas.size)


if __name__ == '__main__':
    build()
