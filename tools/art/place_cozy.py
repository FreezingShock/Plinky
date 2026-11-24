#!/usr/bin/env python3
"""Places the cozy props (tools/art/gen_cozy.py) on the zone 1 meadow and writes assets/art/zone1/cozy/cozy.json.

Placement is deterministic (a fixed seed), so a rerun gives the same layout. A spot is accepted only when its
footprint is all base grass with a 2-texel margin, clear of the sand path, the cliff rim, the lake and pond,
the pads, the gate, the shrine, the walker's start, the meadow's own sprites and every cozy prop placed before it.
Coordinates are in the 640x360 frame (the same as placements3d.json); sprite x, y is the top-left texel.

Run: python3 tools/art/place_cozy.py   (after gen_cozy.py). Prints the chosen spots and an ASCII map to check."""
import json
import math
import os
import random
import sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
COZY = os.path.join(ROOT, 'assets', 'art', 'zone1', 'cozy')
MEADOW = os.path.join(ROOT, 'assets', 'art', 'zone1', 'meadow3d')
OFFSET = (100, 60)                    # ground.png texel (0, 0) sits at frame (-100, -60), as MeadowSites
FRAME_W, FRAME_H = 640, 360
SEED = 20261124
MARGIN = 2

GRASS_HEX = {'#5fa36a', '#2f6b55', '#b7d978', '#1f3b35'}   # grass: base, light, deep and the dithered shade; props stand only on these, inside the island mask
SAND_HEX = {'#f2e6a0', '#f6efd9'}               # the packed path
CLIFF_HEX = {'#c2784e'}                         # the rim and cliffs

SIZES = {}   # name -> (w, h), read from the PNGs


def hexof(c: tuple) -> str:
    return '#%02x%02x%02x' % c[:3]


def load_ground() -> dict:
    """Classes from ground.png. The island is the region reached from the walker's spawn without crossing the
    cliff rim (the sea beyond the rim shares the grass's shade colour, so colour alone cannot tell them apart)."""
    im = Image.open(os.path.join(MEADOW, 'ground.png')).convert('RGB')
    kind = [[0] * FRAME_W for _ in range(FRAME_H)]   # 0 off the island, 1 grass, 2 sand, 3 cliff
    rim = [[False] * FRAME_W for _ in range(FRAME_H)]
    for y in range(FRAME_H):
        for x in range(FRAME_W):
            gx, gy = x + OFFSET[0], y + OFFSET[1]
            if not (0 <= gx < im.width and 0 <= gy < im.height):
                continue
            h = hexof(im.getpixel((gx, gy)))
            if h in CLIFF_HEX:
                rim[y][x] = True
                kind[y][x] = 3
            elif h in SAND_HEX:
                kind[y][x] = 2
            elif h in GRASS_HEX:
                kind[y][x] = 1
    seed = (164, 262)                              # the walker's start, on the path
    island = [[False] * FRAME_W for _ in range(FRAME_H)]
    stack = [seed]
    island[seed[1]][seed[0]] = True
    while stack:
        x, y = stack.pop()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < FRAME_W and 0 <= ny < FRAME_H and not island[ny][nx] and not rim[ny][nx] and kind[ny][nx] != 0:
                island[ny][nx] = True
                stack.append((nx, ny))
    cls = [[0] * FRAME_W for _ in range(FRAME_H)]
    for y in range(FRAME_H):
        for x in range(FRAME_W):
            if island[y][x]:
                cls[y][x] = kind[y][x]
    return {'cls': cls}


def block_meadow(blocked: list) -> None:
    """Marks the meadow's own placed things: sprites, pads, gate, shrine, spawn, lake and pond."""
    data = json.load(open(os.path.join(MEADOW, 'placements3d.json')))
    for s in data['sprites']:
        # Only the foot blocks ground: a tree's canopy sits above the spot, and a bench can stand under it.
        fx, fy = float(s['foot'][0]), float(s['foot'][1])
        for y in range(int(fy) - 4, int(fy) + 4):
            for x in range(int(fx) - 6, int(fx) + 7):
                mark(blocked, x, y)
    for a in data['anchors']:
        kind = a['kind']
        sx, sy = float(a['sx']), float(a['sy'])
        if kind in ('pad', 'gate', 'shrine', 'player_spawn'):
            r = {'pad': 20, 'gate': 18, 'player_spawn': 18, 'shrine': 14}[kind]   # the meadow thread's clearances
            for y in range(int(sy) - r, int(sy) + r + 1):
                for x in range(int(sx) - r, int(sx) + r + 1):
                    mark(blocked, x, y)
        elif kind == 'water':
            rx, ry = float(a['rx']), float(a['ry'])
            for y in range(int(sy - ry * 1.3) - 3, int(sy + ry * 1.3) + 4):
                for x in range(int(sx - rx * 1.3) - 3, int(sx + rx * 1.3) + 4):
                    if ((x - sx) / (rx * 1.15)) ** 2 + ((y - sy) / (ry * 1.15)) ** 2 <= 1.0:
                        mark(blocked, x, y)
    return data


def mark(blocked: list, x: int, y: int) -> None:
    if 0 <= x < FRAME_W and 0 <= y < FRAME_H:
        blocked[y][x] = True


def fits(ground: dict, blocked: list, x0: int, y0: int, w: int, h: int, base: int = 0) -> bool:
    """True when a footprint can stand here. The bottom `base` rows (what stands on the ground; 0 means the whole
    height) must be grass. Nothing blocked may touch the box within MARGIN texels. Sand, cliff and sea keep a
    3-texel band clear around the base, so the walk line and the rim stay clear. A tall prop's upper rows may
    overhang the grass's edge."""
    cls = ground['cls']
    base = h if base <= 0 else min(base, h)
    base_top = y0 + h - base
    for y in range(y0 - MARGIN, y0 + h + MARGIN):
        for x in range(x0 - MARGIN, x0 + w + MARGIN):
            if not (0 <= x < FRAME_W and 0 <= y < FRAME_H):
                return False
            if blocked[y][x]:
                return False
    for y in range(base_top, y0 + h):
        for x in range(x0, x0 + w):
            if cls[y][x] != 1:
                return False
    for y in range(base_top - 3, y0 + h + 3):
        for x in range(x0 - 3, x0 + w + 3):
            if not (0 <= x < FRAME_W and 0 <= y < FRAME_H):
                return False
            if cls[y][x] in (0, 2, 3):
                return False
    return True


def take(blocked: list, x0: int, y0: int, w: int, h: int) -> None:
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            blocked[y][x] = True


class Placer:
    def __init__(self, ground: dict, blocked: list):
        self.ground = ground
        self.blocked = blocked
        self.rng = random.Random(SEED)
        self.out: list = []

    def near(self, cx: float, cy: float, radius: float):
        """Every texel within `radius` of (cx, cy), nearest first, ties broken by the seeded rng (so the layout is
        stable from run to run). The first spot whose footprint fits wins."""
        r = int(radius)
        cand = []
        for y in range(int(cy) - r, int(cy) + r + 1):
            for x in range(int(cx) - r, int(cx) + r + 1):
                d = math.hypot(x - cx, y - cy)
                if d <= radius:
                    cand.append((d + self.rng.uniform(0.0, 1.5), x, y))
        cand.sort()
        for _, x, y in cand:
            yield x, y

    def put(self, kind: str, name: str, cx: float, cy: float, radius: float, file: str = '', **extra):
        w, h = SIZES[name]
        for x, y in self.near(cx, cy, radius * 3.0):   # the target is a hint; a nearby open spot is fine
            x0, y0 = x - w // 2, y - h + 1
            if fits(self.ground, self.blocked, x0, y0, w, h, base=max(4, h // 3)):
                take(self.blocked, x0, y0, w, h)
                e = {'kind': 'cozy_' + kind, 'file': file or name + '.png', 'x': x0, 'y': y0, 'w': w, 'h': h,
                     'foot': [x0 + w / 2.0, float(y0 + h - 1)]}
                e.update(extra)
                self.out.append(e)
                return e
        print('no room for %s near (%d, %d)' % (kind, cx, cy), file=sys.stderr)
        return None

    def put_row(self, kind: str, name: str, cx: float, cy: float, radius: float, count: int) -> None:
        """A line of `count` segments end to end (fence runs), starting at the first spot where all of them fit."""
        w, h = SIZES[name]
        for x, y in self.near(cx, cy, radius * 3.0):
            x0, y0 = x - (count * w) // 2, y - h + 1
            if all(fits(self.ground, self.blocked, x0 + i * w, y0, w, h, base=4) for i in range(count)):
                for i in range(count):
                    take(self.blocked, x0 + i * w, y0, w, h)
                    self.out.append({'kind': 'cozy_' + kind, 'file': name + '.png', 'x': x0 + i * w, 'y': y0, 'w': w, 'h': h,
                                     'foot': [x0 + i * w + w / 2.0, float(y0 + h - 1)]})
                return
        print('no room for a %s run near (%d, %d)' % (kind, cx, cy), file=sys.stderr)

    def put_wheat(self, cx: float, cy: float, radius: float, cols: int, rows: int) -> None:
        """A block of wheat patches (48 x 16 each). Neighbours start their gust frame a step apart so the wave rolls on."""
        w, h = SIZES['wheat_sheet_frame']
        start = None
        for x, y in self.near(cx, cy, radius * 3.0):
            if all(fits(self.ground, self.blocked, x + c * w, y + r * h, w, h, base=6) for r in range(rows) for c in range(cols)):
                start = (x, y)
                break
        if start is None:
            print('no room for wheat near (%d, %d)' % (cx, cy), file=sys.stderr)
            return
        for r in range(rows):
            for c in range(cols):
                x0, y0 = start[0] + c * w, start[1] + r * h
                take(self.blocked, x0, y0, w, h)
                self.out.append({'kind': 'cozy_wheat', 'file': 'wheat_sheet.png', 'x': x0, 'y': y0, 'w': w, 'h': h,
                                 'foot': [x0 + w / 2.0, float(y0 + h - 1)], 'phase': (c + 2 * r) % 8})

    def brook(self, cx: float, cy: float, radius: float, length: int) -> list:
        """A short stream: a walk from a grass spot in a random direction, stopping at anything that is not grass.
        Returns the points (frame coordinates) and marks a 3-texel band as taken."""
        for x, y in self.near(cx, cy, radius * 3.0):
            if not fits(self.ground, self.blocked, x - 3, y - 3, 6, 6):
                continue
            ang = self.rng.uniform(0.0, math.tau)
            pts = [(x, y)]
            cls = self.ground['cls']
            for _ in range(length):
                ang += self.rng.uniform(-0.25, 0.25)
                nx = pts[-1][0] + math.cos(ang) * 2.0
                ny = pts[-1][1] + math.sin(ang) * 2.0
                ix, iy = int(round(nx)), int(round(ny))
                if not (2 <= ix < FRAME_W - 2 and 2 <= iy < FRAME_H - 2):
                    break
                if cls[iy][ix] != 1 or self.blocked[iy][ix]:
                    break
                pts.append((ix, iy))
            if len(pts) < 12:
                continue
            for px, py in pts:
                for dy in range(-2, 3):
                    for dx in range(-2, 3):
                        mark(self.blocked, px + dx, py + dy)
            return pts
        print('no room for a brook near (%d, %d)' % (cx, cy), file=sys.stderr)
        return []


def sizes() -> None:
    for name in ('bench', 'blanket', 'swing_frame', 'swing_seat', 'cottage', 'fence', 'signpost',
                 'campfire_ring', 'well', 'fountain_basin', 'stone_0', 'stone_1', 'stone_2'):
        im = Image.open(os.path.join(COZY, name + '.png'))
        SIZES[name] = (im.width, im.height)
    SIZES['wheat_sheet_frame'] = (48, 16)
    SIZES['wheel_frame'] = (18, 18)
    SIZES['fence'] = SIZES['fence']


def ascii_map(ground: dict, blocked: list, entries: list, brooks: list) -> str:
    grid = [['.' if ground['cls'][y][x] == 1 else ('s' if ground['cls'][y][x] == 2 else
             ('c' if ground['cls'][y][x] == 3 else ' ')) for x in range(FRAME_W)] for y in range(FRAME_H)]
    for y in range(FRAME_H):
        for x in range(FRAME_W):
            if blocked[y][x] and grid[y][x] == '.':
                grid[y][x] = 'x'
    marks = {'cozy_bench': 'B', 'blanket': 'P', 'swing_frame': 'S', 'cottage': 'H', 'fence': 'F', 'signpost': 'T',
             'campfire_ring': 'O', 'well': 'W', 'fountain_basin': 'U', 'wheat': 'w', 'wheel': 'R', 'stone': 'o'}
    for e in entries:
        ch = marks.get(e['kind'], '?')
        for y in range(e['y'], e['y'] + e['h']):
            for x in range(e['x'], e['x'] + e['w']):
                if 0 <= x < FRAME_W and 0 <= y < FRAME_H:
                    grid[y][x] = ch
    for pts in brooks:
        for x, y in pts:
            grid[y][x] = '~'
    rows = []
    for y in range(0, FRAME_H, 6):
        rows.append('%3d ' % y + ''.join(grid[y][x] for x in range(0, FRAME_W, 4)))
    return '\n'.join(rows)


def main() -> int:
    sizes()
    ground = load_ground()
    blocked = [[False] * FRAME_W for _ in range(FRAME_H)]
    meadow = block_meadow(blocked)
    pl = Placer(ground, blocked)

    # Named anchors from the meadow data: the lake, the pond and the cottage's meadow (the open grass by the lake).
    water = [a for a in meadow['anchors'] if a['kind'] == 'water']
    lake = next(a for a in water if a['name'] == 'lake')
    pond = next(a for a in water if a['name'] == 'pond')
    lx, ly = float(lake['sx']), float(lake['sy'])
    px, py = float(pond['sx']), float(pond['sy'])

    # The big open meadow is north-east of the path and south of the gate. Each group is placed as it is
    # read: the largest pieces first, so the small ones fill the gaps.
    pl.put('cottage', 'cottage', 470.0, 120.0, 40.0)
    pl.put('well', 'well', 445.0, 150.0, 30.0)
    pl.put('fountain_basin', 'fountain_basin', 300.0, 150.0, 40.0)
    pl.put_wheat(150.0, 168.0, 60.0, 2, 1)
    pl.put_wheat(170.0, 128.0, 60.0, 1, 2)
    pl.put('swing_frame', 'swing_frame', 232.0, 140.0, 40.0)
    pl.put('campfire_ring', 'campfire_ring', 120.0, 150.0, 40.0)
    pl.put('bench', 'bench', lx + 30.0, ly - 60.0, 20.0)
    pl.put('bench', 'bench', lx - 46.0, ly - 40.0, 16.0)
    pl.put('bench', 'bench', px + 28.0, py + 14.0, 14.0)
    pl.put('blanket', 'blanket', lx + 4.0, ly - 46.0, 14.0)
    pl.put('signpost', 'signpost', 340.0, 118.0, 24.0)
    pl.put('signpost', 'signpost', 105.0, 118.0, 24.0)
    for _ in range(2):
        pl.put('stone', 'stone_%d' % pl.rng.randrange(3), px + 40.0, py + 22.0, 14.0)
    brooks = [pl.brook(px + 52.0, py + 30.0, 16.0, 46)]
    if brooks[0]:
        sx, sy = brooks[0][0]
        pl.put('wheel', 'wheel_frame', sx - 14.0, sy + 2.0, 30.0, file='wheel_sheet.png')
    pl.put_row('fence', 'fence', 196.0, 150.0, 60.0, 2)
    entries = pl.out
    manifest = {
        'note': 'Written by tools/art/place_cozy.py. Frame coordinates (640x360); x, y is the top-left texel. '
                'kind picks the behaviour in world/cozy/cozy_props.gd. Rerun the placer to change the layout.',
        'items': entries,
        'brooks': [{'points': [[x, y] for x, y in pts], 'width': 3} for pts in brooks if pts],
    }
    with open(os.path.join(COZY, 'cozy.json'), 'w') as f:
        json.dump(manifest, f, indent=1)
        f.write('\n')
    print(ascii_map(ground, blocked, entries, [p for p in brooks if p]))
    print('%d items, %d brook(s)' % (len(entries), len([p for p in brooks if p])))
    return 0


if __name__ == '__main__':
    sys.exit(main())
