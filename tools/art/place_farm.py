"""Places the Larkmoor farm district (Thistle Rise, east of the windmill) and writes assets/art/zone1b/farm/farm.json.

Layout comes from larkmoor_layout.py (layout texels). The Larkmoor canvas is 2x the layout (the windmill foot is at
layout (1090, 518) and canvas (2180, 1037)), so every layout value is doubled here.

Rules, all in layout texels unless noted:
- The box is centre (1090, 520), 260 x 220. Nothing is placed outside it.
- Every item bbox sits on walkable grass (walkable.png = 255, ground is green, not path cream or water).
- 19 texels clear of every path (the map thread widens paths to about 1.7x; this is the clearance it asked for).
- 30 texels clear of every pad plate, 24 of the windmill and the gates, and clear of the mere (with a 12 texel margin).
- No overlap with the meadow's existing sprites, or with another farm item (4 canvas texels of air between items).

Output: farm.json with sprites in the placements3d format (file, kind, x, y, w, h, foot, sort_y) plus fence runs as
polylines in canvas texels. The farm is always loaded: it is about two dozen nodes, so it fits under the 1350 ceiling.

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
MERE_MARGIN = 12                        # layout texels
GAP = 4                                 # canvas texels between farm items

# Sprite sizes (canvas texels), from gen_farm.py. Fields are the whole 768-wide sheet's frame: 96 x 28.
SIZES = {
    'farm_barn': (72, 56), 'farm_shed': (40, 34), 'farm_hay_0': (16, 12), 'farm_hay_1': (16, 12),
    'farm_scarecrow': (18, 34), 'farm_cart': (28, 20), 'farm_crates': (12, 12),
    'farm_plot_a': (64, 22), 'farm_plot_b': (64, 22),
    'farm_field_a': (96, 28), 'farm_field_b': (96, 28), 'farm_field_c': (128, 28), 'farm_field_d': (160, 28),
    'farm_greens': (64, 22),
}
FILES = {
    'farm_barn': 'farm_barn.png', 'farm_shed': 'farm_shed.png', 'farm_hay_0': 'farm_hay_0.png',
    'farm_hay_1': 'farm_hay_1.png', 'farm_scarecrow': 'farm_scarecrow.png', 'farm_cart': 'farm_cart.png',
    'farm_crates': 'farm_crates.png', 'farm_plot_a': 'farm_plot_a.png', 'farm_plot_b': 'farm_plot_b.png',
    'farm_field_a': 'field_a_sheet.png', 'farm_field_b': 'field_b_sheet.png',
    'farm_field_c': 'field_c_sheet.png', 'farm_field_d': 'field_d_sheet.png', 'farm_greens': 'farm_greens.png',
}

# Where each item wants to go (layout texels). Each is searched outward from its target, nearest first, inside the box.
# Fields first: they are the big shapes, and the small items fill the gaps around them.
TARGETS = [
    ('farm_field_d', 1040, 486), ('farm_field_a', 976, 445), ('farm_field_c', 1116, 596),
    ('farm_field_b', 1118, 556), ('farm_field_c', 1000, 580), ('farm_field_a', 1196, 470),
    ('farm_field_d', 1080, 640), ('farm_field_b', 1010, 430),
    ('farm_greens', 1082, 576), ('farm_plot_a', 984, 506), ('farm_plot_b', 1148, 528),
    ('farm_greens', 1004, 618), ('farm_plot_a', 1200, 608), ('farm_greens', 1030, 470),
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

    def clear_of_taken(self, x0, y0, x1, y1):
        for (a, b, c, d) in self.taken:
            if not (x1 + GAP <= a or x0 >= c + GAP or y1 + GAP <= b or y0 >= d + GAP):
                return False
        return True

    def place(self, w, h, tx, ty, radius=80):
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
            if not self.clear_of_taken(x0, y0, x1, y1):
                continue
            self.taken.append((x0, y0, x1, y1))
            return x0, y0
        return None


def _existing_rects(path):
    d = json.load(open(path))
    rects = []
    for s in d['sprites']:
        x, y, w, h = int(s['x']), int(s['y']), int(s['w']), int(s['h'])
        rects.append((x, y, x + w, y + h))
    return rects


def _fence_runs(field_rects, ground: Ground, placer: Placer, rng: random.Random):
    """Wobbly fence runs along the south and east edges of each field. Points are sampled every few canvas texels with
    a little wobble. Each run keeps only its longest stretch that stands on walkable grass, clear of the paths, pads
    and the other farm items, so a fence never crosses a walkway or the water."""
    runs = []
    for (x0, y0, x1, y1) in field_rects:
        edges = [
            ((x0 - 4, y1 + 5), (x1 + 4, y1 + 5)),   # south
            ((x1 + 5, y0 - 4), (x1 + 5, y1 + 4)),   # east
        ]
        for (ax, ay), (bx, by) in edges:
            n = max(2, int(math.hypot(bx - ax, by - ay) / 6))
            pts = []
            for i in range(n + 1):
                t = i / n
                pts.append((ax + (bx - ax) * t + rng.uniform(-1.2, 1.2), ay + (by - ay) * t + rng.uniform(-1.2, 1.2)))
            valid = [_fence_ok(ground, placer, px, py) for (px, py) in pts]
            best, cur = (0, 0), (0, 0)
            for i, v in enumerate(valid):
                if v:
                    cur = (cur[0] if cur[1] else i, cur[1] + 1)
                    if cur[1] > best[1]:
                        best = cur
                else:
                    cur = (0, 0)
            if best[1] >= 4:
                seg = pts[best[0]:best[0] + best[1]]
                runs.append([[round(px, 1), round(py, 1)] for (px, py) in seg])
    return runs


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


def build(map_only: bool = False) -> dict:
    ground = Ground()
    existing = _existing_rects(os.path.join(ZONE, 'placements3d.json'))
    placer = Placer(ground, existing)
    rng = random.Random(7)
    items = []
    field_rects = []
    for kind, tx, ty in TARGETS:
        w, h = SIZES[kind]
        at = placer.place(w, h, tx, ty)
        if at is None:
            print('no room for %s near (%d, %d)' % (kind, tx, ty))
            continue
        x, y = at
        if kind.startswith('farm_field'):
            field_rects.append((x, y, x + w, y + h))
        items.append({'kind': kind, 'file': FILES[kind], 'x': x, 'y': y, 'w': w, 'h': h,
                      'foot': [x + w / 2.0, y + h - 2.0], 'sort_y': float(y + h - 2)})
        if kind.startswith('farm_field'):
            items[-1]['frame_w'] = w            # one gust frame; the sheet is 8 frames wide
    # Each field starts its gust wave half a cycle apart from the last, so the two fields do not sway in step.
    for idx, it in enumerate(i for i in items if i['kind'].startswith('farm_field')):
        it['phase'] = (4 * idx) % 8
    fences = _fence_runs(field_rects, ground, placer, rng)
    channel = _channel(ground, placer)
    brooks = [{'points': channel, 'width': 2}] if channel else []
    if map_only:
        _print_map(ground, placer, items)
    return {'items': items, 'fences': fences, 'brooks': brooks, 'box_layout': list(BOX), 'scale': S}


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
        print(json.dumps({'items': len(out['items']), 'fences': len(out['fences'])}))
        return 0
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, 'farm.json'), 'w') as f:
        json.dump(out, f, indent=1)
    print('wrote farm.json:', len(out['items']), 'items,', len(out['fences']), 'fence runs')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
