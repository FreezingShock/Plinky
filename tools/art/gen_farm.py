"""Larkmoor farm district: sprites for the Thistle Rise farm (world/farm/).

Writes assets/art/zone1b/farm/ (PNG props and farm_preview.png). The wheat is not drawn here: tools/bake_wheat.gd bakes it. Pixel scale is Larkmoor's
(the windmill is about 65 texels wide), so these are about twice the meadow's cozy props. Everything is drawn in the
meadow palette roles from gen_cozy.py, so the post-process palette and dither treat them like the rest of the meadow.

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
from farm_iso import barn, cart, crates, hay_bale, scarecrow, shed  # noqa: E402  (elevated view, see farm_iso.py)

ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'art', 'zone1b', 'farm')



# Every prop comes from farm_iso.py, fitted to its ground (row h - 2), so none is lifted here.
PROPS = [
    ('farm_barn', barn),
    ('farm_shed', shed),
    ('farm_hay_0', lambda: hay_bale(0)),
    ('farm_hay_1', lambda: hay_bale(1)),
    ('farm_scarecrow', scarecrow),
    ('farm_cart', cart),
    ('farm_crates', crates),
]


def fence_piece(w: int, h: int, chord) -> Canvas:
    """One straight piece of a rustic fence, w x h. `chord` is the piece's line from (x0, y0) to (x1, y1) in this box
    (see place_farm.py). Two rails run along the chord, with a shaded underside on the lower one, and a post every
    eight texels with a lit cap. Posts stand on the chord; the rails sit above it."""
    c = Canvas(w, h)
    px, py, qx, qy = chord
    length = math.hypot(qx - px, qy - py)
    # Seeded from the chord, so the same piece breaks the same way on every regeneration.
    rng = random.Random('%.1f,%.1f,%.1f,%.1f' % (px, py, qx, qy))
    steps = max(2, int(length * 2))

    def at(t: float, off: float = 0.0):
        return px + (qx - px) * t, py + (qy - py) * t + off

    # Rails: each rail has up to two gaps where a plank is gone. The rail end beside a gap sags one texel, and the
    # lower rail keeps its shaded underside wherever it is still there.
    for off, under in ((-6, None), (-3, SHADE)):
        gaps = []
        if length > 20:
            for _ in range(rng.choice((0, 1, 1, 2))):
                g = rng.uniform(0.12, 0.88)
                gaps.append((g, g + rng.uniform(3.0, 7.0) / length))
        for i in range(steps + 1):
            t = i / steps
            if any(a <= t <= b for a, b in gaps):
                continue
            x, y = at(t, off)
            c.set(round(x), round(y), EARTH)
            if under is not None:
                c.set(round(x), round(y + 3), under)
        for a, _b in gaps:
            x, y = at(a, off)
            c.set(round(x), round(y) + 1, EARTH)      # sagging end beside the gap

    # Posts: most stand full height with a lit cap. Some snap short, some lean a texel, and some are missing.
    n = max(2, int(length / 8) + 1)
    for i in range(n):
        if 0 < i < n - 1 and rng.random() < 0.15:
            continue
        x, y = at(i / (n - 1))
        top = rng.choice((4, 5)) if rng.random() < 0.2 else 7
        lean = 1 if rng.random() < 0.12 else 0
        c.seg(x, y, x + lean, y - top, EARTH)
        if top == 7:
            c.set(round(x + lean), round(y - top), LIGHT)   # lit post cap
    c.outline(INK)
    return c


def fences_from_manifest() -> None:
    """Writes the whole fence ring as one PNG, from the batch item in farm.json (see place_farm.py). Each piece is drawn
    in its own box and pasted at its place in the batch, so the ring reads as one fence."""
    import json
    with open(os.path.join(OUT, 'farm.json')) as f:
        items = json.load(f)['items']
    batch = [it for it in items if it['kind'] == 'farm_fence']
    if not batch:
        return
    it = batch[0]
    out = Image.new('RGBA', (int(it['w']), int(it['h'])), (0, 0, 0, 0))
    for p in it['pieces']:
        piece = fence_piece(int(p['w']), int(p['h']), p['chord']).image()
        out.alpha_composite(piece, (int(p['x'] - it['x']), int(p['y'] - it['y'])))
    os.makedirs(os.path.join(OUT, 'fence'), exist_ok=True)
    out.save(os.path.join(OUT, it['file']))


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    fences_from_manifest()
    for name, make in PROPS:
        make().image().save(os.path.join(OUT, name + '.png'))
        print('wrote', name)
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
