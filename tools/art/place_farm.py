"""Places the Larkmoor farm district (Thistle Rise, east of the windmill) and writes assets/art/zone1b/farm/farm.json.

Layout comes from larkmoor_layout.py (layout texels). The Larkmoor canvas is 2x the layout (the windmill foot is at
layout (1090, 518) and canvas (2180, 1037)), so every layout value is doubled here.

Rules, all in layout texels unless noted:
- The box is centre (1090, 520), 260 x 220. Nothing is placed outside it.
- Every item bbox sits on walkable grass (walkable.png = 255, ground is green, not path cream or water).
- 19 texels clear of every path (the map thread widens paths to about 1.7x; this is the clearance it asked for).
- 30 texels clear of every pad plate, 24 of the windmill and the gates, and clear of the mere (with a 12 texel margin).
- No overlap with the meadow's existing sprites, or with another farm item (4 canvas texels of air between items).

Output: farm.json with sprites in the placements3d format (file, kind, x, y, w, h, foot, sort_y), the wheat clumps'
seed and stage, and the irrigation channel. Wheat clumps are baked into sheets by tools/bake_wheat.gd. The farm is always loaded: it is about two dozen nodes, so it fits under the 1350 ceiling.

Run: python3 tools/art/place_farm.py [--map]   (--map prints an ASCII view of the box).
"""
import json
import math
import os
import random
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import larkmoor_layout as LAY  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
ZONE = os.path.join(ROOT, 'assets', 'art', 'zone1b', 'larkmoor')
OUT = os.path.join(ROOT, 'assets', 'art', 'zone1b', 'farm')
S = 2                                   # canvas texels per layout texel

BOX = (1090, 520, 260, 220)             # centre x, centre y, width, height (layout)
PATH_CLEAR = 19 * S
PAD_CLEAR = 30 * S
WINDMILL_CLEAR = 24 * S
WHEAT_DX = 18                           # canvas texels: two clumps' centres stay at least this far apart in x ...
WHEAT_DY = 12                           # ... or in y, so clumps overlap a little, never stack
MERE_MARGIN = 12                        # layout texels
GAP = 4                                 # canvas texels between farm items

# Sprite sizes (canvas texels), from gen_farm.py. Wheat clumps are placed by WHEAT_PATCHES below.
SIZES = {
    'farm_barn': (72, 56), 'farm_shed': (40, 34), 'farm_hay_0': (16, 12), 'farm_hay_1': (16, 12),
    'farm_scarecrow': (18, 34), 'farm_cart': (28, 20), 'farm_crates': (12, 12),
}
FILES = {
    'farm_barn': 'farm_barn.png', 'farm_shed': 'farm_shed.png', 'farm_hay_0': 'farm_hay_0.png',
    'farm_hay_1': 'farm_hay_1.png', 'farm_scarecrow': 'farm_scarecrow.png', 'farm_cart': 'farm_cart.png',
    'farm_crates': 'farm_crates.png',
}

# Where each item wants to go (layout texels). Each is searched outward from its target, nearest first, inside the box.
# Fields first: they are the big shapes, and the small items fill the gaps around them.
TARGETS = [
    ('farm_barn', 1066, 424), ('farm_shed', 1028, 432), ('farm_scarecrow', 1136, 528),
    ('farm_hay_0', 1064, 593), ('farm_hay_1', 1146, 547), ('farm_hay_0', 1158, 593),
    ('farm_cart', 1119, 527), ('farm_crates', 1167, 543), ('farm_crates', 1029, 615),
]


def _densify(poly, step=4.0):
    pts = []
    for (ax, ay), (bx, by) in zip(poly, poly[1:]):
        n = max(1, int(math.hypot(bx - ax, by - ay) / step))
        for i in range(n):
            t = i / n
            pts.append((ax + (bx - ax) * t, ay + (by - ay) * t))
    pts.append(poly[-1])
    return np.array(pts, dtype=float) * S


def _rect_dist(px, py, x0, y0, x1, y1):
    """Distance from points (arrays) to the rectangle [x0,x1] x [y0,y1]."""
    dx = np.maximum(np.maximum(x0 - px, 0), px - x1)
    dy = np.maximum(np.maximum(y0 - py, 0), py - y1)
    return np.hypot(dx, dy)


class Ground:
    def __init__(self):
        walk = np.array(Image.open(os.path.join(ZONE, 'walkable.png')).convert('L'))
        self.walk = walk == 255
        g = np.array(Image.open(os.path.join(ZONE, 'ground.png')).convert('RGB')).astype(int)
        r, gg, b = g[..., 0], g[..., 1], g[..., 2]
        self.grass = (gg - r >= 15) & (gg >= b + 8) & (r < 200)
        self.H, self.W = self.walk.shape
        paths = [p for pp in LAY.PATHS for p in [_densify(pp)]]
        self.path_pts = np.vstack(paths)
        pads = [(x, y) for d in LAY.DISTRICTS for (x, y) in d['pads']]
        self.pad_pts = np.array(pads, dtype=float) * S
        self.obstacles = [(lm['at'][0] * S, lm['at'][1] * S) for lm in LAY.LANDMARKS if lm['kind'] in ('windmill', 'great_lantern')]
        self.gates = [(x * S, y * S) for (x, y) in (LAY.EMBER_GATE, LAY.HOLLOW_GATE)]
        m = LAY.MERE
        self.mere = (m['c'][0] * S, m['c'][1] * S, (m['rx'] + MERE_MARGIN) * S, (m['ry'] + MERE_MARGIN) * S)

    def ok_rect(self, x0, y0, x1, y1):
        """True when the canvas rect [x0, x1) x [y0, y1) is walkable grass and clear of every constraint."""
        if x0 < 0 or y0 < 0 or x1 > self.W or y1 > self.H:
            return False
        sub_w = self.walk[y0:y1, x0:x1]
        if sub_w.mean() < 0.999:
            return False
        if self.grass[y0:y1, x0:x1].mean() < 0.9:
            return False
        if _rect_dist(self.path_pts[:, 0], self.path_pts[:, 1], x0, y0, x1, y1).min() < PATH_CLEAR:
            return False
        if _rect_dist(self.pad_pts[:, 0], self.pad_pts[:, 1], x0, y0, x1, y1).min() < PAD_CLEAR:
            return False
        for (ox, oy) in self.obstacles + self.gates:
            if _rect_dist(np.array([ox]), np.array([oy]), x0, y0, x1, y1)[0] < WINDMILL_CLEAR:
                return False
        cx, cy, rx, ry = self.mere
        nx = np.clip(cx, x0, x1)
        ny = np.clip(cy, y0, y1)
        if ((nx - cx) / rx) ** 2 + ((ny - cy) / ry) ** 2 <= 1.0:
            return False
        return True


def _spiral(radius_layout, step=2):
    """Offsets (layout texels) inside a radius, nearest first."""
    pts = []
    r = 0
    while r <= radius_layout:
        for dx in range(-r, r + 1, step):
            for dy in range(-r, r + 1, step):
                if max(abs(dx), abs(dy)) == r:
                    pts.append((dx, dy))
        r += step
    pts.sort(key=lambda p: math.hypot(*p))
    return pts


def _inside_box(x0, y0, x1, y1):
    bx, by, bw, bh = BOX
    return x0 >= (bx - bw / 2) * S and x1 <= (bx + bw / 2) * S and y0 >= (by - bh / 2) * S and y1 <= (by + bh / 2) * S


class Placer:
    def __init__(self, ground: Ground, existing: list):
        self.g = ground
        self.taken = list(existing)      # (x0, y0, x1, y1) canvas rects already used
        self.tags = [None] * len(self.taken)   # 'wheat' for clumps, None for everything else

    def clear_of_taken(self, x0, y0, x1, y1, tag=None):
        """Wheat clumps may overlap each other a little (thick wheat), but keep their centres apart. Everything else
        keeps GAP texels clear of every rect already used."""
        for (a, b, c, d), t in zip(self.taken, self.tags):
            if tag == 'wheat' and t == 'wheat':
                if abs((x0 + x1) - (a + c)) / 2.0 < WHEAT_DX and abs((y0 + y1) - (b + d)) / 2.0 < WHEAT_DY:
                    return False
                continue
            if not (x1 + GAP <= a or x0 >= c + GAP or y1 + GAP <= b or y0 >= d + GAP):
                return False
        return True

    def place(self, w, h, tx, ty, radius=80, tag=None):
        """Return the top-left canvas rect for a w x h sprite whose bbox centre is near layout (tx, ty), or None."""
        for dx, dy in _spiral(radius):
            cx = (tx + dx) * S
            cy = (ty + dy) * S
            x0 = int(round(cx - w / 2))
            y0 = int(round(cy - h / 2))
            x1, y1 = x0 + w, y0 + h
            if not _inside_box(x0, y0, x1, y1):
                continue
            if not self.g.ok_rect(x0, y0, x1, y1):
                continue
            if not self.clear_of_taken(x0, y0, x1, y1, tag):
                continue
            self.taken.append((x0, y0, x1, y1))
            self.tags.append(tag)
            return x0, y0
        return None


def _existing_rects(path):
    d = json.load(open(path))
    rects = []
    for s in d['sprites']:
        x, y, w, h = int(s['x']), int(s['y']), int(s['w']), int(s['h'])
        rects.append((x, y, x + w, y + h))
    return rects


def _fence_ok(ground: Ground, placer: Placer, px: float, py: float) -> bool:
    ix, iy = int(round(px)), int(round(py))
    if not (0 <= ix < ground.W and 0 <= iy < ground.H):
        return False
    if not (ground.walk[iy, ix] and ground.grass[iy, ix]):
        return False
    if _rect_dist(ground.path_pts[:, 0], ground.path_pts[:, 1], ix, iy, ix, iy).min() < PATH_CLEAR:
        return False
    if _rect_dist(ground.pad_pts[:, 0], ground.pad_pts[:, 1], ix, iy, ix, iy).min() < PAD_CLEAR:
        return False
    for (a, b, c, d) in placer.taken:
        if a - 2 <= ix <= c + 2 and b - 2 <= iy <= d + 2:
            return False
    return True


# Wheat: three organic patches. Each has a wobbly outline (harmonics of the angle), and clumps are placed on a loose
# grid inside it. Every clump goes through the placer, so it never overlaps a path, pad, or another item.
WHEAT_PATCHES = [
    # centre x, centre y (layout texels), radius x, radius y, stage mix. Each sits on the walkable ground the placer
    # allows inside the farm box (the map is walkable grass west and south of centre, cliffs and the mere to the east).
    (1034, 468, 50, 19, 'gold'),
    (1140, 540, 30, 22, 'gold'),
    (1030, 600, 44, 16, 'mixed'),
    (1090, 440, 26, 12, 'mixed'),
    (1120, 572, 26, 12, 'gold'),
]
CLUMP_SIZES = [(32, 28), (28, 26), (32, 26), (30, 28)]     # canvas texels (w, h): smaller clumps, tighter grid, more stalks


def _limit(theta: float, phases) -> float:
    """The patch outline: how far from the centre (in radii) the wheat may grow at angle theta."""
    return 1 + 0.16 * math.sin(3 * theta + phases[0]) + 0.09 * math.sin(5 * theta + phases[1]) \
        + 0.05 * math.sin(8 * theta + phases[2])


def _wheat_items(placer: Placer, rng: random.Random, start: int, shapes: list):
    """Clump items for every patch. Stage: 1 golden, 2 brown inside a mixed patch, 0 green shoots at a patch's edge.
    Each patch's outline (centre, radii, phases) is appended to `shapes` for the fence ring."""
    items = []
    n = start
    for (cx, cy, rx, ry, mix) in WHEAT_PATCHES:
        phases = [rng.uniform(0, 2 * math.pi) for _ in range(3)]
        shapes.append((cx, cy, rx, ry, phases))
        # Grid steps are layout texels (the canvas is 2x), so a clump of 48 to 64 canvas texels is 24 to 32 layout wide.
        for row in range(-int(ry) // 10 - 2, int(ry) // 10 + 3):
            for col in range(-int(rx) // 12 - 2, int(rx) // 12 + 3):
                gx = cx + col * 12 + (6 if row % 2 else 0) + rng.uniform(-1, 1)
                gy = cy + row * 10 + rng.uniform(-1, 1)
                dx, dy = gx - cx, gy - cy
                theta = math.atan2(dy, dx)
                limit = _limit(theta, phases)
                r = math.hypot(dx / rx, dy / ry)
                if r > limit:
                    continue
                w, h = CLUMP_SIZES[rng.randrange(len(CLUMP_SIZES))]
                if mix == 'mixed':
                    stage = 0 if r > 0.8 and rng.random() < 0.6 else (2 if rng.random() < 0.4 else 1)
                else:
                    stage = 0 if r > 0.85 and rng.random() < 0.4 else 1
                at = placer.place(w, h, gx, gy, radius=5, tag='wheat')
                if at is None:
                    continue
                x, y = at
                kind = 'farm_wheat_%d' % n
                items.append({'kind': kind, 'file': 'wheat/%s.png' % kind, 'x': x, 'y': y, 'w': w, 'h': h,
                              'foot': [x + w / 2.0, y + h - 2.0], 'sort_y': float(y + h - 2),
                              'frame_w': w, 'phase': rng.randrange(8), 'seed': 5000 + n, 'stage': stage})
                n += 1
    return items


FENCE_OFFSET = 11                       # layout texels beyond the wheat outline: clear of every clump's reach
FENCE_CHORD = 24                        # canvas texels per fence piece (one sprite each)
FENCE_GATE = 11                         # canvas texels of walk-in gap, half on each side of a gate
FENCE_GATES = 2                         # walk-in gaps per patch


def _fence_items(ground: Ground, placer: Placer, shapes: list, start: int):
    """A rustic fence ring around each wheat patch, outside the clumps, with walk-in gaps.

    The ring is sampled along each patch outline and cut into straight chords of about FENCE_CHORD canvas texels. Each
    chord is one sprite (posts and two rails, drawn by gen_farm.py from its 'chord' endpoints). A chord is kept only
    when its box is walkable grass, clear of paths and pads, and clear of the items placed before it (the targets,
    the wheat and the channel). Chords may touch each other: they are one fence."""
    items = []
    n = start
    for pi, (cx, cy, rx, ry, phases) in enumerate(shapes):
        rng = random.Random(41 + pi)
        radius_c = math.sqrt((rx * rx + ry * ry) / 2.0) * S      # canvas texels, for arc lengths
        count = max(24, int(2 * math.pi * (radius_c + FENCE_OFFSET * S) / FENCE_CHORD))
        gates = [rng.uniform(0, 2 * math.pi) for _ in range(FENCE_GATES)]
        half_gate = (FENCE_GATE / 2.0) / (radius_c + FENCE_OFFSET * S)
        pts = []
        for k in range(count):
            th = 2 * math.pi * k / count
            L = _limit(th, phases)
            px = (cx + (rx * L + FENCE_OFFSET) * math.cos(th)) * S
            py = (cy + (ry * L + FENCE_OFFSET) * math.sin(th)) * S
            pts.append((px, py))
        for k in range(count):
            mid = 2 * math.pi * (k + 0.5) / count
            if any(_angle_gap(mid, g) < half_gate for g in gates):
                continue
            (ax, ay), (bx, by) = pts[k], pts[(k + 1) % count]
            x0 = int(math.floor(min(ax, bx))) - 1
            y0 = int(math.floor(min(ay, by))) - 8          # room above the line for the posts
            x1 = int(math.ceil(max(ax, bx))) + 2
            y1 = int(math.ceil(max(ay, by))) + 2
            if not _inside_box(x0, y0, x1, y1) or not ground.ok_rect(x0, y0, x1, y1):
                continue
            if not placer.clear_of_taken(x0, y0, x1, y1):
                continue
            w, h = x1 - x0, y1 - y0
            kind = 'farm_fence_%d' % n
            items.append({'kind': kind, 'file': 'fence/%s.png' % kind, 'x': x0, 'y': y0, 'w': w, 'h': h,
                          'foot': [x0 + w / 2.0, y1 - 2.0], 'sort_y': float(y1 - 2),
                          'chord': [round(ax - x0, 1), round(ay - y0, 1), round(bx - x0, 1), round(by - y0, 1)]})
            n += 1
    return items


def _angle_gap(a: float, b: float) -> float:
    d = abs(a - b) % (2 * math.pi)
    return min(d, 2 * math.pi - d)


def _fence_batch(pieces: list) -> list:
    """One item for the whole fence ring: a single sprite, so the ring costs one node. Its box is the union of the
    pieces, and its foot sits on the box's north edge, so the ring sorts behind every wheat clump and prop south of it.
    Each piece keeps its own rect and chord, so the test can still check the pieces against the wheat and buildings."""
    if not pieces:
        return []
    x0 = min(p['x'] for p in pieces)
    y0 = min(p['y'] for p in pieces)
    x1 = max(p['x'] + p['w'] for p in pieces)
    y1 = max(p['y'] + p['h'] for p in pieces)
    w, h = x1 - x0, y1 - y0
    return [{'kind': 'farm_fence', 'file': 'fence/farm_fence.png', 'x': x0, 'y': y0, 'w': w, 'h': h,
             'foot': [x0 + w / 2.0, float(y0)], 'sort_y': float(y0), 'pieces': pieces}]


def _patch_shapes() -> list:
    """Each wheat patch's outline (centre, radii, phases). The wheat's own draws replay from the same seed, and they do
    not depend on where a clump lands, so these are the outlines the wheat is grown inside."""
    shapes: list = []
    _wheat_items(Placer(Ground(), []), random.Random(7), 0, shapes)
    return shapes


def build(map_only: bool = False) -> dict:
    """Places the whole farm from scratch: the targets, the wheat patches, the water channel, then the fence ring around
    each patch. The wheat sheets in assets/art/zone1b/farm/wheat/ are baked from this output (tools/bake_wheat.gd), so
    re-run the bake after any change here."""
    ground = Ground()
    existing = _existing_rects(os.path.join(ZONE, 'placements3d.json'))
    placer = Placer(ground, existing)
    rng = random.Random(7)
    items = []
    for kind, tx, ty in TARGETS:
        w, h = SIZES[kind]
        at = placer.place(w, h, tx, ty)
        if at is None:
            print('no room for %s near (%d, %d)' % (kind, tx, ty))
            continue
        x, y = at
        items.append({'kind': kind, 'file': FILES[kind], 'x': x, 'y': y, 'w': w, 'h': h,
                      'foot': [x + w / 2.0, y + h - 2.0], 'sort_y': float(y + h - 2)})
    # The fence ring goes before the wheat: it marks each patch's edge, and the clumps grow inside it.
    pieces = _fence_items(ground, placer, _patch_shapes(), 0)
    for it in pieces:
        placer.taken.append((it['x'], it['y'], it['x'] + it['w'], it['y'] + it['h']))
        placer.tags.append('fence')
    items += _fence_batch(pieces)
    items += _wheat_items(placer, rng, len(items), [])
    channel = _channel(ground, placer)
    brooks = [{'points': channel, 'width': 2}] if channel else []
    if map_only:
        _print_map(ground, placer, items)
    return {'items': items, 'fences': [], 'brooks': brooks, 'box_layout': list(BOX), 'scale': S}


def _channel(ground: Ground, placer: Placer):
    """An irrigation channel across the box: the longest stretch of a horizontal run that stands clear of every
    item, the paths and the pads. Points are about 6 canvas texels apart, so the channel reads as water in a few
    short ripples. It runs beside the fields, not through them, so no field is cut."""
    bx, by, bw, bh = BOX
    best: list = []
    for ly in range(int(by - bh / 2) + 6, int(by + bh / 2) - 6, 4):
        y = ly * S
        run: list = []
        for lx in range(int(bx - bw / 2) + 2, int(bx + bw / 2) - 2, 3):
            x = lx * S
            if _fence_ok(ground, placer, x, y):
                run.append([float(x), float(y)])
            else:
                if len(run) > len(best):
                    best = run
                run = []
        if len(run) > len(best):
            best = run
    return [[round(px, 1), round(py, 1)] for (px, py) in best] if len(best) >= 8 else []


def _print_map(ground: Ground, placer: Placer, items):
    bx, by, bw, bh = BOX
    x0, y0 = int((bx - bw / 2 - 20) * S), int((by - bh / 2 - 20) * S)
    x1, y1 = int((bx + bw / 2 + 20) * S), int((by + bh / 2 + 20) * S)
    rows = []
    for y in range(y0, y1, 6):
        row = []
        for x in range(x0, x1, 3):
            ch = '.'
            if not ground.walk[y, x]:
                ch = '#'
            elif not ground.grass[y, x]:
                ch = '~'
            for it in items:
                if it['x'] <= x < it['x'] + it['w'] and it['y'] <= y < it['y'] + it['h']:
                    ch = it['kind'][5]
            if _rect_dist(ground.path_pts[:, 0], ground.path_pts[:, 1], x, y, x, y).min() < PATH_CLEAR:
                ch = ch if ch != '.' else ','
            row.append(ch)
        rows.append(''.join(row))
    print('\n'.join(rows))


def main() -> int:
    map_only = '--map' in sys.argv
    out = build(map_only)
    if map_only:
        print(json.dumps({'items': len(out['items'])}))
        return 0
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, 'farm.json'), 'w') as f:
        json.dump(out, f, indent=1)
    fence_n = sum(1 for it in out['items'] if it['kind'].startswith('farm_fence'))
    print('wrote farm.json:', len(out['items']), 'items,', fence_n, 'fence pieces')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
