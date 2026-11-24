"""Field shapes and tilled soil for the Larkmoor farm (used by place_farm.py).

A field is one of two irregular shapes, drawn from real-field references (irregular fields of varying size, as in the
satellite imagery of Germany; see docs/decisions/art.md): "notched" (two lobes and a bite out of one edge) and "blob" (a
main body, a bulge and a bump). Both are unions of rounded rectangles in ground space, warped by low-frequency noise so
the edges wander, and both can be mirrored and scaled, so the same two shapes read as different fields around the farm.

`Field.sdf` gives the signed distance in layout texels (negative inside). The wheat is placed where the sdf is negative,
the fence ring runs at a fixed distance outside it, and `soil_image` draws the tilled soil under the field: dark soil in
furrows (EARTH dithered with INK), a headland a few texels wider than the wheat, and an edge that dissolves into grass
through a 4x4 Bayer band. Colours are palette roles only (gen_cozy.py).
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from gen_cozy import Canvas, INK, EARTH, PAPER  # noqa: E402

K0 = 0.29                                # layout texels per mockup pixel at scale 1 (the g1/g3 mockups' pixels)
MX0, MY0 = 222.0, 152.0                  # the mockups' field centre, so the warp noise matches the mockups
BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def noise(x: float, y: float, s: float) -> float:
    return (math.sin(x * 0.047 + s) * math.cos(y * 0.061 - s * 0.7)
            + 0.5 * math.sin(x * 0.13 - y * 0.09 + s * 1.9)) / 1.5


def rbox(u: float, v: float, cu: float, cv: float, a: float, b: float, r: float) -> float:
    du = abs(u - cu) - (a - r)
    dv = abs(v - cv) - (b - r)
    return math.hypot(max(du, 0.0), max(dv, 0.0)) + min(max(du, dv), 0.0) - r


class Field:
    """One field: a shape kind, a centre (layout texels), a scale, a mirror flag and a seed for its warp."""

    def __init__(self, kind: str, cx: float, cy: float, scale: float, mirror: bool, seed: int):
        assert kind in ('notched', 'blob')
        self.kind, self.cx, self.cy, self.scale, self.mirror, self.seed = kind, cx, cy, scale, mirror, seed
        self.k = K0 * scale
        self.reach = 135.0 * self.k      # layout texels from the centre that always holds the whole shape

    def _mock(self, x: float, y: float):
        dx = (x - self.cx) / self.k
        dy = (y - self.cy) / self.k
        if self.mirror:
            dx = -dx
        return dx, dy

    def sdf(self, x: float, y: float) -> float:
        """Signed distance to the field in layout texels: negative inside, positive outside."""
        dx, dy = self._mock(x, y)
        mx, my = MX0 + dx, MY0 + dy
        u, v = dy + dx / 2.0, dy - dx / 2.0          # the ground axes of the 2:1 view
        s = self.seed * 0.37
        if self.kind == 'notched':
            u += 5.0 * noise(mx * 1.7, my * 1.7, 3.1 + s)
            v += 5.0 * noise(mx * 1.7 + 40, my * 1.7 - 13, 5.1 + s)
            d = min(rbox(u, v, 0, 0, 74, 40, 9), rbox(u, v, 36, 30, 34, 24, 8), rbox(u, v, -50, -26, 22, 16, 7))
            d = max(d, -(math.hypot(u - 6, v + 40) - 13))          # a notch bitten out of the upper edge
        else:
            u += 6.0 * noise(mx * 1.7, my * 1.7, 7.7 + s)
            v += 6.0 * noise(mx * 1.7 + 40, my * 1.7 - 13, 9.7 + s)
            d = min(rbox(u, v, 0, 0, 60, 36, 11), rbox(u, v, -30, 20, 36, 28, 12), rbox(u, v, 40, -30, 34, 19, 8))
            d = max(d, -(math.hypot(u + 34, v + 40) - 12))
        return d * self.k

    def tone(self, x: float, y: float) -> float:
        """A slow noise in [-1, 1] across the field: where the wheat is late (brown) and where it is ripe (gold)."""
        dx, dy = self._mock(x, y)
        return noise((MX0 + dx) * 1.3, (MY0 + dy) * 1.3, 4.1 + self.seed)

    def contour(self, offset: float, n: int = 96):
        """Points `offset` layout texels outside the field, by marching rays out from its centre. Both shapes are
        star-shaped around the centre, so each ray crosses the edge once."""
        pts = []
        for i in range(n):
            th = 2 * math.pi * i / n
            ca, sa = math.cos(th), math.sin(th)
            r = 2.0
            while r < self.reach * 1.6 and self.sdf(self.cx + r * ca, self.cy + r * sa) < offset:
                r += 0.5
            pts.append((self.cx + r * ca, self.cy + r * sa))
        return pts

    def bounds(self, margin: float):
        """(x0, y0, x1, y1) in layout texels of the field plus `margin`, from its contour."""
        pts = self.contour(margin)
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        return min(xs), min(ys), max(xs), max(ys)


def soil_image(field: Field, x0: int, y0: int, mask, s: int, reach=None, band=None):
    """The tilled soil under a field as an RGBA image, for the canvas rect starting at (x0, y0) (canvas texels). `mask`
    is a boolean array (rows, cols) of the texels where soil may be drawn: walkable grass, clear of paths and props. The
    soil reaches 7 mockup pixels past the wheat (a headland), or `reach` layout texels when given (the farm runs it up to a few
    texels short of the fence), and its edge dissolves through a Bayer band."""
    h, w = mask.shape
    c = Canvas(w, h)
    margin = 7.0 * field.k if reach is None else reach      # layout texels past the field's edge that still hold soil
    band = 3.0 * field.k if band is None else band           # layout texels of Bayer dissolve beyond that
    cxc, cyc = field.cx * s, field.cy * s
    for yy in range(h):
        for xx in range(w):
            if not mask[yy, xx]:
                continue
            gx, gy = x0 + xx, y0 + yy
            d = field.sdf((gx + 0.5) / s, (gy + 0.5) / s) - margin
            if d > band:
                continue
            if d > 0.0 and BAYER4[gy % 4][gx % 4] / 16.0 < d / band:
                continue
            dxc = (gx - cxc) * (-1.0 if field.mirror else 1.0)
            v = (gy - cyc) - dxc / 2.0                       # across the furrows
            trough = int(math.floor(v)) % 4 == 0
            row = int(math.floor(v / 4.0)) % 2
            share = 0.52 if trough else (0.22 if row == 0 else 0.34)
            share += 0.18 * max(0.0, noise(gx * 1.7, gy * 1.7, 2.2))
            col = INK if BAYER4[gy % 4][gx % 4] / 16.0 < share else EARTH
            if (gx * 13 + gy * 7) % 83 == 0:
                col = PAPER                                  # a pebble
            c.set(xx, yy, col)
    return c.image()
