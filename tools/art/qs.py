#!/usr/bin/env python3
"""Front-facing 2D sprite kit for the Ember Quarry (Nathan: "more detailed 2D, facing the screen", not isometric).
A sprite is a stack of painted shapes. Every pixel keeps a ramp id and a tone value 0..1; finish() turns tone into a
ramp index with a Bayer 4x4 threshold (a narrow one, so dither only shows at tone band edges), adds a lit top-left
rim, a shaded bottom-right edge, and a 1 px ink outline. Light comes from the top left. numpy + Pillow only."""
import math
import numpy as np
from PIL import Image

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
QPAL = ['1a1116', '4a1f2a', '8a3a2e', 'd0602f', 'e9a845', 'b77a7a', '5b3d5c', 'f1d9b5']


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def qramp(*ix):
    return [rgb(QPAL[i]) for i in ix]


def h2(a, b, s=0):
    n = (int(a) * 374761393 + int(b) * 668265263 + int(s) * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


LIGHT = np.array([-0.55, -0.62, 0.56]); LIGHT /= np.linalg.norm(LIGHT)


class Spr:
    def __init__(self, w, h, seed=0, ink=None):
        self.w, self.h, self.seed = w, h, seed
        self.R = np.full((h, w), -1, np.int16)     # ramp id (-1 empty)
        self.V = np.zeros((h, w))                   # tone 0..1
        self.O = np.zeros((h, w), np.int16)         # object id (ink between objects)
        self.G = np.zeros((h, w), bool)             # glow pixels (frame flicker)
        self.ramps = []
        self.ink = ink
        self.oid = 0
        self.yy, self.xx = np.mgrid[0:h, 0:w]

    def ramp(self, cols):
        self.ramps.append(cols)
        return len(self.ramps) - 1

    # ---- masks
    def poly_mask(self, pts):
        from PIL import ImageDraw
        im = Image.new('L', (self.w, self.h), 0)
        ImageDraw.Draw(im).polygon([(float(x), float(y)) for x, y in pts], fill=255)
        return np.array(im) > 0

    def ell_mask(self, cx, cy, rx, ry):
        return ((self.xx + .5 - cx) / rx) ** 2 + ((self.yy + .5 - cy) / ry) ** 2 <= 1.0

    def paint(self, mask, ramp, v, glow=False, obj=True):
        if obj:
            self.oid += 1
        self.R[mask] = ramp
        self.V[mask] = v[mask] if isinstance(v, np.ndarray) else v
        self.G[mask] = glow
        if obj:
            self.O[mask] = self.oid

    # ---- shapes
    def poly(self, pts, ramp, v0, v1=None, noise=0.0, glow=False, obj=True):
        m = self.poly_mask(pts)
        ys = [p[1] for p in pts]
        y0, y1 = min(ys), max(ys)
        v1 = v0 if v1 is None else v1
        t = np.clip((self.yy - y0) / max(y1 - y0, 1e-6), 0, 1)
        v = v0 + (v1 - v0) * t
        if noise:
            v = v + (h2v(self.xx, self.yy, self.seed) - .5) * noise
        self.paint(m, ramp, v, glow, obj)
        return m

    def rock(self, cx, cy, rw, rh, ramp, seed=0, facets=7, flat=0.25, glow_ramp=None, crack_p=0.0, bright=0.0, sides=9):
        """Faceted rock seen from the front: an irregular blob with a flat-ish base, split into facets whose tone comes
        from each facet's lean toward the light. Optional glow cracks along facet seams."""
        rng = np.random.default_rng(seed)
        pts = []
        for i in range(sides):
            a = math.pi + math.pi * i / (sides - 1) * 1.0   # top half arc left to right
            r = 1 + (rng.random() - .5) * 0.34
            pts.append((cx + math.cos(a) * rw * r, cy + math.sin(a) * rh * r * (1 - flat * .0)))
        pts += [(cx + rw * (0.9 + rng.random() * .12), cy), (cx + rw * 0.55, cy + 1), (cx - rw * 0.55, cy + 1), (cx - rw * (0.9 + rng.random() * .12), cy)]
        m = self.poly_mask(pts)
        cs = np.array([[cx + (rng.random() * 2 - 1) * rw * .85, cy - rng.random() * rh * 1.0] for _ in range(facets)])
        d = (self.xx[..., None] + .5 - cs[:, 0]) ** 2 + ((self.yy[..., None] + .5 - cs[:, 1]) * 1.3) ** 2
        fid = np.argmin(d, -1)
        ftone = np.zeros(facets)
        for k in range(facets):
            nx = (cs[k, 0] - cx) / rw; ny = (cs[k, 1] - (cy - rh * .5)) / (rh * .6)
            n = np.array([nx, ny, 0.9]); n /= np.linalg.norm(n)
            ftone[k] = float(np.clip(n @ LIGHT * 0.95 + 0.12 + (rng.random() - .5) * .16, 0, 1))
        v = ftone[fid] * 0.8 + 0.2 * (1 - (self.yy - (cy - rh)) / (rh * 1.1)).clip(0, 1) + bright
        self.paint(m, ramp, v)
        # seams: darker line between facets, sometimes glowing
        if glow_ramp is not None and crack_p > 0:
            seam = np.zeros_like(m)
            for dy, dx in ((0, 1), (1, 0)):
                seam |= (np.roll(fid, -dx, 1) != fid) if dx else (np.roll(fid, -dy, 0) != fid)
            seam &= m
            sel = seam & (h2v(self.xx // 2, self.yy // 2, seed + 5) < crack_p)
            self.paint(sel, glow_ramp, 0.25 + 0.6 * h2v(self.xx, self.yy, seed + 9), glow=True, obj=False)
        return m

    def crystal(self, x, y, w, h, ramp, lean=0.0, tipw=0.0, hi=1.0, seed=0, gl=False):
        """Hexagonal crystal standing on y: left face lit, right face dark, a bright spine and tip."""
        l, r = x - w / 2, x + w / 2
        sh = y - h * 0.72
        pts = [(l, y), (l + lean * .3, sh), (x + lean - tipw / 2, y - h), (x + lean + tipw / 2, y - h), (r + lean * .3, sh), (r, y)]
        pts = [(a, b) for a, b in pts]
        self.oid += 1
        m = self.poly_mask(pts)
        mid = x + lean * (1 - (self.yy - (y - h)) / max(h, 1)).clip(0, 1) * 0.6 - w * 0.05
        t = (self.yy - (y - h)) / max(h, 1)
        v = np.where(self.xx + .5 < mid, 0.62 + 0.25 * (1 - t) * hi, 0.22 + 0.18 * (1 - t))
        v = np.where((np.abs(self.xx + .5 - mid) < 0.7), 0.93, v)
        self.paint(m, ramp, v, obj=False)
        self.O[m] = self.oid
        if gl:
            self.G[m & (np.abs(self.xx + .5 - mid) < 1.2)] = True
        return m

    # ---- finish
    def finish(self, frame=0, glow_ramp=None, outline=True, rim=True, extra_glow=None):
        out = np.zeros((self.h, self.w, 4), np.uint8)
        bay = BAYER[self.yy % 4, self.xx % 4]
        A = self.R >= 0
        idx = np.zeros((self.h, self.w), np.int32)
        for rid, cols in enumerate(self.ramps):
            sel = A & (self.R == rid)
            if not sel.any():
                continue
            L = len(cols) - 1
            v = self.V.copy()
            # rim light on the top-left edge, shade on the bottom-right edge of each object
            if rim:
                up = np.roll(self.O, 1, 0); lf = np.roll(self.O, 1, 1)
                dn = np.roll(self.O, -1, 0); rt = np.roll(self.O, -1, 1)
                lit = ((up != self.O) | (lf != self.O)) & (self.O > 0)
                dk = ((dn != self.O) | (rt != self.O)) & (self.O > 0)
                v = v + 0.16 * lit - 0.12 * (dk & ~lit)
            pos = np.clip(v, 0, 0.999) * L + (bay - .5) * 0.34
            ix = np.clip(np.floor(pos + .5).astype(int), 0, L)
            col = np.array(cols, np.uint8)[ix]
            fl = sel & self.G
            if fl.any():
                # glow flicker: the ramp index steps up on a sparse moving lattice
                bump = ((self.xx * 3 + self.yy * 5 + frame * 2) % 4 == 0) & (bay < .75)
                ix2 = np.clip(ix + bump.astype(int), 0, L)
                col = np.where(fl[..., None], np.array(cols, np.uint8)[ix2], col)
            out[sel, :3] = col[sel]
            out[sel, 3] = 255
        if outline:
            ink = np.array(self.ink or (12, 8, 10), np.uint8)
            a = out[..., 3] > 0
            edge = np.zeros_like(a)
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                edge |= np.roll(np.roll(a, dy, 0), dx, 1)
            edge &= ~a
            edge[0, :] = edge[-1, :] = False
            out[edge, :3] = ink; out[edge, 3] = 255
        return Image.fromarray(out, 'RGBA')


def h2v(x, y, s=0):
    n = (x.astype(np.int64) * 374761393 + y.astype(np.int64) * 668265263 + np.int64(s) * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def pad_canvas(img, w, h):
    """Crop a finished sprite to its bounding box."""
    return img.crop(img.getbbox())
