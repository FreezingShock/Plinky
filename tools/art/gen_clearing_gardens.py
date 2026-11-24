#!/usr/bin/env python3
"""Starting Clearing flower fields: the zone 1 meadow's two pad rows (Sprout, Clover) each sit in a field of their own
statistic's flower, the same look as the Larkmoor rows (tools/art/gen_gardens.py). Writes world/clearing_gardens.json in the
same format 2 as larkmoor_gardens.json, so world/garden_layer.gd draws it unchanged.

Pads stay where they are (3 per row, the tutorial's order). Only the ground around them is dressed.
Coordinates: the scene frame is 640x360, and the ground image sits at (-100,-60) (placements3d.json bleed), so a
ground pixel is frame + (100, 60). Output is in frame coordinates, like the anchors and sprites.
Run after gen_meadow3d.py:  python3 tools/art/gen_clearing_gardens.py
Needs Pillow and numpy. Deterministic (fixed seeds)."""
import json, math, os, random
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
DIR = os.path.join(ROOT, 'assets', 'art', 'zone1', 'meadow3d')
OUT = os.path.join(ROOT, 'world', 'clearing_gardens.json')
STATS = ['dewdrop', 'clover', 'thistle', 'heather', 'foxglove', 'starbloom']   # the order of GardenArt.STATS
VARIANTS = 4
SHRUBS = (4, 5)
FIELD_FIRST, FIELD_TINTS = 6, 4
GRASS = {(0x5f, 0xa3, 0x6a), (0xb7, 0xd9, 0x78), (0x2f, 0x6b, 0x55)}   # the same palette as the Larkmoor ground
BAD = {(0xf2, 0xe6, 0xa0), (0x1f, 0x3b, 0x35), (0xc2, 0x78, 0x4e)}     # path sand, water and dirt
PLATE = (24.0, 13.0)
SOLID = {'oak', 'pine', 'bush', 'rock', 'crystals', 'lantern'}
SCALE_PLATE = {1: 1.0, 2: 1.3, 3: 1.9}
PATH_CLEAR, PATH_FULL = 3.0, 12.0   # ground texels from the path edge: no flower inside the first, full density past the second
OFFSET = (100, 60)                  # ground pixel = frame + OFFSET
ORIGIN = (320.0, 4.0)               # screen = (ox + u - v, oy + (u + v) / 2), the 2:1 iso projection in the frame

# One field per row. Pads 0 to 2 are the Sprout row, 3 to 5 the Clover row (anchor order from gen_meadow3d).
GARDENS = [
    dict(stat='dewdrop', pads=(0, 1, 2), seed=1.0, reach=72, n=96, small=52, scales=(3, 4, 1), strays=36),
    dict(stat='clover',  pads=(3, 4, 5), seed=2.0, reach=72, n=96, small=56, scales=(4, 4, 1), strays=36),
]


def to_uv(x, y):
    a, b = x - ORIGIN[0], y - ORIGIN[1]
    return (a + 2.0 * b) / 2.0, (2.0 * b - a) / 2.0


def to_screen(u, v):
    return ORIGIN[0] + u - v, ORIGIN[1] + (u + v) / 2.0


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
    # distance from the nearest bad texel (path, water, dirt), in texels, up to 40: a grid walk of shifts, no scipy needed
    dist = np.full((h, w), 40.0)
    dist[bad] = 0.0
    frontier = bad.copy()
    for k in range(1, 41):
        grown = frontier.copy()
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dy or dx:
                    grown |= np.roll(np.roll(frontier, dy, 0), dx, 1)
        new = grown & (dist == 40.0)
        dist[new] = float(k)
        frontier = grown
        if not new.any():
            break
    placements = json.load(open(os.path.join(DIR, 'placements3d.json')))
    boxes = []
    for s in placements['sprites']:
        if s['kind'] in SOLID:
            boxes.append((s['x'] - 2, s['y'] + s['h'] * 0.35, s['x'] + s['w'] + 2, s['y'] + s['h'] + 3))
    pads = [(a['sx'], a['sy']) for a in placements['anchors'] if a['kind'] == 'pad']
    keep_out = [(a['sx'], a['sy'], 18.0 if a['kind'] in ('gate', 'player_spawn') else 14.0)
                for a in placements['anchors'] if a['kind'] in ('gate', 'player_spawn', 'shrine')]
    return grass, dist, boxes, pads, keep_out


def in_box(boxes, x, y):
    return any(b[0] <= x <= b[2] and b[1] <= y <= b[3] for b in boxes)


def patch(x, y, seed):
    a = math.sin(x * 0.037 + seed) + math.sin(y * 0.071 + x * 0.019 + seed * 2.1) + math.sin((x + y * 1.7) * 0.029 + seed * 3.7)
    return max(0.0, min(1.0, 0.5 + a / 4.2))


def around(p, ang, r):
    """The frame point r ground texels from frame point p, at ground angle ang."""
    u, v = to_uv(*p)
    return to_screen(u + math.cos(ang) * r, v + math.sin(ang) * r)


def garden(cfg, pads, all_pads, grass, dist, boxes, keep_out, rng, taken):
    h, w = grass.shape
    out = []
    stat = STATS.index(cfg['stat'])

    row_pads = [pads[i] for i in cfg['pads']]

    def ok(x, y, k=1.0, shrub=False):
        gx, gy = int(round(x)) + OFFSET[0], int(round(y)) + OFFSET[1]
        if gx < 6 or gy < 6 or gx >= w - 6 or gy >= h - 6:
            return False
        if not grass[gy, gx]:
            return False
        near = min(all_pads, key=lambda q: (x - q[0]) ** 2 + ((y - q[1]) * 2.0) ** 2)
        if near not in row_pads:
            return False
        grow = 1.5 if shrub else SCALE_PLATE.get(int(k), 1.0)
        for q in all_pads:
            if ((x - q[0]) / (PLATE[0] * grow)) ** 2 + ((y - q[1]) / (PLATE[1] * grow)) ** 2 < 1.0:
                return False
        for kx, ky, kr in keep_out:
            if math.hypot(x - kx, y - ky) < kr:
                return False
        if in_box(boxes, x, y):
            return False
        cell = (int(x) // 4, int(y) // 3)
        r = 6 if (shrub or k >= 3) else 4
        need_x, need_y = (10.0, 5.0) if shrub else (3.2 * k + 1.0, 1.3 * k + 1.0)
        for dx in range(-r, r + 1):
            for dy in range(-r, r + 1):
                for q in taken.get((cell[0] + dx, cell[1] + dy), ()):
                    if abs(q[0] - x) < max(need_x, q[2] * 0.8) and abs(q[1] - y) < max(need_y, q[2] * 0.4):
                        return False
        return True

    def path_ok(x, y, lo=PATH_CLEAR, hi=PATH_FULL):
        gx, gy = int(round(x)) + OFFSET[0], int(round(y)) + OFFSET[1]
        if not (0 <= gx < w and 0 <= gy < h):
            return False
        g = float(dist[gy, gx])
        return g >= hi or (g > lo and rng.random() < (g - lo) / (hi - lo))

    def put(x, y, variant, k):
        xi, yi = int(round(x)), int(round(y))
        taken.setdefault((xi // 4, yi // 3), []).append((x, y, k))
        out.append([xi, yi, stat, variant])

    # shrubs frame the field, a loose hedge past each end of the row
    (ax, ay), (bx, by) = row_pads[0], row_pads[-1]
    ln = math.hypot(bx - ax, by - ay) or 1.0
    ux, uy = (bx - ax) / ln, (by - ay) / ln
    spots = [around(p, rng.uniform(0, math.tau), rng.uniform(26, 38)) for p in row_pads]
    spots += [(ax - ux * 30, ay - uy * 30), (bx + ux * 30, by + uy * 30)]
    for sx, sy in spots:
        for _ in range(rng.randint(1, 2)):
            x, y = sx + rng.gauss(0, 6), sy + rng.gauss(0, 3)
            if ok(x, y, 3, True) and path_ok(x, y, PATH_CLEAR + 4, PATH_FULL + 6):
                put(x, y, rng.choice(SHRUBS), 14)
    weights = cfg['scales']
    for p in row_pads:
        for _ in range(cfg['n'] * 8):
            r = abs(rng.gauss(0, cfg['reach'] * 0.55))
            if r > cfg['reach']:
                continue
            x, y = around(p, rng.uniform(0, math.tau), r)
            k = rng.choices((1, 2, 3), weights=weights)[0]
            if rng.random() > 0.3 + 0.9 * patch(x, y, cfg['seed']):
                continue
            if ok(x, y, k) and path_ok(x, y):
                put(x, y, FIELD_FIRST + (k - 1) * FIELD_TINTS + rng.randrange(FIELD_TINTS), k)
    for p in row_pads:
        for _ in range(cfg['small'] * 8):
            r = abs(rng.gauss(0, cfg['reach'] * 0.55))
            if r > cfg['reach'] * 1.15:
                continue
            x, y = around(p, rng.uniform(0, math.tau), r)
            if rng.random() > 0.3 + 0.9 * patch(x, y, cfg['seed']):
                continue
            if ok(x, y, 1) and path_ok(x, y):
                put(x, y, rng.randrange(VARIANTS), 1)
    for _ in range(cfg['strays'] * 6):
        p = rng.choice(row_pads)
        r = rng.uniform(cfg['reach'] * 0.9, cfg['reach'] * 1.6)
        x, y = around(p, rng.uniform(0, math.tau), r)
        if ok(x, y, 1) and path_ok(x, y, PATH_CLEAR + 3, PATH_FULL + 6):
            put(x, y, rng.choice((rng.randrange(VARIANTS), FIELD_FIRST + rng.randrange(FIELD_TINTS))), 1)
    return out


def main():
    grass, dist, boxes, pads, keep_out = load_world()
    flowers = []
    taken = {}
    for gi, cfg in enumerate(GARDENS):
        rng = random.Random(9100 + gi)
        got = garden(cfg, pads, pads, grass, dist, boxes, keep_out, rng, taken)
        big = sum(1 for f in got if f[3] >= FIELD_FIRST)
        print('%-8s pads %s: %4d flowers (%d field)' % (cfg['stat'], list(cfg['pads']), len(got), big))
        flowers += got
    flowers.sort(key=lambda f: (f[1], f[0]))
    with open(OUT, 'w') as f:
        json.dump({'format': 2, 'stats': STATS, 'flowers': flowers}, f, separators=(',', ':'))
    print('wrote %s: %d flowers' % (OUT, len(flowers)))


if __name__ == '__main__':
    main()
