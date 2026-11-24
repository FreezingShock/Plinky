#!/usr/bin/env python3
"""Plinky zone 1 world life: writes world/meadow_life.json from the meadow backdrop and its anchors.

Two placement formats are read:
  flat   world/meadow_placements.json (the 2D meadow on main): pads, plus props named lantern and shrine.
  3d     assets/art/zone1/meadow3d/placements3d.json (PR #4): anchors of kind pad, shrine, gate, and
         optionally lantern (sprite kind) and water (anchor kind). Its ground sits at bleed.ground_offset.

Output (all positions in the 640x360 frame):
  sway     grass tips, palette 4 texels with grass below, that the ground layer flicks in a wind wave
  lights   lantern and shrine glow centres
  water    list of water ellipses {name, x, y, rx, ry} for sparkles. Taken from the anchors of kind water when
           the placements have any, otherwise the default cove (water_source "default"). The radii are
           bounding ellipses: the runtime keeps only sparkles on water texels.
  pads     ready pad centres (idle shimmer)
  drift    box that pollen, fireflies and butterflies wander in, from the sway tips
  backdrop_origin  where the backdrop's texel (0, 0) sits in the frame, so the runtime reads the right texels
  flowers    flower spots for butterflies: grass with blossom texels (palette 5 or 7) that are not a sand path,
             clustered by cell, kept off water and pads
  pad_sites  every pad centre, ready or not, so critters can keep off the pads (pads holds only the ready ones)

Usage:
  python3 tools/art/gen_life_anchors.py                       # main's 2D meadow
  python3 tools/art/gen_life_anchors.py --backdrop B --placements P [--out O]
  python3 tools/art/gen_life_anchors.py --backdrop B --placements P --out O --add-keys [--farm assets/art/zone1b/farm/farm.json]   # only flowers, pad_sites and the farm keys
Needs Pillow. Deterministic (fixed seed): the JSON only changes when the art or placements change."""
import argparse, json, os, random

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
DEFAULT_BACKDROP = os.path.join(ROOT, "assets/art/zone1/meadow_backdrop.png")
DEFAULT_PLACEMENTS = os.path.join(ROOT, "world/meadow_placements.json")
DEFAULT_OUT = os.path.join(ROOT, "world/meadow_life.json")

# Palette index -> colour, from render/palettes.gd (Meadow Tally). Index 4 = light, 3 = base, 2 = deep.
PAL = {
    0: (0x14, 0x16, 0x1c), 1: (0x1f, 0x3b, 0x35), 2: (0x2f, 0x6b, 0x55), 3: (0x5f, 0xa3, 0x6a),
    4: (0xb7, 0xd9, 0x78), 5: (0xf2, 0xe6, 0xa0), 6: (0xc2, 0x78, 0x4e), 7: (0xf6, 0xef, 0xd9),
}
# Fallback water cove, from gen_meadow.py WATER(x, y): centre (478, 270), radii 82 x 36.
DEFAULT_COVE = (478.0, 270.0, 82.0, 36.0)
GRASS_BOUNDS = (30, 100, 610, 340)   # x0, y0, x1, y1 in the frame: where tips may go
SWAY_COUNT = 120
SWAY_SPACING = 9                      # minimum texel distance between tips
PAD_CLEARANCE = 22                    # keep sway tips off the pad rings
DRIFT_INSET = 12                      # drift box is the tips' bounding box, pulled in by this
FLOWER_CELL = 24                      # texels per flower cell
FLOWER_MIN = 8                        # qualifying texels a cell needs before it counts as a flower spot
FLOWER_MAX = 240                      # the strongest spots are kept when there are more
FLOWER_WINDOW = 4                     # texel radius of the window that tests grass and blossom (9 x 9)


def nearest_index(rgb):
    return min(PAL, key=lambda i: sum((a - b) ** 2 for a, b in zip(PAL[i], rgb)))


def load_placements(path):
    d = json.load(open(path))
    out = {"pads": [], "pad_sites": [], "lights": [], "water": [], "origin": (0, 0), "format": "flat"}
    if "anchors" in d:
        out["format"] = "3d"
        bleed = d.get("bleed", {})
        off = bleed.get("ground_offset", [0, 0])
        out["origin"] = (int(off[0]), int(off[1]))
        for a in d["anchors"]:
            if a["kind"] == "pad":
                out["pads"].append((a["sx"], a["sy"], a["state"]))
                out["pad_sites"].append((a["sx"], a["sy"]))
            elif a["kind"] == "shrine":
                out["lights"].append({"x": a["sx"], "y": a["sy"] - 18, "r": 10, "kind": "shrine"})
            elif a["kind"] == "water":
                out["water"].append({"name": a.get("name", "water"), "x": a["sx"], "y": a["sy"],
                                     "rx": a["rx"], "ry": a["ry"]})
        for s in d.get("sprites", []):
            if s.get("kind") == "lantern":
                out["lights"].append({"x": s["x"], "y": s["y"] - 12, "r": 9, "kind": "lantern"})
    else:
        for p in d["pads"]:
            out["pads"].append((p["x"], p["y"], p["state"]))
            out["pad_sites"].append((p["x"], p["y"]))
        for p in d["props"]:
            if p["name"] == "lantern":
                out["lights"].append({"x": p["x"], "y": p["y"] - 12, "r": 9, "kind": "lantern"})
            elif p["name"] == "shrine":
                out["lights"].append({"x": p["x"], "y": p["y"] - 18, "r": 10, "kind": "shrine"})
    return out


def flower_spots(im, ox, oy, water, pad_sites):
    """Flower spots in frame coordinates. A texel is blossom when it is palette 5 or 7 and its window is mostly grass
    (palette 3 or 4) with little blossom around it: that leaves flower beds and verges, and drops the sand path, which
    is dithered in the same two colours but sits inside a band of them. Each cell with enough such texels gives one
    spot at their centre. Deterministic: no random numbers."""
    w, h = im.size
    cache: dict = {}
    grass = bytearray(w * h)
    bloom = bytearray(w * h)
    i = 0
    for rgb in im.getdata():
        idx = cache.get(rgb)
        if idx is None:
            idx = nearest_index(rgb)
            cache[rgb] = idx
        if idx in (3, 4):
            grass[i] = 1
        elif idx in (5, 7):
            bloom[i] = 1
        i += 1
    W1 = w + 1
    g_sum = [0] * ((w + 1) * (h + 1))
    b_sum = [0] * ((w + 1) * (h + 1))
    for y in range(h):
        g_row = 0
        b_row = 0
        for x in range(w):
            g_row += grass[y * w + x]
            b_row += bloom[y * w + x]
            g_sum[(y + 1) * W1 + x + 1] = g_sum[y * W1 + x + 1] + g_row
            b_sum[(y + 1) * W1 + x + 1] = b_sum[y * W1 + x + 1] + b_row

    def window(sums: list, x0: int, y0: int, x1: int, y1: int) -> int:
        return sums[y1 * W1 + x1] - sums[y0 * W1 + x1] - sums[y1 * W1 + x0] + sums[y0 * W1 + x0]

    cells: dict = {}
    for y in range(h):
        for x in range(w):
            if not bloom[y * w + x]:
                continue
            x0, y0 = max(x - FLOWER_WINDOW, 0), max(y - FLOWER_WINDOW, 0)
            x1, y1 = min(x + FLOWER_WINDOW + 1, w), min(y + FLOWER_WINDOW + 1, h)
            area = float((x1 - x0) * (y1 - y0))
            if window(g_sum, x0, y0, x1, y1) / area <= 0.45 or window(b_sum, x0, y0, x1, y1) / area >= 0.35:
                continue
            fx, fy = x + ox, y + oy
            key = (fx // FLOWER_CELL, fy // FLOWER_CELL)
            acc = cells.setdefault(key, [0, 0.0, 0.0])
            acc[0] += 1
            acc[1] += fx
            acc[2] += fy
    spots = []
    for n, sx, sy in cells.values():
        if n < FLOWER_MIN:
            continue
        cx, cy = sx / n, sy / n
        if any((cx - px) ** 2 + (cy - py) ** 2 < PAD_CLEARANCE ** 2 for px, py in pad_sites):
            continue
        if any(((cx - wb["x"]) ** 2) / (wb["rx"] ** 2) + ((cy - wb["y"]) ** 2) / (wb["ry"] ** 2) < 1.2 for wb in water):
            continue
        spots.append((n, round(cx), round(cy)))
    spots.sort(key=lambda t: (-t[0], t[2], t[1]))
    spots = spots[:FLOWER_MAX]
    spots.sort(key=lambda t: (t[2], t[1]))
    return [[x, y] for _, x, y in spots]


def main() -> None:
    global GRASS_BOUNDS, SWAY_COUNT
    from PIL import Image

    ap = argparse.ArgumentParser()
    ap.add_argument("--backdrop", default=DEFAULT_BACKDROP)
    ap.add_argument("--placements", default=DEFAULT_PLACEMENTS)
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--bounds", default="", help="x0,y0,x1,y1 in the frame where tips may go (default: the meadow's)")
    ap.add_argument("--sway-count", type=int, default=SWAY_COUNT)
    ap.add_argument("--add-keys", action="store_true",
                    help="only write flowers and pad_sites into the existing --out file, leaving every other key as it is")
    ap.add_argument("--farm", default="",
                    help="with --add-keys: a farm.json. Its yard box goes in as 'farm' and its prop rects as 'farm_items' "
                         "(chickens keep off the props)")
    args = ap.parse_args()
    if args.bounds:
        GRASS_BOUNDS = tuple(int(v) for v in args.bounds.split(","))
    SWAY_COUNT = args.sway_count

    im = Image.open(args.backdrop).convert("RGB")
    w, h = im.size
    pix = im.load()
    cache = {}

    def index_at(tx, ty):
        """Palette index of a backdrop texel, or None outside the backdrop."""
        if not (0 <= tx < w and 0 <= ty < h):
            return None
        rgb = pix[tx, ty]
        if rgb not in cache:
            cache[rgb] = nearest_index(rgb)
        return cache[rgb]

    pl = load_placements(args.placements)
    ox, oy = pl["origin"]
    ready_pads = [(x, y) for x, y, s in pl["pads"] if s == "ready"]

    if pl["water"]:
        water = pl["water"]
        water_source = "anchor"
    else:
        water = [{"name": "cove", "x": DEFAULT_COVE[0], "y": DEFAULT_COVE[1],
                  "rx": DEFAULT_COVE[2], "ry": DEFAULT_COVE[3]}]
        water_source = "default"
        print("note: placements have no water anchor, using the default cove")

    def in_water(x: int, y: int) -> bool:
        for wb in water:
            if ((x - wb["x"]) ** 2) / (wb["rx"] ** 2) + ((y - wb["y"]) ** 2) / (wb["ry"] ** 2) < 1.2:
                return True
        return False

    def near_pad(x: int, y: int) -> bool:
        return any((x - qx) ** 2 + (y - qy) ** 2 < PAD_CLEARANCE ** 2 for qx, qy in ready_pads)

    x0, y0, x1, y1 = GRASS_BOUNDS
    candidates = []
    for y in range(max(y0, 1), min(y1, h + oy - 1)):
        for x in range(max(x0, 1), min(x1, w + ox - 1)):
            if index_at(x - ox, y - oy) != 4:
                continue
            below = index_at(x - ox, y + 1 - oy)
            above = index_at(x - ox, y - 1 - oy)
            if below not in (2, 3) or above not in (2, 3, 4):
                continue
            if in_water(x, y) or near_pad(x, y):
                continue
            candidates.append((x, y))

    rnd = random.Random(7)
    rnd.shuffle(candidates)
    picked: list[tuple[int, int]] = []
    taken: set[tuple[int, int]] = set()
    for x, y in candidates:
        if len(picked) >= SWAY_COUNT:
            break
        cell = (x // SWAY_SPACING, y // SWAY_SPACING)
        if any((cell[0] + dx, cell[1] + dy) in taken for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
            continue
        taken.add(cell)
        picked.append((x, y))
    picked.sort(key=lambda p: (p[1], p[0]))

    if picked:
        xs = [p[0] for p in picked]
        ys = [p[1] for p in picked]
        dx0, dy0 = min(xs) + DRIFT_INSET, min(ys) + DRIFT_INSET
        drift = [dx0, dy0, max(xs) - DRIFT_INSET - dx0, max(ys) - DRIFT_INSET - dy0]
    else:
        drift = [34, 104, 572, 226]

    flowers = flower_spots(im, ox, oy, water, pl["pad_sites"])
    data = {
        "format": pl["format"],
        "size": [w + ox, h + oy] if (ox, oy) != (-100, -60) else [640, 360],
        "backdrop_origin": [ox, oy],
        "sway": [[x, y] for x, y in picked],
        "lights": pl["lights"],
        "water": water,
        "water_source": water_source,
        "pads": [[x, y] for x, y in ready_pads],
        "drift": drift,
        "flowers": flowers,
        "pad_sites": [[x, y] for x, y in pl["pad_sites"]],
    }
    if args.add_keys:
        data = json.load(open(args.out))
        data["flowers"] = flowers
        data["pad_sites"] = [[x, y] for x, y in pl["pad_sites"]]
        if args.farm:
            fm = json.load(open(args.farm))
            cx, cy, bw, bh = fm["box_layout"]
            s = float(fm["scale"])
            data["farm"] = [[(cx - bw / 2) * s, (cy - bh / 2) * s, bw * s, bh * s]]
            data["farm_items"] = [[it["x"], it["y"], it["w"], it["h"]] for it in fm["items"]]
    with open(args.out, "w") as f:
        json.dump(data, f, indent=1)
        f.write("\n")
    print(f"wrote {args.out}: {len(picked)} sway tips, {len(pl['lights'])} lights, "
          f"{len(ready_pads)} ready pads, {len(water)} water bodies ({water_source}), drift {drift}, "
          f"{len(flowers)} flower spots")


if __name__ == "__main__":
    main()
