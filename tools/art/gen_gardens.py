#!/usr/bin/env python3
"""Larkmoor flower fields: fills the ground around each statistic's pad row with that statistic's own flower and writes
world/larkmoor_gardens.json.

Each row sits in a FIELD: big flowers (the pad's own flower art at 1x to 3x, tinted and mirrored), small hand-drawn flowers
between them, and a few leafy shrubs. Density is highest around the plates and thins out into the grass, so the field has
a soft edge, and it fades away before the path (no flowers hug a path edge: the path blends into plain grass, then the
field starts). Never a grid, and nothing on water, under a pad plate, or in the footprint of a tree, bush or rock.
Deterministic (fixed seeds), so the JSON only changes when the ground, the props or the pads change.
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
VARIANTS = 4                # small hand-drawn flowers are variants 0 to 3; 4 and 5 are leafy shrubs (world/garden_art.gd)
SHRUBS = (4, 5)
FIELD_FIRST, FIELD_TINTS = 6, 4   # field flowers: the pad's own flower at scale 1, 2 or 3 in four tints: id = 6 + scale index * 4 + tint
GRASS = {(0x5f, 0xa3, 0x6a), (0xb7, 0xd9, 0x78), (0x2f, 0x6b, 0x55)}   # palette 3, 4 and 2: grass, light grass and grass in shade. Path sand, dirt and water are not.
BAD = {(0xf2, 0xe6, 0xa0), (0x1f, 0x3b, 0x35), (0xc2, 0x78, 0x4e)}   # path, water and dirt: keep flowers a few texels off them
PLATE = (24.0, 13.0)    # half extents of the exclusion ellipse around a pad plate (plate 14 x 7, plus its glow ring and a gap)
SOLID = {'oak', 'pine', 'bush', 'rock', 'crystals', 'menhir', 'tower', 'windmill', 'lighthouse', 'obelisk', 'sign', 'gateway', 'lantern'}
SPREAD = 1.4   # how much farther apart flowers stand than their bare footprints: open, even spacing, not tight blobs
PATH_CLEAR, PATH_FULL = 17.0, 36.0   # uv texels from a path centre line: no flower closer than the first, full density beyond the second
SCALE_PLATE = {1: 1.0, 2: 1.3, 3: 1.9}   # a bigger flower keeps further from a plate, so the plates always read

# One garden (field) per statistic, laid round its row. reach: how far the field spreads from the plates (uv texels), n: big
# flowers per plate, small: small flowers per plate, scales: weights for 1x, 2x, 3x, strays: far, sparse flowers that spill into the grass.
GARDENS = [
    dict(stat='dewdrop',   row='sprout',      seed=1.0, reach=84, n=70, small=34, scales=(3, 4, 1), strays=40),
    dict(stat='clover',    row='clover',      seed=2.0, reach=84, n=30, small=80, scales=(6, 4, 0), strays=40),
    dict(stat='thistle',   row='thistle',     seed=3.0, reach=100, n=100, small=46, scales=(2, 4, 2), strays=48),
    dict(stat='heather',   row='heather',     seed=4.0, reach=88, n=74, small=34, scales=(3, 4, 1), strays=42),
    dict(stat='foxglove',  row='foxglove',    seed=5.0, reach=84, n=120, small=56, scales=(1, 3, 4), strays=38),
    dict(stat='starbloom', row='starbloom_n', seed=6.0, reach=80, n=136, small=62, scales=(2, 4, 2), strays=32),
    dict(stat='starbloom', row='starbloom_w', seed=7.0, reach=80, n=74, small=33, scales=(2, 4, 2), strays=32),
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


def patch(x, y, seed):
    """0 to 1, slowly varying: where a field is thick and where it opens into grass, so it grows in drifts, not an even carpet."""
    a = math.sin(x * 0.037 + seed) + math.sin(y * 0.071 + x * 0.019 + seed * 2.1) + math.sin((x + y * 1.7) * 0.029 + seed * 3.7)
    return max(0.0, min(1.0, 0.5 + a / 4.2))


def uv_to_screen(u, v):
    return LAY._from_uv(u, v)


def radius(rng, reach, cap=1.0):
    """A distance from a plate: half the draws spread evenly over the whole field (so it is not a heap at the plates),
    half bunch toward the plates, so the middle is a little fuller than the edge without forming blobs."""
    r = reach * math.sqrt(rng.random()) if rng.random() < 0.55 else abs(rng.gauss(0, reach * 0.6))
    return r if r <= reach * cap else reach * cap * rng.random()


def thick(x, y, seed):
    """How likely a spot is to take a flower: gentle drifts, never bare patches next to fat ones."""
    return 0.5 + 0.5 * patch(x, y, seed)


def around(p, ang, r):
    """The screen point r ground texels from screen point p, at ground angle ang (a ground circle is a 2:1 ellipse on screen)."""
    u, v = LAY._to_uv(*p)
    return uv_to_screen(u + math.cos(ang) * r, v + math.sin(ang) * r)


def garden(cfg, pads, grass, near_bad, boxes, rng, taken):
    """The field for one row. pads: [(x, y)] in texels. Returns [x, y, stat, variant] flowers."""
    h, w = grass.shape
    out = []
    stat = STATS.index(cfg['stat'])
    fb = [v * LAY.S for v in LAY.FARM_BOX]   # the windmill farm keeps its own planting: no field flowers inside its box

    def ok(x, y, k=1.0, shrub=False, jitter=1.0):
        xi, yi = int(x), int(y)
        if fb[0] <= x <= fb[2] and fb[1] <= y <= fb[3]:
            return False
        if xi < 6 or yi < 6 or xi >= w - 6 or yi >= h - 6:
            return False
        if not grass[yi, xi] or near_bad[yi, xi]:
            return False
        near = min(ALL_PADS, key=lambda q: (x - q[0]) ** 2 + ((y - q[1]) * 2.0) ** 2)
        if near not in pads:   # a flower belongs to the row whose plate is closest, so two fields never run into each other
            return False
        grow = 1.5 if shrub else SCALE_PLATE.get(int(k), 1.0)   # a bigger flower or a shrub keeps a wider berth from the plates
        for q in ALL_PADS:
            if ((x - q[0]) / (PLATE[0] * grow)) ** 2 + ((y - q[1]) / (PLATE[1] * grow)) ** 2 < 1.0:
                return False
        if in_box(boxes, x, y):
            return False
        cell = (xi // 4, yi // 3)
        r = 6 if (shrub or k >= 3) else 4
        need_x, need_y = (14.0, 7.0) if shrub else (SPREAD * (3.2 * k + 1.0) * jitter, SPREAD * (1.3 * k + 1.0) * jitter)
        for dx in range(-r, r + 1):
            for dy in range(-r, r + 1):
                for q in taken.get((cell[0] + dx, cell[1] + dy), ()):
                    if abs(q[0] - x) < max(need_x, q[2] * 0.8) and abs(q[1] - y) < max(need_y, q[2] * 0.4):
                        return False
        return True

    def path_ok(x, y, lo=PATH_CLEAR, hi=PATH_FULL):
        """The field fades out toward a path: nothing inside lo, thinning up to hi, so the path blends into plain grass."""
        g = LAY.path_gap((x, y))
        return g >= hi or (g > lo and rng.random() < (g - lo) / (hi - lo))

    def put(x, y, variant, k):
        xi, yi = int(x), int(y)
        taken.setdefault((xi // 4, yi // 3), []).append((x, y, k))
        out.append([xi, yi, stat, variant])

    # shrubs frame the field: a loose hedge on the side away from the path, and one past each end of the row
    cx = sum(p[0] for p in pads) / len(pads)
    cy = sum(p[1] for p in pads) / len(pads)
    best_dir = max((LAY.path_gap(around((cx, cy), a, 40)), a) for a in [i * math.tau / 16 for i in range(16)])[1]
    spots = []
    for f in range(len(pads)):
        spots.append(around(pads[f], best_dir + rng.uniform(-0.5, 0.5), rng.uniform(40, 64)))
    (ax, ay), (bx, by) = pads[0], pads[-1]
    ln = math.hypot(bx - ax, by - ay) or 1.0
    ux, uy = (bx - ax) / ln, (by - ay) / ln
    spots += [(ax - ux * 46, ay - uy * 46), (bx + ux * 46, by + uy * 46)]
    for sx, sy in spots:
        for _ in range(rng.randint(2, 3)):
            x, y = sx + rng.gauss(0, 10), sy + rng.gauss(0, 5)
            if ok(x, y, 3, True) and path_ok(x, y, PATH_CLEAR + 8, PATH_FULL + 10):
                put(x, y, rng.choice(SHRUBS), 14)
    # big flowers: the pad's own flower grown large, densest at the plates and thinning into the grass
    weights = cfg['scales']
    for p in pads:
        for _ in range(cfg['n'] * 14):
            ang = rng.uniform(0, math.tau)
            r = radius(rng, cfg['reach'])
            x, y = around(p, ang, r)
            k = rng.choices((1, 2, 3), weights=weights)[0]
            if rng.random() > thick(x, y, cfg['seed']):
                continue
            if ok(x, y, k, jitter=rng.uniform(0.75, 1.6)) and path_ok(x, y):
                put(x, y, FIELD_FIRST + (k - 1) * FIELD_TINTS + rng.randrange(FIELD_TINTS), k)
    # small flowers fill the gaps between the big ones
    for p in pads:
        for _ in range(cfg['small'] * 14):
            ang = rng.uniform(0, math.tau)
            r = radius(rng, cfg['reach'], 1.15)
            x, y = around(p, ang, r)
            if rng.random() > thick(x, y, cfg['seed']):
                continue
            if ok(x, y, 1, jitter=rng.uniform(0.75, 1.6)) and path_ok(x, y):
                put(x, y, rng.randrange(VARIANTS), 1)
    # strays: a thin, sparse trail of flowers spilling out into the grass, thinner the further out
    for _ in range(cfg['strays'] * 6):
        p = rng.choice(pads)
        r = rng.uniform(cfg['reach'] * 0.9, cfg['reach'] * 1.7)
        x, y = around(p, rng.uniform(0, math.tau), r)
        if ok(x, y, 1) and path_ok(x, y, PATH_CLEAR + 6, PATH_FULL + 10):
            put(x, y, rng.choice((rng.randrange(VARIANTS), FIELD_FIRST + rng.randrange(FIELD_TINTS))), 1)
    return out


ALL_PADS = []


def main():
    global ALL_PADS
    grass, near_bad, boxes = load_world()
    districts = {d['id']: d for d in LAY.DISTRICTS}
    row_district = {v: k for k, v in LAY._ROW_OF.items()}
    ALL_PADS = [tuple(p) for d in LAY.DISTRICTS for p in d['pads']]
    flowers = []
    taken = {}
    for gi, cfg in enumerate(GARDENS):
        rng = random.Random(7000 + gi)
        d = districts[row_district[cfg['row']]]
        pads = [tuple(p) for p in d['pads']]
        got = garden(cfg, pads, grass, near_bad, boxes, rng, taken)
        big = sum(1 for f in got if f[3] >= FIELD_FIRST)
        print('%-10s %-12s %4d flowers (%d field, %d shrubs) around %d pads' % (cfg['stat'], cfg['row'], len(got), big, sum(1 for f in got if f[3] in SHRUBS), len(pads)))
        flowers += got
    flowers.sort(key=lambda f: (f[1], f[0]))
    with open(OUT, 'w') as f:
        json.dump({'format': 2, 'stats': STATS, 'flowers': flowers}, f, separators=(',', ':'))
    print('wrote %s: %d flowers' % (OUT, len(flowers)))


if __name__ == '__main__':
    main()
