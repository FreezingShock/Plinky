#!/usr/bin/env python3
"""Plinky cozy props for zone 1: benches, a picnic blanket, a swing, a cottage, a fence run, a signpost,
a campfire ring, a well, a fountain basin, stepping stones, a water wheel and a wheat patch.

Every pixel is a palette index (meadow roles, docs/art-bible.md section 3): 0 ink, 1 shadow, 2 deep, 3 base,
4 light, 5 accent, 6 earth, 7 paper. A zone palette swap re-tints every sprite with no new art.
Outputs (1x, nearest, no alpha tricks beyond the transparent background):
  assets/art/zone1/cozy/<name>.png       each prop, 1x
  assets/art/zone1/cozy/wheel_sheet.png  4 spin frames, side by side (18 px each)
  assets/art/zone1/cozy/wheat_sheet.png  8 gust frames, side by side (48 px each, 16 tall)
  assets/art/zone1/cozy/preview_cozy.png 8x sheet of everything, for review only
Run: python3 tools/art/gen_cozy.py   (from the repo root). Pure Pillow, no numpy."""
import math
import os
import sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'art', 'zone1', 'cozy')

PAL = ['#14161c', '#1f3b35', '#2f6b55', '#5fa36a', '#b7d978', '#f2e6a0', '#c2784e', '#f6efd9']
RGBA = [tuple(int(h[k:k + 2], 16) for k in (1, 3, 5)) + (255,) for h in PAL]

INK, SHADE, DEEP, BASE, LIGHT, ACCENT, EARTH, PAPER = range(8)


class Canvas:
    def __init__(self, w: int, h: int):
        self.w, self.h = w, h
        self.px: dict = {}

    def set(self, x: int, y: int, c: int) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[(x, y)] = c

    def rect(self, x0: int, y0: int, x1: int, y1: int, c: int) -> None:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, c)

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, c: int) -> None:
        for y in range(self.h):
            for x in range(self.w):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                    self.set(x, y, c)

    def seg(self, x0: float, y0: float, x1: float, y1: float, c: int, thick: int = 1) -> None:
        n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        for i in range(n + 1):
            t = i / n
            x = round(x0 + (x1 - x0) * t)
            y = round(y0 + (y1 - y0) * t)
            for k in range(thick):
                self.set(x + k, y, c)

    def outline(self, c: int = INK) -> None:
        """Ink on every transparent texel that touches the silhouette (4-neighbour)."""
        filled = set(self.px)
        add = {}
        for (x, y) in filled:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (x + dx, y + dy)
                if q not in filled and 0 <= q[0] < self.w and 0 <= q[1] < self.h:
                    add[q] = c
        self.px.update(add)

    def image(self) -> Image.Image:
        im = Image.new('RGBA', (self.w, self.h), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            im.putpixel((x, y), RGBA[c])
        return im


def bench() -> Canvas:
    cv = Canvas(24, 14)
    cv.rect(1, 0, 22, 1, EARTH)        # backrest slat, top
    cv.rect(1, 3, 22, 4, EARTH)        # backrest slat, bottom (row 2 stays a gap: reads as a plank line)
    cv.rect(0, 6, 23, 7, EARTH)        # seat
    cv.rect(0, 6, 23, 6, ACCENT)       # sun on the seat's top edge
    cv.rect(2, 8, 3, 12, EARTH)        # legs
    cv.rect(20, 8, 21, 12, EARTH)
    cv.outline()
    return cv


def blanket() -> Canvas:
    """A round picnic rug with stripes. Not a checker: the wooden pads are checkered, and a rug must not read as a pad."""
    cv = Canvas(22, 9)
    cv.ellipse(10.5, 4.5, 10.5, 4.5, PAPER)
    for x in range(22):
        if x % 6 in (0, 1):
            for y in range(9):
                if (x + 0.5 - 10.5) ** 2 / 10.5 ** 2 + (y + 0.5 - 4.5) ** 2 / 4.5 ** 2 <= 1.0:
                    cv.set(x, y, ACCENT)
    cv.outline()
    return cv


def swing_frame() -> Canvas:
    cv = Canvas(32, 34)
    cv.rect(4, 1, 27, 2, EARTH)                       # top bar the seat hangs from
    cv.seg(3, 33, 14, 2, EARTH, thick=2)              # left A-leg
    cv.seg(28, 33, 17, 2, EARTH, thick=2)             # right A-leg
    cv.seg(8, 23, 23, 23, EARTH)                      # cross brace
    cv.outline()
    return cv


def swing_seat() -> Canvas:
    """Pivot is texel (6, 0): the rope tops. Rotate the sprite about that point to swing it."""
    cv = Canvas(13, 22)
    cv.seg(2, 0, 2, 17, PAPER)
    cv.seg(10, 0, 10, 17, PAPER)
    cv.rect(0, 18, 12, 19, EARTH)
    cv.rect(0, 18, 12, 18, ACCENT)
    cv.outline()
    return cv


def cottage() -> Canvas:
    cv = Canvas(40, 44)
    cv.rect(5, 18, 34, 41, PAPER)                     # walls
    cv.rect(5, 28, 34, 28, EARTH)                     # half-timber beam
    cv.rect(5, 40, 34, 41, SHADE)                     # dark stone footing
    for y in range(4, 18):                            # roof: a wide, low gable
        half = 4 + (y - 4) * 17 // 13
        cv.rect(20 - half, y, 19 + half, y, EARTH)
        if (y - 4) % 3 == 2:
            cv.rect(20 - half, y, 19 + half, y, SHADE)  # shingle courses
    cv.rect(26, 4, 30, 12, EARTH)                     # chimney
    cv.rect(25, 4, 31, 4, EARTH)
    for wx in (8, 24):                                # two lit windows, with a frame and a mullion
        cv.rect(wx, 21, wx + 7, 27, EARTH)
        cv.rect(wx + 1, 22, wx + 6, 26, ACCENT)
        cv.rect(wx + 3, 22, wx + 4, 26, EARTH)
        cv.rect(wx + 1, 24, wx + 6, 24, EARTH)
        cv.rect(wx - 1, 29, wx + 8, 30, EARTH)        # flower box
        for fx in range(wx, wx + 8, 2):
            cv.set(fx, 28, PAPER)
            cv.set(fx + 1, 27, ACCENT)
    cv.rect(17, 31, 22, 41, EARTH)                    # door
    cv.set(21, 36, ACCENT)                             # knob
    cv.outline()
    return cv


def fence() -> Canvas:
    cv = Canvas(24, 12)
    cv.rect(0, 3, 23, 4, EARTH)
    cv.rect(0, 7, 23, 8, EARTH)
    cv.rect(0, 1, 1, 11, EARTH)                       # one post per segment, at its left end
    cv.set(0, 1, ACCENT)
    cv.outline()
    return cv


def signpost() -> Canvas:
    cv = Canvas(14, 26)
    cv.rect(6, 9, 7, 25, EARTH)
    cv.rect(1, 2, 11, 9, EARTH)
    for y in range(3, 9):                             # arrow head pointing right
        if 4 <= y <= 7:
            cv.set(12, y, EARTH)
        if 5 <= y <= 6:
            cv.set(13, y, EARTH)
    cv.rect(3, 4, 9, 4, PAPER)                        # two lines of lettering
    cv.rect(3, 7, 8, 7, PAPER)
    cv.outline()
    return cv


def campfire_ring() -> Canvas:
    cv = Canvas(20, 10)
    cv.ellipse(10, 6.5, 9.5, 3.5, PAPER)              # stone ring
    cv.ellipse(10, 6.5, 6.5, 2.0, SHADE)              # ash bed
    cv.seg(5, 6, 15, 4, EARTH, thick=2)               # two crossed logs
    cv.seg(5, 4, 15, 6, EARTH, thick=2)
    cv.outline()
    return cv


def well() -> Canvas:
    cv = Canvas(20, 24)
    for y in range(0, 6):                             # pitched roof
        half = 2 + y * 2
        cv.rect(10 - half, y, 9 + half, y, EARTH)
    cv.rect(3, 6, 4, 15, EARTH)                       # posts
    cv.rect(15, 6, 16, 15, EARTH)
    cv.rect(3, 6, 16, 6, EARTH)                       # cross beam
    cv.seg(9, 8, 9, 16, PAPER)                        # rope
    cv.ellipse(9.5, 19.5, 9.5, 4.5, PAPER)            # stone curb
    cv.ellipse(9.5, 19.5, 6.5, 2.8, DEEP)             # water in the shaft
    cv.outline()
    return cv


def fountain_basin() -> Canvas:
    cv = Canvas(28, 16)
    cv.ellipse(14, 10, 13.5, 5.5, PAPER)              # stone rim
    cv.ellipse(14, 10, 10.5, 4.0, BASE)               # water
    cv.ellipse(14, 10.5, 8.0, 2.5, DEEP)
    cv.rect(13, 3, 14, 9, PAPER)                      # central column
    cv.rect(11, 2, 16, 3, PAPER)                      # bowl on top
    cv.outline()
    return cv


def stone(variant: int) -> Canvas:
    cv = Canvas(7, 5)
    shapes = [
        [(1, 0, 5, 0), (0, 1, 6, 3), (1, 4, 5, 4)],
        [(2, 0, 4, 0), (0, 1, 6, 2), (0, 3, 5, 3), (1, 4, 4, 4)],
        [(1, 1, 5, 1), (0, 2, 6, 3), (2, 4, 4, 4)],
    ][variant % 3]
    for x0, y0, x1, y1 in shapes:
        cv.rect(x0, y0, x1, y1, PAPER)
    cv.rect(0, 3, 6, 3, SHADE) if variant % 2 == 0 else cv.rect(1, 4, 5, 4, SHADE)
    cv.outline()
    return cv


WHEEL_SIZE: int = 18
WHEEL_FRAMES: int = 4


def wheel_frame(phase_deg: float) -> Canvas:
    """Eight spokes, so the wheel repeats every 45 degrees. Four frames step through a quarter of that."""
    cv = Canvas(WHEEL_SIZE, WHEEL_SIZE)
    cx, cy = 9.0, 9.0
    for i in range(72):                               # rim: a thin ring, drawn as dots on the circle
        a = math.radians(i * 5.0)
        x, y = cx + 7.6 * math.cos(a), cy + 7.6 * math.sin(a)
        cv.set(round(x), round(y), EARTH)
    for k in range(8):
        a = math.radians(phase_deg + k * 45.0)
        for r10 in range(15, 70):
            r = r10 / 10.0
            cv.set(round(cx + r * math.cos(a)), round(cy + r * math.sin(a)), EARTH)
    cv.ellipse(cx, cy, 1.6, 1.6, ACCENT)              # hub
    cv.outline()
    return cv


WHEAT_W: int = 48
WHEAT_H: int = 16
WHEAT_FRAMES: int = 8


def wheat_frame(frame: int) -> Canvas:
    """A row of stalks rooted on the bottom row. A gust is a sine wave along x that moves one step per frame,
    so the bend rolls across the field instead of every stalk moving in step. Stems are light green so they
    read against the base-green grass; heads are the accent colour."""
    cv = Canvas(WHEAT_W, WHEAT_H)
    phase = frame * 2.0 * math.pi / WHEAT_FRAMES
    base_y = WHEAT_H - 1
    for i in range(WHEAT_W):
        if i % 3 == 2:
            continue                                  # a gap every third texel keeps the field airy
        x0 = i
        h = 8 + ((i * 7) % 6)                         # stalk height 8..13
        bend = 2.4 * math.sin(x0 * 0.42 - phase)
        cv.set(x0, base_y, DEEP)
        for k in range(1, h):
            t = k / h
            x = round(x0 + bend * t * t)
            y = base_y - k
            cv.set(x, y, LIGHT if k < h - 3 else BASE)
        tip_x = round(x0 + bend)
        tip_y = base_y - h
        cv.set(tip_x, tip_y, ACCENT)
        cv.set(tip_x, tip_y + 1, ACCENT)
        if i % 2 == 0:
            cv.set(tip_x + 1, tip_y + 1, PAPER)
    return cv


PROPS = {
    'bench': bench,
    'blanket': blanket,
    'swing_frame': swing_frame,
    'swing_seat': swing_seat,
    'cottage': cottage,
    'fence': fence,
    'signpost': signpost,
    'campfire_ring': campfire_ring,
    'well': well,
    'fountain_basin': fountain_basin,
    'stone_0': lambda: stone(0),
    'stone_1': lambda: stone(1),
    'stone_2': lambda: stone(2),
}


def sheet_of(frames: list, w: int, h: int) -> Image.Image:
    im = Image.new('RGBA', (w * len(frames), h), (0, 0, 0, 0))
    for i, cv in enumerate(frames):
        im.paste(cv.image(), (i * w, 0))
    return im


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    made: dict = {}
    for name, fn in PROPS.items():
        cv = fn()
        cv.image().save(os.path.join(OUT, name + '.png'))
        made[name] = (cv.w, cv.h)
    wheel = [wheel_frame(k * 11.25) for k in range(WHEEL_FRAMES)]
    sheet_of(wheel, WHEEL_SIZE, WHEEL_SIZE).save(os.path.join(OUT, 'wheel_sheet.png'))
    wheat = [wheat_frame(f) for f in range(WHEAT_FRAMES)]
    sheet_of(wheat, WHEAT_W, WHEAT_H).save(os.path.join(OUT, 'wheat_sheet.png'))
    made['wheel_sheet'] = (WHEEL_SIZE * WHEEL_FRAMES, WHEEL_SIZE)
    made['wheat_sheet'] = (WHEAT_W * WHEAT_FRAMES, WHEAT_H)
    # Review sheet: every prop on a grass-coloured strip, 6x, so the silhouettes can be judged at a glance.
    names = list(PROPS.keys())
    sheet_w = 1400
    rows: list = []
    row: list = []
    x = 8
    rowh = 0
    for n in names:
        im = Image.open(os.path.join(OUT, n + '.png'))
        im = im.resize((im.width * 4, im.height * 4), Image.NEAREST)
        if x + im.width + 8 > sheet_w:
            rows.append((row, rowh))
            row, x, rowh = [], 8, 0
        row.append((im, x))
        x += im.width + 16
        rowh = max(rowh, im.height)
    rows.append((row, rowh))
    total_h = sum(rh + 16 for _, rh in rows) + 8
    sheet = Image.new('RGBA', (sheet_w, total_h), tuple(int(PAL[3][k:k + 2], 16) for k in (1, 3, 5)) + (255,))
    y = 8
    for row_items, rh in rows:
        for im, px in row_items:
            sheet.alpha_composite(im, (px, y))
        y += rh + 16
    sheet.save(os.path.join(OUT, 'preview_cozy.png'))
    for name in sorted(made):
        print('%-16s %3d x %3d' % (name, made[name][0], made[name][1]))
    return 0


if __name__ == '__main__':
    sys.exit(main())
