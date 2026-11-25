"""Places the Larkmoor farm district (Foxglove Rise, east of the windmill) and writes assets/art/zone1b/farm/farm.json.

Layout comes from larkmoor_layout.py (layout texels). The Larkmoor canvas is 2x the layout (the windmill foot is at
layout (1090, 518) and canvas (2180, 1037)), so every layout value is doubled here.

Rules, all in layout texels unless noted:
- The box is centre (1090, 520), 260 x 220. Nothing is placed outside it.
- Every item bbox sits on walkable grass (walkable.png = 255, ground is green, not path cream or water).
- 19 texels clear of every path (the map thread widens paths to about 1.7x; this is the clearance it asked for).
- 30 texels clear of every pad plate, 24 of the windmill and the gates, and clear of the mere (with a 12 texel margin).
- No overlap with the meadow's existing sprites, or with another farm item (4 canvas texels of air between items).

Output: farm.json with sprites in the placements3d format (file, kind, x, y, w, h, foot, sort_y), the wheat clumps'
seed and stage, the irrigation channel, and the field list. The fields are irregular shapes (farm_fields.py) on tilled soil:
one soil decal per field is written to soil/ (farm_soil_N.png, drawn behind everything). Wheat clumps are baked into sheets
by tools/bake_wheat.gd. The farm is always loaded: it is about two dozen nodes, so it fits under the 1350 ceiling.

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
import farm_fields as FF  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
ZONE = os.path.join(ROOT, 'assets', 'art', 'zone1b', 'larkmoor')
OUT = os.path.join(ROOT, 'assets', 'art', 'zone1b', 'farm')
S = 2                                   # canvas texels per layout texel

BOX = (1090, 548, 260, 276)             # centre x, centre y, width, height (layout); runs south of the yard to the open grass
SAND_CLEAR = 12                          # canvas texels: props keep this far from the drawn sand path
FIELD_SAND_CLEAR = 22                    # canvas texels: wheat and soil keep this far from the drawn sand path (11 layout texels)
FENCE_SAND_CLEAR = 10                    # canvas texels: a fence chord keeps this far from the sand path
PAD_CLEAR = 30 * S
WINDMILL_CLEAR = 24 * S
WHEAT_DX = 15                           # canvas texels: two clumps' centres stay at least this far apart in x ...
WHEAT_DY = 9                           # ... or in y, so clumps overlap a little, never stack
MERE_MARGIN = 12                        # layout texels
GAP = 4                                 # canvas texels between farm items

# Sprite sizes (canvas texels), from gen_farm.py. Wheat clumps are placed by FIELDS below.
SIZES = {
    'farm_barn': (72, 58), 'farm_shed': (40, 36), 'farm_hay_0': (16, 14), 'farm_hay_1': (16, 14),
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


SMALL_PROPS = ('farm_hay_0', 'farm_hay_1', 'farm_crates', 'farm_scarecrow', 'farm_cart')   # low props: soil runs under them


def _rect_dist(px, py, x0, y0, x1, y1):
    """Distance from points (arrays) to the rectangle [x0,x1] x [y0,y1]."""
    dx = np.maximum(np.maximum(x0 - px, 0), px - x1)
    dy = np.maximum(np.maximum(y0 - py, 0), py - y1)
    return np.hypot(dx, dy)


def _box_sum(mask, r: int):
    """Number of True texels in the (2r+1) square around each texel. Summed-area table, so it is fast on the canvas."""
    H, W = mask.shape
    sat = np.zeros((H + 1, W + 1), dtype=np.int64)
    sat[1:, 1:] = mask.astype(np.int64).cumsum(0).cumsum(1)
    ys, xs = np.arange(H), np.arange(W)
    y0 = np.clip(ys - r, 0, H)
    y1 = np.clip(ys + r + 1, 0, H)
    x0 = np.clip(xs - r, 0, W)
    x1 = np.clip(xs + r + 1, 0, W)
    Y0, X0 = np.meshgrid(y0, x0, indexing='ij')
    Y1, X1 = np.meshgrid(y1, x1, indexing='ij')
    return sat[Y1, X1] - sat[Y0, X1] - sat[Y1, X0] + sat[Y0, X0]


def _near_mask(mask, r: int):
    """True where any True texel of mask lies within r of that texel (a (2r+1) square)."""
    return _box_sum(mask, r) > 0


def _open_mask(mask, r: int):
    """Morphological opening: removes specks thinner than (2r+1) texels, such as dithered light flecks in the grass,
    and keeps the drawn path band."""
    eroded = _box_sum(mask, r) == (2 * r + 1) ** 2
    return _near_mask(eroded, r)


class Ground:
    def __init__(self):
        # walkable.png is RGBA since #376, and the game's walk mask (world/walk_mask.gd) reads it the same way: magenta
        # (255, 0, 255) is walkable ground, green (0, 255, 0) is water, black is not walkable.
        wrgb = np.array(Image.open(os.path.join(ZONE, 'walkable.png')).convert('RGB')).astype(int)
        self.walk = (wrgb[..., 0] == 255) & (wrgb[..., 1] == 0) & (wrgb[..., 2] == 255)
        self.water = (wrgb[..., 0] == 0) & (wrgb[..., 1] == 255) & (wrgb[..., 2] == 0)
        # The sand path as drawn: ACCENT (242, 230, 160) and its near-sand texels in ground.png. This is the only path
        # check. LAY.PATHS is a different frame from the drawn ground, so it is not used for clearance.
        g = np.array(Image.open(os.path.join(ZONE, 'ground.png')).convert('RGB')).astype(int)
        gr, gg, gb = g[..., 0], g[..., 1], g[..., 2]
        # Light-sand colour from ground.png, then opened so the dithered light flecks in the grass drop out. What is left
        # is the drawn path band.
        self.sand = _open_mask((gr >= 225) & (gg >= 210) & (gb <= 180) & (gr - gb >= 50), 2)
        self.sand_near = _near_mask(self.sand, SAND_CLEAR)   # texels within SAND_CLEAR of the drawn sand
        self.sand_field = _near_mask(self.sand, FIELD_SAND_CLEAR)   # wheat and soil stay clear of the path by this much
        self.sand_fence = _near_mask(self.sand, FENCE_SAND_CLEAR)
        self.grass = (gg - gr >= 15) & (gg >= gb + 8) & (gr < 200)
        self.H, self.W = self.walk.shape
        pads = [(x, y) for d in LAY.DISTRICTS for (x, y) in d['pads']]
        self.pad_pts = np.array(pads, dtype=float) * S
        self.obstacles = [(lm['at'][0] * S, lm['at'][1] * S) for lm in LAY.LANDMARKS if lm['kind'] in ('windmill', 'great_lantern')]
        self.gates = [(x * S, y * S) for (x, y) in (LAY.EMBER_GATE, LAY.HOLLOW_GATE)]
        m = LAY.MERE
        self.mere = (m['c'][0] * S, m['c'][1] * S, (m['rx'] + MERE_MARGIN) * S, (m['ry'] + MERE_MARGIN) * S)

    def fence_ok(self, x0, y0, x1, y1):
        """A fence is a blocker: it stays inside the canvas, off the water and off the sand paths. A chord that would sit
        on a path is dropped, so the ring leaves a gap where a path meets it and the path stays open. Buildings and wheat
        are checked by the placer's taken rects, not here."""
        if x0 < 0 or y0 < 0 or x1 > self.W or y1 > self.H:
            return False
        if self.water[y0:y1, x0:x1].any():
            return False
        if self.sand[y0:y1, x0:x1].any():             # the drawn sand path, from ground.png: a chord never sits on it
            return False
        return True

    def ok_rect(self, x0, y0, x1, y1, field=False):
        """True when the canvas rect [x0, x1) x [y0, y1) is walkable grass and clear of every constraint."""
        if x0 < 0 or y0 < 0 or x1 > self.W or y1 > self.H:
            return False
        sub_w = self.walk[y0:y1, x0:x1]
        if sub_w.mean() < 0.999:
            return False
        if self.grass[y0:y1, x0:x1].mean() < 0.9:
            return False
        if (self.sand_field if field else self.sand_near)[y0:y1, x0:x1].any():
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
            if not self.g.ok_rect(x0, y0, x1, y1, field=(tag == 'wheat')):
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
    if ground.sand_near[iy, ix]:
        return False
    if _rect_dist(ground.pad_pts[:, 0], ground.pad_pts[:, 1], ix, iy, ix, iy).min() < PAD_CLEAR:
        return False
    for (a, b, c, d) in placer.taken:
        if a - 2 <= ix <= c + 2 and b - 2 <= iy <= d + 2:
            return False
    return True


# Wheat fields: irregular shapes on tilled soil (farm_fields.py). Each field is one of two real-field shapes, scaled,
# mirrored and warped differently, so they read as different fields scattered round the farm. Every clump goes through
# the placer, so it never overlaps a path, a pad, or another item.
FIELDS = [
    # kind, centre x, centre y (layout texels), scale, mirrored, warp seed. The first four are the original fields; the
    # last three sit on the open grass south of them, found by a search that keeps FIELD_SAND_CLEAR from every path and
    # clear of the yard. Fields may touch: their soil runs together, and the fence only runs round the outside.
    FF.Field('notched', 1005, 530, 1.55, False, 1),
    FF.Field('blob', 1000, 470, 1.35, True, 2),
    FF.Field('blob', 1065, 580, 1.05, False, 3),
    FF.Field('notched', 1075, 470, 0.80, True, 4),
    FF.Field('notched', 1020, 620, 1.25, False, 44),
    FF.Field('blob', 1070, 650, 1.10, True, 45),
    FF.Field('blob', 1050, 600, 0.95, False, 46),
]
CLUMP_SIZES = [(32, 28), (28, 26), (32, 26), (30, 28)]     # canvas texels (w, h): smaller clumps, tighter grid, more stalks
EDGE_SIZES = [(24, 22), (26, 24)]       # smaller clumps along a field's edge, so the irregular outline reads
EDGE_BAND = 5.0                         # layout texels: clumps whose foot is this close to the edge use EDGE_SIZES
EDGE_INSET = -3.0                       # layout texels: a clump's foot may stand this far outside the field's edge, so the wheat fills out to the soil
GRID_X = 7.5                           # layout texels between clump centres across a row
GRID_Y = 4.5                            # layout texels between rows; clumps still keep WHEAT_DX or WHEAT_DY apart
WHEAT_RADIUS = 12                       # layout texels: how far a clump may slide from its grid point to find room


def _wheat_items(placer: Placer, rng: random.Random, start: int, fields: list):
    """Clump items for every field. Stage 1 is golden and stage 2 is late, brown and dry: a slow noise across the field
    decides where. There are no green sprouts (Nathan: no green in the wheat)."""
    items = []
    n = start
    for f in fields:
        # Grid steps are layout texels (the canvas is 2x), so a clump of 28 to 32 canvas texels is 14 to 16 layout wide.
        rows = int(f.reach // GRID_Y) + 2
        cols = int(f.reach // GRID_X) + 2
        for row in range(-rows, rows + 1):
            for col in range(-cols, cols + 1):
                gx = f.cx + col * GRID_X + (GRID_X / 2 if row % 2 else 0) + rng.uniform(-1.2, 1.2)
                gy = f.cy + row * GRID_Y + rng.uniform(-1.2, 1.2)
                edge = f.sdf(gx, gy + 3.0)
                if edge > -EDGE_INSET:
                    continue
                sizes = EDGE_SIZES if edge > -EDGE_BAND else CLUMP_SIZES
                w, h = sizes[rng.randrange(len(sizes))]
                stage = 2 if f.tone(gx, gy) > 0.38 and rng.random() < 0.7 else 1
                at = placer.place(w, h, gx, gy, radius=WHEAT_RADIUS, tag="wheat")
                if at is None:
                    continue
                x, y = at
                kind = 'farm_wheat_%d' % n
                items.append({'kind': kind, 'file': 'wheat/%s.png' % kind, 'x': x, 'y': y, 'w': w, 'h': h,
                              'foot': [x + w / 2.0, y + h - 2.0], 'sort_y': float(y + h - 2),
                              'frame_w': w, 'phase': rng.randrange(8), 'seed': 5000 + n, 'stage': stage})
                n += 1
    return items


FENCE_OFFSET = 12                       # layout texels beyond the field's edge: a paddock, clear of every clump's reach
FENCE_CHORD = 24                        # canvas texels per fence piece (one sprite each)
FENCE_GATE = 11                         # canvas texels of walk-in gap, half on each side of a gate
FENCE_MIN_RUN = 3                       # chords: a fence run shorter than this is dropped, so there are no stubs
FENCE_GATES = 2                         # walk-in gaps per field
SOIL_REACH = 7.0                        # layout texels past a field's edge that hold tilled soil: up to 3 short of the fence
SOIL_BAND = 2.0                         # layout texels of Bayer dissolve beyond SOIL_REACH
SOIL_PAD = 2                            # canvas texels of air kept between the soil and any building or prop


class YardRing:
    """The farmyard: a rectangle around the barn, shed, hay, cart, crates and scarecrow, fenced like a field with one
    walk-in gate. It only has the parts _fence_items reads (cx, cy, gates, contour), so it is never wheat or soil."""

    def __init__(self, x0: float, y0: float, x1: float, y1: float, gates: int = 1):
        self.cx, self.cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
        self.box = (x0, y0, x1, y1)
        self.gates = gates

    def contour(self, offset: float, n: int = 96):
        x0, y0, x1, y1 = self.box
        return [(x0 - offset, y0 - offset), (x1 + offset, y0 - offset), (x1 + offset, y1 + offset),
                (x0 - offset, y1 + offset)]


# The yard covers every building target (layout texels, from TARGETS and SIZES): the barn and shed at the top, the scarecrow,
# cart and hay in the middle, and the crates at the bottom.
YARD = YardRing(1005, 402, 1180, 628)


def _fence_items(ground: Ground, placer: Placer, fields: list, start: int):
    """A rustic fence ring around each field, outside the clumps, with walk-in gaps.

    The ring runs FENCE_OFFSET texels outside the field's edge, resampled into straight chords of about FENCE_CHORD
    canvas texels. Each chord is one sprite (posts and two rails, drawn by gen_farm.py from its 'chord' endpoints). A chord
    is kept only when its box is walkable grass, clear of paths and pads, and clear of the items placed before it (the
    targets). Chords may touch each other: they are one fence."""
    items = []
    n = start
    for fi, f in enumerate(fields):
        rng = random.Random(41 + fi)
        ring = [(x * S, y * S) for (x, y) in f.contour(FENCE_OFFSET)]
        ring.append(ring[0])
        seg = [math.hypot(ring[i + 1][0] - ring[i][0], ring[i + 1][1] - ring[i][1]) for i in range(len(ring) - 1)]
        total = sum(seg)
        count = max(24, int(round(total / FENCE_CHORD)))
        pts = []
        for k in range(count):
            target = total * k / count
            i, acc = 0, 0.0
            while i < len(seg) - 1 and acc + seg[i] < target:
                acc += seg[i]
                i += 1
            t = (target - acc) / seg[i] if seg[i] > 0 else 0.0
            pts.append((ring[i][0] + (ring[i + 1][0] - ring[i][0]) * t, ring[i][1] + (ring[i + 1][1] - ring[i][1]) * t))
        gates = [rng.uniform(0, 2 * math.pi) for _ in range(getattr(f, 'gates', FENCE_GATES))]
        mean_r = total / (2 * math.pi)
        half_gate = (FENCE_GATE / 2.0) / mean_r
        keep = [False] * count
        cand = {}
        for k in range(count):
            (ax, ay), (bx, by) = pts[k], pts[(k + 1) % count]
            mid = math.atan2((ay + by) / 2.0 - f.cy * S, (ax + bx) / 2.0 - f.cx * S)
            if any(_angle_gap(mid, g) < half_gate for g in gates):
                continue
            # a chord inside a neighbouring field's soil is dropped, so touching fields share no inner fence
            mx, my = (ax + bx) / 2.0 / S, (ay + by) / 2.0 / S
            if any(o is not f and hasattr(o, 'sdf') and o.sdf(mx, my) < SOIL_REACH + 1.0 for o in fields):
                continue
            x0 = int(math.floor(min(ax, bx))) - 1
            y0 = int(math.floor(min(ay, by))) - 8          # room above the line for the posts
            x1 = int(math.ceil(max(ax, bx))) + 2
            y1 = int(math.ceil(max(ay, by))) + 2
            if not _inside_box(x0, y0, x1, y1) or not ground.fence_ok(x0, y0, x1, y1):
                continue
            if ground.sand_fence[y0:y1, x0:x1].any():
                continue
            if not placer.clear_of_taken(x0, y0, x1, y1):
                continue
            keep[k] = True
            cand[k] = (x0, y0, x1, y1, ax, ay, bx, by)
        # No stubs: a run of fewer than FENCE_MIN_RUN chords is dropped, so every fence reads as a connected line.
        for k in range(count):
            if not keep[k]:
                continue
            run = 1
            for step in (1, -1):
                j = k + step
                while keep[j % count] and run < count:
                    run += 1
                    j += step
            if run < FENCE_MIN_RUN and run < count:
                continue
            x0, y0, x1, y1, ax, ay, bx, by = cand[k]
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
    x0 = min(p['x'] for p in pieces) - 1      # one texel of transparent margin, matching gen_farm.FENCE_PAD
    y0 = min(p['y'] for p in pieces) - 1
    x1 = max(p['x'] + p['w'] for p in pieces) + 1
    y1 = max(p['y'] + p['h'] for p in pieces) + 1
    w, h = x1 - x0, y1 - y0
    return [{'kind': 'farm_fence', 'file': 'fence/farm_fence.png', 'x': x0, 'y': y0, 'w': w, 'h': h,
             'foot': [x0 + w / 2.0, float(y0)], 'sort_y': float(y0), 'pieces': pieces}]


def _soil_items(ground: Ground, placer: Placer, fields: list, start: int):
    """One soil decal per field: tilled dirt (farm_fields.soil_image) under the wheat, a few texels wider than it. It is
    drawn only on walkable grass, and never over a building or prop (the targets and the meadow's own sprites, plus
    SOIL_PAD texels of air). The sprite's foot is on its north edge, so it sorts behind everything south of it: the
    wheat, the walker and the props all draw over it. Returns (items, {file: image})."""
    items = []
    images = {}
    bx, by, bw, bh = BOX
    box = (int((bx - bw / 2) * S), int((by - bh / 2) * S), int((bx + bw / 2) * S), int((by + bh / 2) * S))
    blockers = [r for r, t in zip(placer.taken, placer.tags) if t is None]
    n = start
    for f in fields:
        lx0, ly0, lx1, ly1 = f.bounds(SOIL_REACH + SOIL_BAND + 1.0)
        x0, y0 = max(int(math.floor(lx0 * S)), box[0]), max(int(math.floor(ly0 * S)), box[1])
        x1, y1 = min(int(math.ceil(lx1 * S)), box[2]), min(int(math.ceil(ly1 * S)), box[3])
        if x1 - x0 < 4 or y1 - y0 < 4:
            continue
        mask = ground.walk[y0:y1, x0:x1] & ground.grass[y0:y1, x0:x1] & ~ground.sand_field[y0:y1, x0:x1]
        for (a, b, c, d) in blockers:
            ax0, ay0 = max(a - SOIL_PAD - x0, 0), max(b - SOIL_PAD - y0, 0)
            ax1, ay1 = min(c + SOIL_PAD - x0, x1 - x0), min(d + SOIL_PAD - y0, y1 - y0)
            if ax0 < ax1 and ay0 < ay1:
                mask[ay0:ay1, ax0:ax1] = False
        img = FF.soil_image(f, x0, y0, mask, S, SOIL_REACH, SOIL_BAND)
        bb = img.getbbox()
        if bb is None:
            continue
        img = img.crop(bb)
        x0, y0 = x0 + bb[0], y0 + bb[1]
        w, h = img.size
        kind = 'farm_soil_%d' % n
        images['soil/%s.png' % kind] = img
        items.append({'kind': kind, 'file': 'soil/%s.png' % kind, 'x': x0, 'y': y0, 'w': w, 'h': h,
                      'foot': [x0 + w / 2.0, float(y0)], 'sort_y': float(y0)})
        n += 1
    return items, images


TREE_FILES = ['oak_013', 'oak_051', 'oak_062', 'oak_044', 'pine_111', 'pine_127', 'pine_128', 'pine_085', 'pine_117']
GROVES = 3                              # tree clusters along the south and east edge of the farm
GROVE_TREES = 6                         # trees per cluster
GROVE_RADIUS = 34                       # layout texels a cluster's trees spread over
TREE_FIELD_CLEAR = 6.0                  # layout texels a tree's foot stays outside every field's soil


def _grove_items(ground: Ground, placer: Placer, fields: list, start: int):
    """Tree groves on the open grass along the south and east edge. The trees are the zone's own oaks and pines (copied
    into farm/trees/ so the farm manifest stays self-contained), the biggest in the set so the grove reads from far away.
    Each cluster centre is the roomiest spot found by a search (free walkable grass, clear of paths, wheat and soil), then
    the trees are placed nearest the centre first, through the placer, so none sits on a path, a field or another prop."""
    placements = json.load(open(os.path.join(ZONE, 'placements3d.json')))['sprites']
    by_name = {os.path.basename(sp['file'])[:-4]: sp for sp in placements}
    trees = [by_name[n] for n in TREE_FILES if n in by_name]
    if not trees:
        return [], {}
    bx, by, bw, bh = BOX
    free = ground.walk & ground.grass & ~ground.sand_field
    for (a, b, c, d) in placer.taken:
        free[max(b - 2, 0):d + 2, max(a - 2, 0):c + 2] = False
    centres = []
    best = []
    for ly in range(int(by - bh / 2) + 20, int(by + bh / 2) - 12, 6):
        for lx in range(int(bx - bw / 2) + 20, int(bx + bw / 2) - 12, 6):
            if any(f.sdf(lx, ly) < SOIL_REACH + TREE_FIELD_CLEAR for f in fields):
                continue
            if lx < 1110 and ly < 600:
                continue                      # groves go on the south and east edge, not the north-west corner
            r = int(GROVE_RADIUS * S * 0.8)
            win = free[max(ly * S - r, 0):ly * S + r:3, max(lx * S - r, 0):lx * S + r:3]
            if win.size:
                best.append((float(win.mean()), lx, ly))
    best.sort(reverse=True)
    for sc, lx, ly in best:
        if sc < 0.3 or len(centres) >= GROVES:
            break
        if all(math.hypot(lx - cx, ly - cy) > GROVE_RADIUS * 1.6 for cx, cy in centres):
            centres.append((lx, ly))
    rng = random.Random(77)
    items, images = [], {}
    n = start
    for cx, cy in centres:
        placed = 0
        spots = _spiral(GROVE_RADIUS, step=4)
        rng.shuffle(spots)
        for dx, dy in spots:
            if placed >= GROVE_TREES:
                break
            sp = rng.choice(trees)
            w, h = int(sp['w']), int(sp['h'])
            fx, fy = float(sp['foot'][0]) - float(sp['x']), float(sp['foot'][1]) - float(sp['y'])
            x0 = int(round((cx + dx) * S - fx))
            y0 = int(round((cy + dy) * S - fy))
            if any(f.sdf((x0 + fx) / S, (y0 + fy) / S) < SOIL_REACH + TREE_FIELD_CLEAR for f in fields):
                continue
            # The footprint is the trunk base: the crown may hang over the edge of the grass, the foot may not.
            fr = (int(x0 + fx - 8), int(y0 + fy - 6), int(x0 + fx + 8), int(y0 + fy + 3))
            if not (_inside_box(*fr) and ground.ok_rect(*fr) and placer.clear_of_taken(*fr)):
                continue
            placer.taken.append(fr)
            placer.tags.append(None)
            name = os.path.basename(sp['file'])
            images['trees/' + name] = os.path.join(ZONE, sp['file'])
            items.append({'kind': 'farm_tree_%d' % n, 'file': 'trees/' + name, 'x': x0, 'y': y0, 'w': w, 'h': h,
                          'foot': [x0 + fx, y0 + fy], 'sort_y': float(y0 + fy)})
            n += 1
            placed += 1
    return items, images


def build(map_only: bool = False) -> dict:
    """Places the whole farm from scratch: the targets, the fence ring around each field, the wheat, the soil under each
    field, and the water channel. The wheat sheets in assets/art/zone1b/farm/wheat/ are baked from this output (tools/bake_wheat.gd), so
    re-run the bake after any change here."""
    ground = Ground()
    existing = _existing_rects(os.path.join(ZONE, 'placements3d.json'))
    placer = Placer(ground, existing)
    rng = random.Random(7)
    items = []
    for kind, tx, ty in TARGETS:
        w, h = SIZES[kind]
        at = placer.place(w, h, tx, ty, tag='prop' if kind in SMALL_PROPS else None)
        if at is None:
            print('no room for %s near (%d, %d)' % (kind, tx, ty))
            continue
        x, y = at
        items.append({'kind': kind, 'file': FILES[kind], 'x': x, 'y': y, 'w': w, 'h': h,
                      'foot': [x + w / 2.0, y + h - 2.0], 'sort_y': float(y + h - 2)})
    # The fence ring goes before the wheat: it marks each field's paddock, and the clumps grow inside it.
    pieces = _fence_items(ground, placer, FIELDS + [YARD], 0)
    for it in pieces:
        placer.taken.append((it['x'], it['y'], it['x'] + it['w'], it['y'] + it['h']))
        placer.tags.append('fence')
    items += _fence_batch(pieces)
    items += _wheat_items(placer, rng, len(items), FIELDS)
    soil, soil_images = _soil_items(ground, placer, FIELDS, len(items))
    items += soil
    groves, tree_files = _grove_items(ground, placer, FIELDS, len(items))
    items += groves
    channel = _channel(ground, placer)
    brooks = [{'points': channel, 'width': 2}] if channel else []
    if map_only:
        _print_map(ground, placer, items)
    return {'items': items, 'fences': [], 'brooks': brooks, 'box_layout': list(BOX), 'scale': S,
            'fields': [{'kind': f.kind, 'at': [f.cx, f.cy], 'scale': f.scale, 'mirror': f.mirror, 'seed': f.seed}
                       for f in FIELDS],
            'soil_images': soil_images, 'tree_files': tree_files}


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
            if ground.sand_near[y, x]:
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
    soil_dir = os.path.join(OUT, 'soil')
    os.makedirs(soil_dir, exist_ok=True)
    for old in os.listdir(soil_dir):
        if old.endswith('.png'):
            os.remove(os.path.join(soil_dir, old))
    for path, img in out.pop('soil_images').items():
        img.save(os.path.join(OUT, path))
    os.makedirs(os.path.join(OUT, 'trees'), exist_ok=True)
    for path, src in out.pop('tree_files').items():
        Image.open(src).save(os.path.join(OUT, path))
    with open(os.path.join(OUT, 'farm.json'), 'w') as f:
        json.dump(out, f, indent=1)
    fence_n = sum(1 for it in out['items'] if it['kind'].startswith('farm_fence'))
    soil_n = sum(1 for it in out['items'] if it['kind'].startswith('farm_soil'))
    wheat_n = sum(1 for it in out['items'] if it['kind'].startswith('farm_wheat'))
    print('wrote farm.json:', len(out['items']), 'items,', fence_n, 'fence pieces,', soil_n, 'soil decals,', wheat_n, 'wheat clumps')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
