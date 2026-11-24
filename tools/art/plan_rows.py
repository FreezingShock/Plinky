#!/usr/bin/env python3
"""Plans the Larkmoor pad rows: each row is an offset curve PARALLEL to a path, a few texels off its edge on the grass side.
Prints, for every row, the path, side, start arc length and offset that tools/art/larkmoor_layout.py's ROWS table holds.
Run after gen_larkmoor.py (it reads the baked ground):  python3 tools/art/plan_rows.py
Needs Pillow and numpy."""
import math, os, sys
import numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import larkmoor_layout as L

ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
GROUND = os.path.join(ROOT, 'assets', 'art', 'zone1b', 'larkmoor', 'ground.png')
GRASS = {(0x5f, 0xa3, 0x6a), (0xb7, 0xd9, 0x78), (0x2f, 0x6b, 0x55)}
OFF, GAP = L.ROW_OFFSET, L.ROW_GAP

def load():
    g = np.array(Image.open(GROUND).convert('RGB'))
    key = g[:, :, 0].astype(np.int32) << 16 | g[:, :, 1].astype(np.int32) << 8 | g[:, :, 2].astype(np.int32)
    m = np.zeros(key.shape, bool)
    for c in GRASS: m |= key == (c[0] << 16 | c[1] << 8 | c[2])
    return m

def grass_frac(m, x, y, r):
    h, w = m.shape
    x0, x1, y0, y1 = int(max(0, x - r)), int(min(w, x + r)), int(max(0, y - r / 2)), int(min(h, y + r / 2))
    if x1 <= x0 or y1 <= y0: return 0.0
    return float(m[y0:y1, x0:x1].mean())

def main():
    m = load()
    farm = [v * L.S for v in L.FARM_BOX]
    taken = [tuple(p) for d in L.DISTRICTS for p in []]
    out = []
    for name, (pi, side_hint, n, near) in L.ROW_PLAN.items():
        best = None
        for pidx in pi:
            for side in (1, -1):
                if side_hint and side != side_hint: continue
                tot = L.path_length_uv(pidx)
                s0 = tot - (n - 1) * GAP - 6.0 if name == 'starbloom_w' else 0.0   # the Westmere trail must end at its last plate
                while s0 <= tot - (n - 1) * GAP:
                    pads = L.row_pads(pidx, s0, side, n)
                    if pads and not any(abs(a[0] - b[0]) < 32 and abs(a[1] - b[1]) < 17 for a, b in zip(pads, pads[1:])) and all(L.PLAY[0] + 30 < p[0] < L.PLAY[2] - 30 and L.PLAY[1] + 30 < p[1] < L.PLAY[3] - 30 for p in pads):
                        if all(m[int(p[1]), int(p[0])] and L.path_gap(p) >= 26.0 for p in pads) and not any(farm[0] <= p[0] <= farm[2] and farm[1] <= p[1] <= farm[3] for p in pads):
                            sep = min([math.hypot(p[0] - q[0], p[1] - q[1]) for p in pads for q in taken] or [999])
                            if sep >= 100 and all(math.hypot(p[0] - near[0] * L.S, p[1] - near[1] * L.S) <= near[2] * L.S for p in pads):
                                cx = sum(p[0] for p in pads) / n; cy = sum(p[1] for p in pads) / n
                                fr = grass_frac(m, cx, cy, 120)
                                gate = min(math.hypot(p[0] - g[0], p[1] - g[1]) for p in pads for g in (L.SPAWN, L.HOLLOW_GATE, L.EMBER_GATE))
                                lm = min([math.hypot(p[0] - l['at'][0], p[1] - l['at'][1]) for p in pads for l in L.LANDMARKS] or [999])
                                sc = fr - (0.4 if gate < 60 else 0) - (0.4 if lm < 50 else 0)
                                if best is None or sc > best[0]: best = (sc, pidx, s0, side, pads)
                    s0 += 6.0
                    if name == 'starbloom_w': break
        print(name, '->', None if best is None else (round(best[0], 2), best[1], round(best[2]), best[3], best[4][0], best[4][-1]))
        if best: taken += best[4]; out.append((name, best))
    return out

if __name__ == '__main__':
    main()
