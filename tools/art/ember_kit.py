"""Tiny pixel kit for the Ember Quarry entrance art (gen_ember_entrance.py). RGBA canvas, no anti-aliasing, 4x4 Bayer
dither, hash noise. Colours are the meadow palette plus the quarry's ember accents, so everything maps onto the zone
palettes in the post-process."""
import math
from PIL import Image, ImageDraw


def hx(s): return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)


# meadow palette (roles 0..7) and the quarry's ember ramp
INK, SHADOW, DEEP, BASE, LIGHT, ACCENT, EARTH, PAPER = [hx(s) for s in
    ("14161c", "1f3b35", "2f6b55", "5fa36a", "b7d978", "f2e6a0", "c2784e", "f6efd9")]
QINK, QSHADOW, QDEEP, QBASE, QLIGHT, QACCENT, QEARTH, QPAPER = [hx(s) for s in
    ("1a1116", "4a1f2a", "8a3a2e", "d0602f", "e9a845", "b77a7a", "5b3d5c", "f1d9b5")]
CLEAR = (0, 0, 0, 0)

BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]


def bayer(x, y): return (BAYER[(y & 3) * 4 + (x & 3)] + 0.5) / 16.0


def hsh(a, b=0, c=0):
    n = (a * 374761393 + b * 668265263 + c * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def vnoise(x, y, s=0):
    x0, y0 = math.floor(x), math.floor(y)
    fx, fy = x - x0, y - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b = hsh(x0, y0, s), hsh(x0 + 1, y0, s)
    c, d = hsh(x0, y0 + 1, s), hsh(x0 + 1, y0 + 1, s)
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.im = Image.new("RGBA", (w, h), CLEAR)
        self.d = ImageDraw.Draw(self.im)

    def px(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h and c[3] > 0:
            self.im.putpixel((x, y), c)

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h: return self.im.getpixel((x, y))
        return CLEAR

    def rect(self, x0, y0, x1, y1, c):          # inclusive
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1): self.px(x, y, c)

    def line(self, x0, y0, x1, y1, c):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) or 1
        for i in range(n + 1):
            self.px(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), c)

    def poly(self, pts, c):
        # non-AA polygon fill by scanline test, so edges stay texel-exact
        ys = [p[1] for p in pts]
        for y in range(int(math.floor(min(ys))), int(math.ceil(max(ys))) + 1):
            xs = []
            for i in range(len(pts)):
                (ax, ay), (bx, by) = pts[i], pts[(i + 1) % len(pts)]
                if (ay <= y + .5 < by) or (by <= y + .5 < ay):
                    xs.append(ax + (y + .5 - ay) / (by - ay) * (bx - ax))
            xs.sort()
            for i in range(0, len(xs) - 1, 2):
                for x in range(int(round(xs[i])), int(round(xs[i + 1]))): self.px(x, y, c)

    def ell(self, cx, cy, rx, ry, c, mask=None):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((x + .5 - cx) / rx) ** 2 + ((y + .5 - cy) / ry) ** 2 <= 1.0: self.px(x, y, c)

    def over(self, other, x, y):
        self.im.alpha_composite(other.im, (int(x), int(y)))

    def outline(self, c, only_outer=True):
        """1 texel outline around opaque pixels, drawn into transparent neighbours (the sprites' ink edge)."""
        src = self.im.copy()
        for y in range(self.h):
            for x in range(self.w):
                if src.getpixel((x, y))[3] == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < self.w and 0 <= ny < self.h and src.getpixel((nx, ny))[3] > 0:
                            self.im.putpixel((x, y), c); break

    def save(self, path, scale=1):
        im = self.im if scale == 1 else self.im.resize((self.w * scale, self.h * scale), Image.NEAREST)
        im.save(path)
