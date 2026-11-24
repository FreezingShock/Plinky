"""Larkmoor farm district: sprites for the Thistle Rise farm (world/farm/).

Writes assets/art/zone1b/farm/ (PNG sprites, wheat field frame sheets, farm_preview.png). Pixel scale is Larkmoor's
(the windmill is about 65 texels wide), so these are about twice the meadow's cozy props. Everything is drawn in the
meadow palette roles from gen_cozy.py, so the post-process palette and dither treat them like the rest of the meadow.

Wheat fields are one sheet each: 8 gust frames, like gen_cozy's wheat, as a thick mass of rows with mixed stalk
heights, rounded sides, and a per-field seed so no two fields look stamped. The fields are wheat only: no plots.

Run: python3 tools/art/gen_farm.py   (needs Pillow; the layout is in place_farm.py).
"""
import math
import os
import random
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from gen_cozy import Canvas, INK, SHADE, DEEP, BASE, LIGHT, ACCENT, EARTH, PAPER  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'art', 'zone1b', 'farm')

WHEAT_FRAMES = 8
# name, frame width, seed. Wider fields are bigger patches; every field shares the height and the 8-frame wave.
FIELD_SPECS = [('field_a', 96, 11), ('field_b', 96, 23), ('field_c', 128, 37), ('field_d', 160, 51)]
FIELD_H = 44                    # the row sheets are taller than the old strip: rows stack back to front


def barn() -> Canvas:
    """A gabled barn, 72x56: red-brown walls, plank lines, a loft window, a double door."""
    c = Canvas(72, 56)
    c.rect(6, 24, 65, 52, EARTH)                      # walls
    for x in range(8, 65, 5):                         # plank lines
        c.seg(x, 25, x, 52, SHADE)
    for y in range(4, 25):                            # gable roof: a filled triangle
        half = (y - 4) * (33.0 / 20.0)
        c.rect(round(36 - half), y, round(36 + half), y, DEEP)
    c.rect(4, 24, 67, 25, DEEP)                       # eave line
    c.rect(27, 33, 45, 52, INK)                       # door
    c.seg(36, 33, 36, 52, SHADE)                      # door split
    c.rect(31, 14, 41, 20, PAPER)                     # loft window
    c.seg(36, 14, 36, 20, INK)
    c.seg(31, 17, 41, 17, INK)
    c.rect(29, 52, 43, 53, LIGHT)                     # threshold of straw
    c.outline(INK)
    return c


def shed() -> Canvas:
    """A lean-to tool shed, 40x34."""
    c = Canvas(40, 34)
    c.rect(4, 12, 35, 31, EARTH)
    for x in range(6, 35, 5):
        c.seg(x, 13, x, 31, SHADE)
    for y in range(4, 13):                            # sloping roof
        span = 1 + (y - 4) * 1.6
        c.rect(max(0, round(20 - span)), y, min(39, round(20 + span)), y, BASE)
    c.rect(2, 11, 37, 12, BASE)
    c.rect(14, 18, 25, 31, INK)                       # doorway
    c.rect(8, 16, 11, 19, PAPER)                      # small window
    c.outline(INK)
    return c


def hay_bale(variant: int) -> Canvas:
    """A round bale on its side, 16x12. variant 1 has a second bale behind it at the top, so stacks read as stacks."""
    c = Canvas(16, 12)
    c.ellipse(8, 6, 7.4, 5.2, ACCENT)
    for y in range(2, 11):                            # straw ridges across the bale
        if y % 2 == 0:
            c.seg(2, y, 14, y, LIGHT)
    c.ellipse(8, 6, 3.2, 2.2, EARTH)                  # the cut face
    c.seg(6, 4, 10, 8, SHADE)
    if variant == 1:
        c.ellipse(9, 1.5, 4.5, 2.6, ACCENT)
        c.seg(6, 0, 12, 0, LIGHT)
    c.outline(INK)
    return c


def scarecrow() -> Canvas:
    """A scarecrow, 18x34: pole, arms, a striped shirt, a sack head with a hat."""
    c = Canvas(18, 34)
    c.rect(8, 10, 9, 33, EARTH)                       # pole
    c.rect(2, 13, 15, 14, EARTH)                      # arms
    c.rect(5, 14, 12, 23, ACCENT)                     # shirt
    for y in range(15, 23, 2):
        c.seg(5, y, 12, y, SHADE)
    c.rect(6, 24, 7, 31, DEEP)                        # legs
    c.rect(10, 24, 11, 31, DEEP)
    c.rect(6, 8, 11, 12, PAPER)                       # sack head
    c.set(7, 10, INK)
    c.set(10, 10, INK)
    c.rect(5, 4, 12, 7, DEEP)                         # hat crown
    c.rect(3, 7, 14, 8, DEEP)                         # hat brim
    c.outline(INK)
    return c


def cart() -> Canvas:
    """A two-wheeled hay cart, 28x20, with a load of hay and a shaft."""
    c = Canvas(28, 20)
    c.rect(4, 8, 23, 12, EARTH)                       # bed
    for x in range(6, 23, 4):
        c.seg(x, 8, x, 12, SHADE)
    c.rect(6, 4, 21, 7, ACCENT)                       # hay load
    for x in range(7, 21, 3):
        c.set(x, 5, LIGHT)
    c.seg(23, 10, 27, 11, EARTH)                      # shaft
    c.ellipse(8, 15, 4.2, 4.2, INK)                   # wheels
    c.ellipse(20, 15, 4.2, 4.2, INK)
    c.ellipse(8, 15, 1.8, 1.8, SHADE)
    c.ellipse(20, 15, 1.8, 1.8, SHADE)
    c.outline(INK)
    return c


def crates() -> Canvas:
    """Two crates, one stacked on the other, 12x12."""
    c = Canvas(12, 12)
    c.rect(0, 5, 6, 11, EARTH)
    c.seg(0, 8, 6, 8, SHADE)
    c.rect(6, 6, 11, 11, EARTH)
    c.seg(6, 9, 11, 9, SHADE)
    c.rect(2, 0, 7, 4, EARTH)                         # top crate
    c.seg(2, 2, 7, 2, SHADE)
    c.outline(INK)
    return c


def grounded(c: Canvas, lift: int = 2) -> Canvas:
    """Lifts an object by `lift` texels and draws a flat contact shadow on the bottom rows, so it sits on the ground.
    The shadow is a dark ellipse hugging the footprint, not a drop shadow with a dither."""
    if not c.px:
        return c
    xs = [x for (x, _) in c.px]
    ys = [y for (_, y) in c.px]
    x0, x1, y1 = min(xs), max(xs), max(ys)
    out = Canvas(c.w, c.h)
    for (x, y), col in c.px.items():
        ny = y - lift
        if 0 <= ny < c.h:
            out.px[(x, ny)] = col
    cx = (x0 + x1) / 2.0
    rx = max(3.0, (x1 - x0) / 2.0 * 0.95)
    for y in range(c.h - lift, c.h):
        for x in range(c.w):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - (c.h - 1)) / (lift * 0.9 + 0.5)) ** 2 <= 1.0:
                if (x, y) not in out.px:
                    out.px[(x, y)] = SHADE
    return out


def field_frame(frame: int, seed: int, fw: int, rows: int = 5, fh: int = 44) -> Canvas:
    """One gust frame of a wheat field: a thick, full mass of wheat from the far edge to the near edge. Each row is a
    dark under-mass that the stalks grow out of, so there are no bare soil lines or water between the rows. Rows overlap
    so the field reads as one volume. Heads sit at varying heights, and the stalks bend with the gust: the near rows bend
    more than the far ones. The silhouette is rounded at the sides, not ruled."""
    rng = random.Random(seed)
    c = Canvas(fw, fh)
    phase = 2.0 * math.pi * frame / WHEAT_FRAMES
    cx = fw / 2.0
    base_ys = [14.0 + i * 6.0 for i in range(rows)]        # rows overlap: the far row's heads show above the near one
    for i, by in enumerate(base_ys):
        depth = i / max(1, rows - 1)                       # 0 far, 1 near
        half = fw * (0.40 + 0.11 * depth)
        by_i = int(round(by))
        # the under-mass: a dark, dithered band the stalks grow out of, so the row has thickness
        for x in range(int(cx - half), int(cx + half) + 1):
            edge = abs(x - cx) / half
            if edge > 0.9 and rng.random() < (edge - 0.9) * 6.0:
                continue
            for dy in range(0, 4):
                col = SHADE if (dy == 0 or (x + dy) % 2 == 0) else EARTH
                c.set(x, by_i - dy, col)
        bend_amp = 1.0 + 1.8 * depth
        for x in range(int(cx - half) + 1, int(cx + half) - 1):
            edge = abs(x - cx) / half
            if edge > 0.92 and rng.random() < (edge - 0.92) * 5.0:
                continue
            taper = 1.0 - 0.35 * edge ** 2                  # a rounded silhouette: shorter stalks towards the sides
            h = (7.0 + 5.0 * rng.random()) * (0.85 + 0.3 * depth) * taper
            bend = bend_amp * math.sin(x * 0.35 - phase + i * 0.7)
            tx, ty = x + bend, by_i - 3 - h
            c.seg(x, by_i - 3, tx, ty, ACCENT)             # golden straw
            c.seg(x, by_i - 3, x + bend * 0.5, by_i - 3 - h * 0.5, EARTH)   # darker lower stalk: depth
            c.set(round(tx), round(ty), EARTH)             # the head
            if rng.random() < 0.35:                        # a second, lighter head beside it: a fuller canopy
                c.set(round(tx) + 1, round(ty) + 1, ACCENT)
    return c


def field_sheet(seed: int, fw: int) -> Image.Image:
    sheet = Image.new('RGBA', (fw * WHEAT_FRAMES, 44), (0, 0, 0, 0))
    for f in range(WHEAT_FRAMES):
        sheet.paste(field_frame(f, seed, fw).image(), (f * fw, 0))
    return sheet


PROPS = [
    ('farm_barn', lambda: grounded(barn())),
    ('farm_shed', lambda: grounded(shed())),
    ('farm_hay_0', lambda: grounded(hay_bale(0))),
    ('farm_hay_1', lambda: grounded(hay_bale(1))),
    ('farm_scarecrow', lambda: grounded(scarecrow())),
    ('farm_cart', lambda: grounded(cart())),
    ('farm_crates', lambda: grounded(crates())),
]


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    for name, make in PROPS:
        make().image().save(os.path.join(OUT, name + '.png'))
        print('wrote', name)
    for name, fw, seed in FIELD_SPECS:
        field_sheet(seed, fw).save(os.path.join(OUT, name + '_sheet.png'))
        print('wrote', name + '_sheet', fw * WHEAT_FRAMES, 'x 44')
    # Preview: every sprite on one strip, scaled up, for a quick look.
    strip = []
    for name, make in PROPS:
        strip.append(make().image())
    W = sum(im.width for im in strip) + 4 * len(strip)
    H = max(im.height for im in strip)
    prev = Image.new('RGBA', (W, H), (246, 239, 217, 255))
    x = 0
    for im in strip:
        prev.alpha_composite(im, (x, H - im.height))
        x += im.width + 4
    prev.resize((W * 3, H * 3), Image.NEAREST).save(os.path.join(OUT, 'farm_preview.png'))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
