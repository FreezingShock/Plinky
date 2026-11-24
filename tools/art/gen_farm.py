"""Larkmoor farm district: sprites for the Thistle Rise farm (world/farm/).

Writes assets/art/zone1b/farm/ (PNG sprites, wheat field frame sheets, farm_preview.png). Pixel scale is Larkmoor's
(the windmill is about 65 texels wide), so these are about twice the meadow's cozy props. Everything is drawn in the
meadow palette roles from gen_cozy.py, so the post-process palette and dither treat them like the rest of the meadow.

Wheat fields are one sheet each: 8 gust frames, like gen_cozy's wheat, but with mixed stalk heights, tapered edges,
and a per-field seed so no two fields look stamped. Tilled plots are static: furrows, and rows that have sprouted
against bare soil, so the growth looks uneven.

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
FIELD_W, FIELD_H = 96, 28       # the default gust frame of a wheat field
# name, frame width, seed. Wider fields are bigger patches; every field shares the height and the 8-frame wave.
FIELD_SPECS = [('field_a', 96, 11), ('field_b', 96, 23), ('field_c', 128, 37), ('field_d', 160, 51)]


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


def wheat_field_frame(frame: int, seed: int, fw: int = FIELD_W) -> Canvas:
    """One gust frame of a wheat field, fw x FIELD_H. Stalk heights vary across the field and taper at the
    edges, so the outline is ragged, not a rectangle. The wave runs across the field as the frame advances."""
    rng = random.Random(seed)
    c = Canvas(fw, FIELD_H)
    phase = 2.0 * math.pi * frame / WHEAT_FRAMES
    base_y = FIELD_H - 3
    # Grass under the stalks, with a ragged top edge so the field blends into the meadow.
    for x in range(fw):
        top = base_y - 1 + (1 if rng.random() < 0.3 else 0)
        c.rect(x, top, x, FIELD_H - 1, DEEP)          # tilled soil under the stalks: a darker patch that reads as a field
    x = 1
    while x < fw - 1:
        taper = min(1.0, x / 10.0, (fw - 1 - x) / 10.0)
        if taper < 0.35 and rng.random() < 0.6:       # thin out the very edge
            x += 2
            continue
        swell = 0.5 + 0.5 * math.sin(x * 0.11 + seed * 0.7)
        h = (9 + 13 * swell + rng.randint(-3, 3)) * (0.55 + 0.45 * taper)
        bend = 2.4 * math.sin(x * 0.42 - phase)
        top_x = x + bend
        top_y = base_y - h
        c.seg(x, base_y, top_x, top_y, ACCENT)   # golden straw stalks
        hx, hy = round(top_x), round(top_y)
        c.set(hx, hy, EARTH)                          # the head, orange-gold
        if h > 12:
            c.set(hx, hy + 1, EARTH)
            c.set(hx - 1, hy + 1, EARTH)
        x += rng.choice([1, 2, 2])
    return c


def wheat_sheet(seed: int, fw: int = FIELD_W) -> Image.Image:
    sheet = Image.new('RGBA', (fw * WHEAT_FRAMES, FIELD_H), (0, 0, 0, 0))
    for f in range(WHEAT_FRAMES):
        sheet.paste(wheat_field_frame(f, seed, fw).image(), (f * fw, 0))
    return sheet


def tilled_plot(seed: int, w: int = 64, h: int = 22) -> Canvas:
    """A tilled plot, irregular outline. Furrows run across it; some rows have sprouted and some are still bare."""
    rng = random.Random(seed)
    c = Canvas(w, h)
    cx, cy, rx, ry = w / 2.0, h / 2.0, w / 2.0 - 1, h / 2.0 - 1
    wobble = [rng.uniform(-0.6, 0.6) for _ in range(24)]
    for y in range(h):
        for x in range(w):
            ang = math.atan2((y + 0.5 - cy), (x + 0.5 - cx))
            k = int((ang + math.pi) / (2 * math.pi) * 24) % 24
            lim = 1.0 + wobble[k] * 0.12
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= lim * lim:
                c.set(x, y, EARTH)
    # Furrows: one continuous line per row, clipped to the soil. A row either sprouts (small shoots above it) or stays
    # bare, so the plot shows uneven growth, not a stamped pattern.
    for y in range(3, h - 2, 4):
        row_sprouted = rng.random() < 0.6
        for x in range(w):
            if c.px.get((x, y)) == EARTH:
                c.set(x, y, SHADE)
        if row_sprouted:
            for sx in range(3, w - 3, 3):
                if rng.random() < 0.8 and c.px.get((sx, y - 1)) == EARTH:
                    c.set(sx, y - 1, LIGHT)
                    if rng.random() < 0.6 and c.px.get((sx, y - 2)) == EARTH:
                        c.set(sx, y - 2, BASE)
    return c


def greens_plot(seed: int, w: int = 64, h: int = 22) -> Canvas:
    """A plot of leafy greens: rows of tufts at uneven heights over the tilled soil, so it reads as a crop, not a bare field."""
    rng = random.Random(seed)
    c = tilled_plot(seed, w, h)
    for y in range(4, h - 2, 4):
        for x in range(4, w - 4, 4):
            if rng.random() < 0.15:
                continue                              # a gap in the row, so growth looks uneven
            top = y - rng.randint(3, 5)
            c.set(x, y - 1, BASE)
            c.set(x, y, BASE)
            c.set(x - 1, top + 1, LIGHT)
            c.set(x, top, LIGHT)
            c.set(x + 1, top + 1, LIGHT)
    return c


PROPS = [
    ('farm_barn', barn),
    ('farm_shed', shed),
    ('farm_hay_0', lambda: hay_bale(0)),
    ('farm_hay_1', lambda: hay_bale(1)),
    ('farm_scarecrow', scarecrow),
    ('farm_cart', cart),
    ('farm_crates', crates),
    ('farm_plot_a', lambda: tilled_plot(41)),
    ('farm_plot_b', lambda: tilled_plot(77)),
    ('farm_greens', lambda: greens_plot(59)),
]


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    for name, make in PROPS:
        make().image().save(os.path.join(OUT, name + '.png'))
        print('wrote', name)
    for name, fw, seed in FIELD_SPECS:
        wheat_sheet(seed, fw).save(os.path.join(OUT, name + '_sheet.png'))
        print('wrote', name + '_sheet', fw * WHEAT_FRAMES, 'px wide')
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
