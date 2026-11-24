#!/usr/bin/env python3
"""Starting Clearing layout, option B (the open pad strip): applies to the baked zone 1 meadow data.

Run once on the committed meadow (run it again only after regenerating the meadow, which rebuilds these files):
  python3 tools/art/clearing_layout.py      then      python3 tools/art/gen_clearing_gardens.py

What it changes, and nothing else:
- placements3d.json: drops the rocks, crystals and bushes inside the pad strip, and the two lanterns nearest the camera.
- walkable.png: the ground under each dropped prop becomes walkable where it is grass or path (the walker can stand there).
- assets/art/zone1/cozy/cozy.json: drops one fence run, moves the fountain, moves two benches and the blanket onto the
  pad strip's rim, and re-places the redrawn props (tools/art/gen_cozy.py) by their ground foot. The stones,
  wheel, cottage, well, swing, campfire and wheat stay where they are. The fountain moves off the pad strip to the
  east rim (its sprite stays flat: its jet pillar is tied to the old sprite's size in world/cozy/cozy_props.gd).
Pads, the gate, the spawn point, the water and the flower fields' stat order are not touched."""
import json
import os

import numpy as np
from PIL import Image

import gen_cozy

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
MEADOW = os.path.join(ROOT, 'assets', 'art', 'zone1', 'meadow3d')
COZY = os.path.join(ROOT, 'assets', 'art', 'zone1', 'cozy')
OFFSET = (100, 60)                     # ground pixel = frame + OFFSET (placements3d.json bleed)
GLADE = (297.0, 181.0, 96.0, 62.0)     # centre and radii (frame texels) of the pad strip
FRONT_LANTERNS = ('lantern_041.png', 'lantern_042.png')
GRASS = {(0x5f, 0xa3, 0x6a), (0xb7, 0xd9, 0x78), (0x2f, 0x6b, 0x55)}
PATH = {(0xf2, 0xe6, 0xa0), (0xf6, 0xef, 0xd9)}
# the cozy prop moves: (kind, file, current foot) -> new foot; None drops the item
COZY_MOVES = [
    ('cozy_bench', 'bench.png', (247.0, 188.0), (236.0, 160.0)),
    ('cozy_bench', 'bench.png', (345.0, 222.0), (352.0, 214.0)),
    ('cozy_blanket', 'blanket.png', (439.0, 198.0), (386.0, 196.0)),
    ('cozy_fence', 'fence.png', (204.0, 152.0), None),
    ('cozy_fountain_basin', 'fountain_basin.png', (303.0, 165.0), (452.0, 236.0)),
]
# the redrawn static props, by file -> canvas factory
REDRAWN = {'bench.png': lambda: gen_cozy.bench(), 'blanket.png': lambda: gen_cozy.blanket(),
           'fence.png': lambda: gen_cozy.fence(), 'signpost.png': lambda: gen_cozy.signpost(),
           'stone_2.png': lambda: gen_cozy.stone(2)}


def in_glade(x: float, y: float) -> bool:
    cx, cy, rx, ry = GLADE
    return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 < 1.0


def patch_placements() -> list:
    path = os.path.join(MEADOW, 'placements3d.json')
    data = json.load(open(path))
    dropped = []
    keep = []
    for s in data['sprites']:
        drop = (s['kind'] in ('rock', 'crystals', 'bush') and in_glade(s['foot'][0], s['foot'][1])) or \
               (s['kind'] == 'lantern' and s['file'].split('/')[-1] in FRONT_LANTERNS)
        (dropped if drop else keep).append(s)
    data['sprites'] = keep
    with open(path, 'w') as f:
        json.dump(data, f, indent=1)
    print('placements: dropped %d props (%s)' % (len(dropped), ', '.join(sorted({d['kind'] for d in dropped}))))
    return dropped


def patch_walkable(dropped: list) -> None:
    path = os.path.join(MEADOW, 'walkable.png')
    wm = np.array(Image.open(path).convert('RGBA'))
    ground = np.array(Image.open(os.path.join(MEADOW, 'ground.png')).convert('RGB'))
    key = lambda c: (c[0] << 16) | (c[1] << 8) | c[2]
    ok = {key(c) for c in GRASS | PATH}
    gkey = (ground[:, :, 0].astype(np.int32) << 16) | (ground[:, :, 1].astype(np.int32) << 8) | ground[:, :, 2].astype(np.int32)
    walkable_ground = np.isin(gkey, list(ok))
    freed = 0
    for s in dropped:
        x0, y0 = int(s['x']) + OFFSET[0], int(s['y']) + OFFSET[1]
        x1, y1 = x0 + int(s['w']), y0 + int(s['h'])
        box = np.zeros(wm.shape[:2], bool)
        box[max(0, y0):y1, max(0, x0):x1] = True
        fill = box & walkable_ground & (wm[:, :, 0] == 0)
        wm[fill, :3] = 255
        freed += int(fill.sum())
    Image.fromarray(wm).save(path)
    print('walkable: freed %d texels' % freed)


def patch_cozy() -> None:
    path = os.path.join(COZY, 'cozy.json')
    data = json.load(open(path))
    items = []
    seen = set()
    moves = {(k, f, tuple(old)): new for k, f, old, new in COZY_MOVES}
    for it in data['items']:
        key = (it['kind'], it['file'], tuple(it['foot']))
        if key in seen:
            continue
        if key in moves:
            new = moves[key]
            if new is None:
                continue
            dx, dy = new[0] - it['foot'][0], new[1] - it['foot'][1]
            it['foot'] = list(new)
            it['x'] = int(round(it['x'] + dx))
            it['y'] = int(round(it['y'] + dy))
        items.append(it)
        seen.add(key)
    for it in items:
        if it['file'] in REDRAWN:
            cv = REDRAWN[it['file']]()
            ox, oy = cv.origin
            fx, fy = it['foot']
            it['x'] = int(round(fx - ox))
            it['y'] = int(round(fy - oy))
            it['w'], it['h'] = cv.w, cv.h
    data['items'] = items
    with open(path, 'w') as f:
        json.dump(data, f, indent=1)
    print('cozy: %d items' % len(items))


def main() -> int:
    dropped = patch_placements()
    patch_walkable(dropped)
    patch_cozy()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
