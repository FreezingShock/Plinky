#!/usr/bin/env python3
"""Plinky zone 1 world life: writes world/meadow_life.json from the meadow backdrop and its anchors.

Two placement formats are read:
  flat   world/meadow_placements.json (the 2D meadow on main): pads, plus props named lantern and shrine.
  3d     assets/art/zone1/meadow3d/placements3d.json (PR #4): anchors of kind pad, shrine, gate, and
         optionally lantern (sprite kind) and water (anchor kind). Its ground sits at bleed.ground_offset.

Output (all positions in the 640x360 frame):
  sway     grass tips, palette 4 texels with grass below, that the ground layer flicks in a wind wave
  lights   lantern and shrine glow centres
  water    the cove ellipse for sparkles. Taken from an anchor of kind water when the placements have one,
           otherwise the default cove (logged as water_source "default")
  pads     ready pad centres (idle shimmer)
  drift    box that pollen, fireflies and butterflies wander in, from the sway tips
  backdrop_origin  where the backdrop's texel (0, 0) sits in the frame, so the runtime reads the right texels

Usage:
  python3 tools/art/gen_life_anchors.py                       # main's 2D meadow
  python3 tools/art/gen_life_anchors.py --backdrop B --placements P [--out O]
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


def nearest_index(rgb):
    return min(PAL, key=lambda i: sum((a - b) ** 2 for a, b in zip(PAL[i], rgb)))


def load_placements(path):
    d = json.load(open(path))
    out = {"pads": [], "lights": [], "water": None, "origin": (0, 0), "format": "flat"}
    if "anchors" in d:
        out["format"] = "3d"
        bleed = d.get("bleed", {})
        off = bleed.get("ground_offset", [0, 0])
        out["origin"] = (int(off[0]), int(off[1]))
        for a in d["anchors"]:
            if a["kind"] == "pad":
                out["pads"].append((a["sx"], a["sy"], a["state"]))
            elif a["kind"] == "shrine":
                out["lights"].append({"x": a["sx"], "y": a["sy"] - 18, "r": 10, "kind": "shrine"})
            elif a["kind"] == "water":
                out["water"] = (a["sx"], a["sy"], a["rx"], a["ry"])
        for s in d.get("sprites", []):
            if s.get("kind") == "lantern":
                out["lights"].append({"x": s["x"], "y": s["y"] - 12, "r": 9, "kind": "lantern"})
    else:
        for p in d["pads"]:
            out["pads"].append((p["x"], p["y"], p["state"]))
        for p in d["props"]:
            if p["name"] == "lantern":
                out["lights"].append({"x": p["x"], "y": p["y"] - 12, "r": 9, "kind": "lantern"})
            elif p["name"] == "shrine":
                out["lights"].append({"x": p["x"], "y": p["y"] - 18, "r": 10, "kind": "shrine"})
    return out


def main() -> None:
    from PIL import Image

    ap = argparse.ArgumentParser()
    ap.add_argument("--backdrop", default=DEFAULT_BACKDROP)
    ap.add_argument("--placements", default=DEFAULT_PLACEMENTS)
    ap.add_argument("--out", default=DEFAULT_OUT)
    args = ap.parse_args()

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

    if pl["water"] is not None:
        cx, cy, rx, ry = pl["water"]
        water_source = "anchor"
    else:
        cx, cy, rx, ry = DEFAULT_COVE
        water_source = "default"
        print("note: placements have no water anchor, using the default cove")

    def in_cove(x: int, y: int) -> bool:
        return ((x - cx) ** 2) / (rx * rx) + ((y - cy) ** 2) / (ry * ry) < 1.2

    def near_pad(x: int, y: int) -> bool:
        return any((x - qx) ** 2 + (y - qy) ** 2 < PAD_CLEARANCE ** 2 for qx, qy in ready_pads)

    x0, y0, x1, y1 = GRASS_BOUNDS
    candidates = []
    for y in range(max(y0, 1), min(y1, 359)):
        for x in range(max(x0, 1), min(x1, 639)):
            if index_at(x - ox, y - oy) != 4:
                continue
            below = index_at(x - ox, y + 1 - oy)
            above = index_at(x - ox, y - 1 - oy)
            if below not in (2, 3) or above not in (2, 3, 4):
                continue
            if in_cove(x, y) or near_pad(x, y):
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

    data = {
        "format": pl["format"],
        "size": [640, 360],
        "backdrop_origin": [ox, oy],
        "sway": [[x, y] for x, y in picked],
        "lights": pl["lights"],
        "water": {"x": cx, "y": cy, "rx": rx, "ry": ry},
        "water_source": water_source,
        "pads": [[x, y] for x, y in ready_pads],
        "drift": drift,
    }
    with open(args.out, "w") as f:
        json.dump(data, f, indent=1)
        f.write("\n")
    print(f"wrote {args.out}: {len(picked)} sway tips, {len(pl['lights'])} lights, "
          f"{len(ready_pads)} ready pads, drift {drift}, water {water_source}")


if __name__ == "__main__":
    main()
