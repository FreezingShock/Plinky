#!/usr/bin/env python3
"""Larkmoor flower gardens: scatters each statistic's flowers around its pad row and writes world/larkmoor_gardens.json.

Each garden is organic, never a grid: a few irregular patches along the row (varied size and density), flowers spilling into
the grass beyond them, a thin trail of strays, and nothing on a path, on water, under a pad plate, or in the footprint of
a tree, bush or rock. Deterministic (fixed seeds), so the JSON only changes when the ground, the props or the pads change.
Run after gen_larkmoor.py:  python3 tools/art/gen_gardens.py
Needs Pillow and numpy. Output: [x, y, stat index, variant] per flower, sorted by y (draw order), in ground texels."""
import json, math, os, random, sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, HERE)
import larkmoor_layout as LAY

DIR = os.path.join(ROOT, 'assets', 'art', 'zone1b', 'larkmoor')
OUT = os.path.join(ROOT, 'world', 'larkmoor_gardens.json')
STATS = ['dewdrop', 'clover', 'thistle', 'heather', 'foxglove', 'starbloom']   # the order of GardenArt.STATS
VARIANTS = 4                # flower variants 0 to 3; variants 4 and 5 are leafy shrubs (world/garden_art.gd)
SHRUBS = (4, 5)
GRASS = {(0x5f, 0xa3, 0x6a), (0xb7, 0xd9, 0x78), (0x2f, 0x6b, 0x55)}   # palette 3, 4 and 2: grass, light grass and grass in shade. Path sand, dirt and water are not.
BAD = {(0xf2, 0xe6, 0xa0), (0x1f, 0x3b, 0x35), (0xc2, 0x78, 0x4e)}   # path, water and dirt: keep flowers a few texels off them
PLATE = (21.0, 11.0)    # half extents of the exclusion ellipse around a pad plate (plate 14 x 7, plus its glow ring and a gap)
SOLID = {'oak', 'pine', 'bush', 'rock', 'crystals', 'menhir', 'tower', 'windmill', 'lighthouse', 'obelisk', 'sign', 'gateway', 'lantern'}

# Which district's pads each garden grows around, with its look. spread: how far the patches reach from the pad line (x texels),
# patches: how many patches per pad, size: patch radius range, per: flowers per patch, strays: scattered spill flowers.
# `skew` leans the variants: weights per variant so every garden has a favourite and a rare form.
GARDENS = [
    dict(stat='dewdrop',   districts=['heronmere'],              spread=70, patches=3.0, size=(16, 30), per=(12, 26), strays=26, weights=(4, 3, 2, 1)),
    dict(stat='clover',    districts=['cairnfold'],              spread=64, patches=3.2, size=(14, 28), per=(16, 30), strays=24, weights=(2, 4, 3, 2)),
    dict(stat='thistle',   districts=['green'],                  spread=70, patches=3.0, size=(16, 30), per=(12, 24), strays=26, weights=(3, 3, 2, 2)),
    dict(stat='heather',   districts=['oak'],                    spread=72, patches=3.2, size=(16, 32), per=(16, 30), strays=30, weights=(3, 3, 2, 2)),
    dict(stat='foxglove',  districts=['thistle'],                spread=70, patches=3.0, size=(14, 26), per=(10, 20), strays=24, weights=(3, 2, 2, 3)),
    dict(stat='starbloom', districts=['emberwatch', 'westmere'], spread=66, patches=3.2, size=(14, 26), per=(10, 20), strays=24, weights=(3, 3, 1, 2)),
]


def load_world():
    ground = np.array(Image.open(os.path.join(DIR, 'ground.png')).convert('RGB'))
    h, w, _ = ground.shape
    key = ground[:, :, 0].astype(np.int32) << 16 | ground[:, :, 1].astype(np.int32) << 8 | ground[:, :, 2].astype(np.int32)
    grass = np.zeros((h, w), bool)
    for c in GRASS:
        grass |= key == (c[0] << 16 | c[1] << 8 | c[2])
    bad = np.zeros((h, w), bool)
    for c in BAD:
        bad |= key == (c[0] << 16 | c[1] << 8 | c[2])
    # dilate the bad ground by a few texels so no flower touches a path edge or the shore
    near_bad = bad.copy()
    for dy, dx in ((0, 3), (0, -3), (3, 0), (-3, 0), (2, 2), (-2, -2), (2, -2), (-2, 2), (0, 6), (0, -6), (4, 0), (-4, 0)):
        near_bad |= np.roll(np.roll(bad, dy, 0), dx, 1)
    placements = json.load(open(os.path.join(DIR, 'placements3d.json')))
    boxes = []
    for s in placements['sprites']:
        if s['kind'] in SOLID:
            boxes.append((s['x'] - 2, s['y'] + s['h'] * 0.35, s['x'] + s['w'] + 2, s['y'] + s['h'] + 3))
    return grass, near_bad, boxes


def in_box(boxes, x, y):
    return any(b[0] <= x <= b[2] and b[1] <= y <= b[3] for b in boxes)


def garden(cfg, pads, grass, near_bad, boxes, rng, taken):
    """Flowers for one garden. pads: [(x, y)] in texels."""
    h, w = grass.shape
    out = []
    n_pads = len(pads)
    centres = []
    # patches: placed around each pad and in the gaps between pads, offset sideways by a random, uneven amount
    anchors = list(pads) + [((a[0] + b[0]) / 2, (a[1] + b[1]) / 2) for a, b in zip(pads, pads[1:])]
    for a in anchors:
        for _ in range(max(1, int(round(cfg['patches'] + rng.uniform(-0.8, 0.8))))):
            ang = rng.uniform(0, math.tau)
            dist = rng.uniform(12, cfg['spread'])
            centres.append((a[0] + math.cos(ang) * dist, a[1] + math.sin(ang) * dist * 0.5, rng.uniform(*cfg['size']), rng.randint(*cfg['per'])))
    # a few big drifts further out, so flowers spill into the grass
    for _ in range(max(2, n_pads)):
        a = rng.choice(pads)
        ang = rng.uniform(0, math.tau)
        dist = rng.uniform(cfg['spread'] * 0.8, cfg['spread'] * 1.5)
        centres.append((a[0] + math.cos(ang) * dist, a[1] + math.sin(ang) * dist * 0.5, rng.uniform(10, 20), rng.randint(5, 10)))

    fb = [v * LAY.S for v in LAY.FARM_BOX]   # the windmill farm keeps its own planting: no garden flowers inside its box

    def ok(x, y, big=False):
        xi, yi = int(x), int(y)
        if fb[0] <= x <= fb[2] and fb[1] <= y <= fb[3]:
            return False
        if xi < 6 or yi < 6 or xi >= w - 6 or yi >= h - 6:
            return False
        if not grass[yi, xi] or near_bad[yi, xi]:
            return False
        for p in pads:
            k = 1.5 if big else 1.0   # a shrub keeps a wider berth from the plates
            if ((x - p[0]) / (PLATE[0] * k)) ** 2 + ((y - p[1]) / (PLATE[1] * k)) ** 2 < 1.0:
                return False
        if in_box(boxes, x, y):
            return False
        cell = (xi // 4, yi // 3)
        r = 3 if big else 1
        for dx in range(-r, r + 1):
            for dy in range(-r, r + 1):
                for q in taken.get((cell[0] + dx, cell[1] + dy), ()):
                    if abs(q[0] - x) < (10 if big else 4) and abs(q[1] - y) < (5 if big else 2.5):
                        return False
        return True

    def add(x, y):
        if not ok(x, y):
            return
        xi, yi = int(x), int(y)
        taken.setdefault((xi // 4, yi // 3), []).append((x, y))
        v = rng.choices(range(VARIANTS), weights=cfg['weights'])[0]
        out.append([xi, yi, STATS.index(cfg['stat']), v])

    def add_shrub(x, y):
        if not ok(x, y, True):
            return
        xi, yi = int(x), int(y)
        taken.setdefault((xi // 4, yi // 3), []).append((x, y))
        out.append([xi, yi, STATS.index(cfg['stat']), rng.choice(SHRUBS)])

    # shrubs frame the garden: a few just past each end of the row and a loose hedge behind it (up the screen, never in front of a plate)
    (ax, ay), (bx, by) = pads[0], pads[-1]
    ln = math.hypot(bx - ax, by - ay) or 1.0
    ux, uy = (bx - ax) / ln, (by - ay) / ln
    spots = [(ax - ux * 54, ay - uy * 54), (bx + ux * 54, by + uy * 54)]
    for f in (0.1, 0.3, 0.5, 0.7, 0.9):
        spots.append((ax + (bx - ax) * f + rng.uniform(-10, 10), ay + (by - ay) * f - rng.uniform(44, 70)))
    for sx, sy in spots:
        for _ in range(rng.randint(2, 4)):
            add_shrub(sx + rng.gauss(0, 12), sy + rng.gauss(0, 5))

    for cx, cy, r, n in centres:
        for _ in range(n * 2):
            # gaussian blob in iso metric (a ground circle is a 2:1 ellipse on screen), denser at the heart
            gx = rng.gauss(0, r * 0.55)
            gy = rng.gauss(0, r * 0.55) * 0.5
            add(cx + gx, cy + gy)
    for _ in range(cfg['strays'] * 4):
        a = rng.choice(pads)
        ang = rng.uniform(0, math.tau)
        dist = rng.uniform(20, cfg['spread'] * 1.6)
        add(a[0] + math.cos(ang) * dist, a[1] + math.sin(ang) * dist * 0.5)
    return out


def main():
    grass, near_bad, boxes = load_world()
    districts = {d['id']: d for d in LAY.DISTRICTS}
    flowers = []
    taken = {}
    for gi, cfg in enumerate(GARDENS):
        rng = random.Random(7000 + gi)
        pads = [tuple(p) for d in cfg['districts'] for p in districts[d]['pads']]
        got = garden(cfg, pads, grass, near_bad, boxes, rng, taken)
        print('%-10s %3d flowers around %d pads' % (cfg['stat'], len(got), len(pads)))
        flowers += got
    flowers.sort(key=lambda f: (f[1], f[0]))
    with open(OUT, 'w') as f:
        json.dump({'format': 1, 'stats': STATS, 'flowers': flowers}, f, separators=(',', ':'))
    print('wrote %s: %d flowers' % (OUT, len(flowers)))


if __name__ == '__main__':
    main()
