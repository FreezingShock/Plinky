"""Tiny pixel-art kit for Plinky icons. Shapes are geometry in a 32 unit space, sampled at pixel centres, so:
  - a symmetric shape is symmetric to the pixel (no hand-placed pixels to drift),
  - 45 degree and 2:1 edges come out as clean steps, and
  - the same drawing renders at 32 px and at 16 px (units halve) with crisp lines.
Palette indices (meadow): 0 ink, 1 shadow, 2 deep, 3 base, 4 light, 5 accent, 6 earth, 7 paper.
Keep every vertex on an even unit so the 16 px version stays on the grid."""
import math
from PIL import Image

PAL = ['#14161c', '#1f3b35', '#2f6b55', '#5fa36a', '#b7d978', '#f2e6a0', '#c2784e', '#f6efd9']
RGB = [tuple(int(h[k:k + 2], 16) for k in (1, 3, 5)) + (255,) for h in PAL]


class Sk:
    def __init__(self, size):
        self.S = size
        self.f = size / 32.0
        self.px = {}          # (x, y) -> palette index

    # ---- geometry (returns sets of pixels)
    def _each(self):
        for y in range(self.S):
            for x in range(self.S):
                yield x, y, (x + 0.5) / self.f, (y + 0.5) / self.f

    def circle(self, cx, cy, r):
        return {(x, y) for x, y, u, v in self._each() if (u - cx) ** 2 + (v - cy) ** 2 <= r * r}

    def ellipse(self, cx, cy, rx, ry):
        return {(x, y) for x, y, u, v in self._each() if ((u - cx) / rx) ** 2 + ((v - cy) / ry) ** 2 <= 1.0}

    def rect(self, x0, y0, x1, y1):
        return {(x, y) for x, y, u, v in self._each() if x0 <= u < x1 and y0 <= v < y1}

    def poly(self, pts):
        out = set()
        for x, y, u, v in self._each():
            inside = False
            j = len(pts) - 1
            for i in range(len(pts)):
                xi, yi = pts[i]
                xj, yj = pts[j]
                if (yi > v) != (yj > v) and u < (xj - xi) * (v - yi) / (yj - yi) + xi:
                    inside = not inside
                j = i
            if inside:
                out.add((x, y))
        return out

    def line(self, a, b, w):
        """Thick line as a polygon. Use 45 degree, 2:1, horizontal or vertical directions only."""
        dx, dy = b[0] - a[0], b[1] - a[1]
        n = math.hypot(dx, dy)
        nx, ny = -dy / n * w / 2, dx / n * w / 2
        return self.poly([(a[0] + nx, a[1] + ny), (b[0] + nx, b[1] + ny), (b[0] - nx, b[1] - ny), (a[0] - nx, a[1] - ny)])

    def mirror(self, shape):
        return shape | {(self.S - 1 - x, y) for x, y in shape}

    def clean(self, shape):
        """Drop pixels with no 4-neighbour: stray dots that read as noise."""
        return {p for p in shape if any((p[0] + dx, p[1] + dy) in shape for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))}

    # ---- painting
    def fill(self, shape, c):
        for p in shape:
            self.px[p] = c

    def body(self, shape, base, hi=None, lo=None):
        """Fill with a lit top-left edge and a shaded bottom-right edge (1 px at 16, 2 px at 32)."""
        band = max(1, self.S // 16)
        for (x, y) in shape:
            c = base
            if lo is not None and any((x + k, y + k) not in shape or (x + k, y) not in shape or (x, y + k) not in shape for k in range(1, band + 1)):
                c = lo
            if hi is not None and any((x - k, y - k) not in shape or (x - k, y) not in shape or (x, y - k) not in shape for k in range(1, band + 1)):
                c = hi
            self.px[(x, y)] = c

    def outline(self):
        filled = set(self.px)
        for (x, y) in filled:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (x + dx, y + dy)
                if q not in filled and 0 <= q[0] < self.S and 0 <= q[1] < self.S:
                    self.px[q] = 0

    def image(self):
        im = Image.new('RGBA', (self.S, self.S), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            if 0 <= x < self.S and 0 <= y < self.S:
                im.putpixel((x, y), RGB[c])
        return im
