#!/usr/bin/env python3
"""Plinky zone 1 world life: writes world/meadow_life.json from the baked meadow backdrop.

Reads assets/art/zone1/meadow_backdrop.png (exactly 8 palette colours, art-bible section 3) and
world/meadow_placements.json. Output:
  sway   grass tips (palette 4 texel with grass below) that the ground layer flicks in a wind wave
  lights lantern and shrine glow centres, texel space
  water  the front-right cove ellipse where sparkles play
  pads   ready pad centres (idle shimmer)

Run after the meadow backdrop changes:  python3 tools/art/gen_life_anchors.py
Needs Pillow. Deterministic (fixed seed), so the JSON only changes when the art does."""
import json, os, random

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
BACKDROP = os.path.join(ROOT, "assets/art/zone1/meadow_backdrop.png")
PLACEMENTS = os.path.join(ROOT, "world/meadow_placements.json")
OUT = os.path.join(ROOT, "world/meadow_life.json")

# Palette index -> colour, from render/palettes.gd (Meadow Tally). Index 4 = light, 3 = base, 2 = deep.
PAL = {
    0: (0x14, 0x16, 0x1c), 1: (0x1f, 0x3b, 0x35), 2: (0x2f, 0x6b, 0x55), 3: (0x5f, 0xa3, 0x6a),
    4: (0xb7, 0xd9, 0x78), 5: (0xf2, 0xe6, 0xa0), 6: (0xc2, 0x78, 0x4e), 7: (0xf6, 0xef, 0xd9),
}
# Water cove, from gen_meadow.py WATER(x, y): centre (478, 270), radii 82 x 36.
COVE = (478.0, 270.0, 82.0, 36.0)
GRASS_BOUNDS = (30, 100, 610, 340)   # x0, y0, x1, y1
SWAY_COUNT = 120
SWAY_SPACING = 9                      # minimum texel distance between tips
PAD_CLEARANCE = 22                    # keep sway tips off the pad rings


def main() -> None:
    from PIL import Image

    im = Image.open(BACKDROP).convert("RGB")
    w, h = im.size
    inv = {v: k for k, v in PAL.items()}
    idx = [[inv[im.getpixel((x, y))] for x in range(w)] for y in range(h)]
    placements = json.load(open(PLACEMENTS))
    pads = [(p["x"], p["y"], p["state"]) for p in placements["pads"]]
    ready_pads = [(x, y) for x, y, s in pads if s == "ready"]
    lights = [{"x": p["x"], "y": p["y"] - 12, "r": 9, "kind": "lantern"}
              for p in placements["props"] if p["name"] == "lantern"]
    lights += [{"x": p["x"], "y": p["y"] - 18, "r": 10, "kind": "shrine"}
               for p in placements["props"] if p["name"] == "shrine"]

    def in_cove(x: int, y: int) -> bool:
        cx, cy, rx, ry = COVE
        return ((x - cx) ** 2) / (rx * rx) + ((y - cy) ** 2) / (ry * ry) < 1.2

    def near_pad(x: int, y: int) -> bool:
        return any((x - px) ** 2 + (y - py) ** 2 < PAD_CLEARANCE ** 2 for px, py in ready_pads)

    x0, y0, x1, y1 = GRASS_BOUNDS
    candidates = []
    for y in range(max(y0, 1), min(y1, h - 2)):
        for x in range(max(x0, 1), min(x1, w - 2)):
            if idx[y][x] != 4:
                continue
            if idx[y + 1][x] not in (2, 3) or idx[y - 1][x] not in (2, 3, 4):
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

    data = {
        "size": [w, h],
        "sway": [[x, y] for x, y in picked],
        "lights": lights,
        "water": {"x": COVE[0], "y": COVE[1], "rx": COVE[2], "ry": COVE[3]},
        "pads": [[x, y] for x, y in ready_pads],
    }
    with open(OUT, "w") as f:
        json.dump(data, f, indent=1)
        f.write("\n")
    print(f"wrote {OUT}: {len(picked)} sway tips, {len(lights)} lights, {len(ready_pads)} ready pads")


if __name__ == "__main__":
    main()
