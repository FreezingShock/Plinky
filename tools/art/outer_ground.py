"""Outer map ground: island grass repeated past the old render edge (Larkmoor).

The painted ground (ground.png, ground_fg.png) and its runtime data (ground_n.png) only cover the scene render mask,
so the map's edges were flat, dark, unlit art. This paints the edges with grass taken from the island and gives them
the same flat terrain data as before, so the sun lights them evenly.

How the grass is laid out, so it does not repeat or reflect:
  - the edge is cut into PATCH-sized blocks, and each block takes one of several grass patches picked by a hash of
    its place. Nothing is mirrored, so no reflections.
  - four copies of that layout are offset by half a block, and blended with smooth weights that are zero on each
    copy's own block seams. That removes the straight lines at block edges.
  - the blend with the island's own art at the old edge is a soft band (EDGE_BLEND), also dithered.
  - every texel is a copy of an island texel (no averaged colours), so the palette stays exact.

Run once on the art as it was before this script; the mask is ground_h > 0 (heights are 0 outside the scene).
Re-running it on its own output would blend the edge with itself, so restore the files from git first:
    python tools/art/outer_ground.py assets/art/zone1b/larkmoor
"""
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

PATCH = 256                                   # texels per block
EDGE_BLEND = 24                               # blur radius of the blend at the old edge, texels
LIGHT = 166                                   # baked light for the edge, the island's median
GRASS_CODES = (100, 101)                      # plain grass ramps
# Five grass patches inside the island, each mostly green in the painted art (x, y of the top-left texel)
ORIGINS = np.array([(924, 596), (2076, 932), (1668, 980), (1140, 1100), (1932, 1148)])


BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], np.float32) / 16.0 + 1.0 / 32.0


def tiled(src, h, w):
    """The edge laid out in blocks, four offset copies chosen per texel by a Bayer dither (no averaged colours).

    Each copy takes its texel from a patch (see ORIGINS) chosen by the hash of its block. The copies are weighted so
    each one's own block seams have zero weight. A texel is taken from the copy its Bayer threshold lands on, so the
    colours stay exactly the island's palette and the seams turn into dither, the way the rest of the art blends.
    """
    xs = np.arange(w)
    ys = np.arange(h)
    bayer = np.tile(BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w]
    layers = []
    weights = []
    for oy in (0, PATCH // 2):
        for ox in (0, PATCH // 2):
            u = (xs + ox) % PATCH
            v = (ys + oy) % PATCH
            weight = (np.outer(np.sin(np.pi * v / PATCH) ** 2, np.sin(np.pi * u / PATCH) ** 2)).astype(np.float32)
            # the sin^2 phases above are for the (0, 0) copy; the half-block copies use the cos^2 phase
            if ox:
                weight = weight * 0 + (np.outer(np.sin(np.pi * v / PATCH) ** 2, np.cos(np.pi * u / PATCH) ** 2)).astype(np.float32)
            if oy:
                weight = weight * 0 + (np.outer(np.cos(np.pi * v / PATCH) ** 2, np.sin(np.pi * u / PATCH) ** 2)).astype(np.float32)
            if ox and oy:
                weight = (np.outer(np.cos(np.pi * v / PATCH) ** 2, np.cos(np.pi * u / PATCH) ** 2)).astype(np.float32)
            bx = (xs + ox) // PATCH
            by = (ys + oy) // PATCH
            k = ((bx[None, :] * 73856093) ^ (by[:, None] * 19349663)) % len(ORIGINS)
            sx = ORIGINS[k, 0] + u[None, :]
            sy = ORIGINS[k, 1] + v[:, None]
            layers.append(src[sy, sx])
            weights.append(weight)
    weights = np.stack(weights)
    weights = weights / np.maximum(weights.sum(axis=0), 1e-6)
    cum = np.cumsum(weights, axis=0)
    pick = (bayer[None] >= cum[:-1]).sum(axis=0)          # 0..3: the copy this texel dithers to
    layers = np.stack(layers)
    return np.take_along_axis(layers, pick[None, ..., None] if src.ndim == 3 else pick[None], axis=0)[0]


def main(folder):
    p = lambda name: os.path.join(folder, name)
    ground = np.array(Image.open(p('ground.png')).convert('RGB')).astype(np.float32)
    fg = np.array(Image.open(p('ground_fg.png')).convert('RGBA'))
    gn = np.array(Image.open(p('ground_n.png')).convert('RGBA'))
    gh = np.array(Image.open(p('ground_h.png')).convert('L'))
    h, w = gh.shape
    inside = gh > 0
    outside = ~inside

    soft = np.array(Image.fromarray((inside * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(EDGE_BLEND))).astype(np.float32) / 255.0
    tile_rgb = tiled(ground.astype(np.uint8), h, w)
    bayer = np.tile(BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w]
    keep = (soft >= bayer)[..., None]                   # the island's own art near the old edge, dithered out
    rgb = np.where(keep, ground.astype(np.uint8), tile_rgb).astype(np.uint8)
    Image.fromarray(rgb, 'RGB').save(p('ground.png'))
    Image.fromarray(np.dstack([rgb, fg[..., 3]]), 'RGBA').save(p('ground_fg.png'))

    gn[outside] = [128, 128, GRASS_CODES[0], LIGHT]   # flat terrain data: the sun lights it evenly, no relief
    Image.fromarray(gn, 'RGBA').save(p('ground_n.png'))
    print('edge texels:', int(outside.sum()))


LIGHT_RGB = (0xb7, 0xd9, 0x78)                # palette 4, the sway tips' colour (render/palettes.gd, Meadow)
# sway tips stay on palette 4 only (the life test and the runtime sway colour); tips on the warm and cool patches are moved or dropped
LIGHTS_RGB = (LIGHT_RGB,)
GRASS_RGB = ((0x5f, 0xa3, 0x6a), (0xb7, 0xd9, 0x78), (0x2f, 0x6b, 0x55),
             (0x7a, 0x7f, 0x45), (0x91, 0x96, 0x54), (0x9e, 0xa3, 0x5f), (0xaa, 0xb0, 0x61),
             (0x3c, 0x7a, 0x6a), (0x4b, 0x8f, 0x7a), (0x5e, 0xa8, 0x8a), (0x72, 0xbf, 0x9f))
SWAY_SPACING = 9                              # same spacing gen_life_anchors.py keeps between tips
PAD_CLEARANCE = 22                            # same clearance from pad rings
SNAP_RADIUS = 8                               # texels a tip may move to find palette 4 again


def snap_sway_tips(life_path, ground_rgb):
    """Move each sway tip that no longer sits on a palette 4 texel to the nearest one, or drop it.

    The blend at the old edge repaints some texels that held tips, so the tip list is repaired in place: only the
    "sway" block of the life JSON is rewritten, every other key keeps its text. A moved tip keeps grass below it,
    stays SWAY_SPACING from other tips and PAD_CLEARANCE from pads.
    """
    import json
    raw = open(life_path, encoding='utf-8').read()
    data = json.loads(raw)
    org = data.get('backdrop_origin', [0, 0])
    h, w = ground_rgb.shape[:2]
    lights = [np.array(c, np.uint8) for c in LIGHTS_RGB]
    grass = np.array(GRASS_RGB, np.uint8)

    def texel(x, y):
        return ground_rgb[y, x]

    def on_light(x, y):
        return 0 < x < w - 1 and 0 < y < h - 1 and any(np.array_equal(texel(x, y), l) for l in lights)

    def grass_below(x, y):
        return any(np.array_equal(texel(x, y + 1), g) for g in grass)

    pads = [(float(p[0]), float(p[1])) for p in data.get('pad_sites', [])]
    tips = [(int(a[0]), int(a[1])) for a in data.get('sway', [])]
    ok = [(x, y) for x, y in tips
          if 0 < x - org[0] < w - 1 and 0 < y - org[1] < h - 1 and on_light(x - org[0], y - org[1])]
    # tips use frame coordinates, the backdrop starts at backdrop_origin
    fixed = [(x - org[0], y - org[1]) for x, y in ok]
    bad = [(x, y) for x, y in tips if (x, y) not in set(ok)]
    kept = [(x - org[0], y - org[1]) for x, y in ok]
    moved = dropped = 0
    for x0, y0 in bad:
        tx, ty = x0 - org[0], y0 - org[1]
        best = None
        for r in range(SNAP_RADIUS + 1):
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    if max(abs(dx), abs(dy)) != r:
                        continue
                    nx, ny = tx + dx, ty + dy
                    if not on_light(nx, ny) or not grass_below(nx, ny):
                        continue
                    fx, fy = nx + org[0], ny + org[1]
                    if any((fx - px) ** 2 + (fy - py) ** 2 < PAD_CLEARANCE ** 2 for px, py in pads):
                        continue
                    if any((nx - kx) ** 2 + (ny - ky) ** 2 < SWAY_SPACING ** 2 for kx, ky in kept):
                        continue
                    best = (nx, ny)
                    break
                if best:
                    break
            if best:
                break
        if best:
            kept.append(best)
            moved += 1
        else:
            dropped += 1
    sway = [[x + org[0], y + org[1]] for x, y in kept]
    block = json.dumps(sway, indent=1).replace('\n', '\n ')
    start = raw.index('"sway": ')
    end = raw.index('"lights": ')
    out = raw[:start] + '"sway": ' + block + ',\n ' + raw[end:]
    open(life_path, 'w', encoding='utf-8').write(out)
    print('sway tips: %d kept as they were, %d moved to palette 4, %d dropped' % (len(ok), moved, dropped))


if __name__ == '__main__':
    main(sys.argv[1])
    if len(sys.argv) > 2:
        snap_sway_tips(sys.argv[2], np.array(Image.open(os.path.join(sys.argv[1], 'ground.png')).convert('RGB')))
