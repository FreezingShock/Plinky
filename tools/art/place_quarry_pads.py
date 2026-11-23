#!/usr/bin/env python3
"""Places the Ember Quarry's 18 forge pads (six rows of three, Cinder at the bottom to Emberheart by the gate) on the
visible walkable terraces and writes them into assets/art/zone2/quarry/placements3d.json. Idempotent: it replaces every
pad anchor and drops props that would stand on a pad. Pad order = Pad0..Pad17 = ZoneDef.pad_buttons.
Usage: python3 tools/art/place_quarry_pads.py [--preview out.png]"""
import json, math, sys
from PIL import Image, ImageDraw
D = "assets/art/zone2/quarry/"
ROWS_Y = [300, 236, 206, 156, 126, 62]   # screen y of each row, bottom to top (frame coords)
SIDE = [+1, -1, +1, -1, +1, -1]          # which side of the road a row sits on, so the climb zig-zags
ROAD_X = 320
STEP = 40

def main():
    mask = Image.open(D + "walkable.png").convert("L")
    def walk(x, y): return mask.getpixel((int(x) + 100, int(y) + 60)) > 128
    def clear(x, y):
        return all(walk(x + dx, y + dy) for dx in (-16, -8, 0, 8, 16) for dy in (-8, -4, 0, 4, 8))
    data = json.load(open(D + "placements3d.json"))
    vents = [a for a in data["anchors"] if a["kind"] in ("vent", "player_spawn", "arch")]
    pads = []
    for row, (y0, side) in enumerate(zip(ROWS_Y, SIDE)):
        best = None
        for sd in (side, -side):
            for dy in range(-6, 7, 2):
                y = y0 + dy
                for x0 in range(110, 560, 2):
                    xs = [x0 + i * STEP for i in range(3)]
                    if not all(clear(x, y) for x in xs): continue
                    if any(math.hypot(x - v["sx"], y - v["sy"]) < 20 for x in xs for v in vents): continue
                    if any(math.hypot(x - p[0], (y - p[1]) * 2) < 40 for x in xs for p in pads): continue
                    score = -abs(dy) * 3 - abs((xs[1]) - (ROAD_X + sd * 90)) * 0.2 - (0 if sd == side else 40)
                    if best is None or score > best[0]: best = (score, xs, y)
            if best: break
        assert best, "no room for row %d" % row
        pads += [(x, best[2]) for x in best[1]]
    anchors = [a for a in data["anchors"] if a["kind"] != "pad"]
    new = [dict(kind="pad", state="ready", u=0.0, v=0.0, sx=float(x), sy=float(y)) for x, y in pads]
    data["anchors"] = new + anchors
    keep = []
    for s in data["sprites"]:
        fx, fy = s["foot"]
        if any(abs(fx - x) < 20 and 0 < (fy - y) < 12 or math.hypot(fx - x, (fy - y) * 2) < 20 for x, y in pads): continue
        keep.append(s)
    print("removed props:", len(data["sprites"]) - len(keep))
    data["sprites"] = keep
    json.dump(data, open(D + "placements3d.json", "w"), indent=1)
    if "--preview" in sys.argv:
        im = Image.open(D + "preview_full.png").convert("RGB")
        dr = ImageDraw.Draw(im)
        for i, (x, y) in enumerate(pads):
            dr.ellipse([x - 14, y - 7, x + 14, y + 7], outline=(255, 255, 255)); dr.text((x - 3, y - 4), str(i // 3 + 1), fill=(255, 255, 0))
        im.save(sys.argv[sys.argv.index("--preview") + 1])
if __name__ == "__main__": main()
