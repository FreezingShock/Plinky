"""Elevated-view farm buildings and props for Larkmoor (world/farm/), drawn in the mockup camera.

The camera is wheat mockup D's: the ground floats below the viewer and every object shows its top. A world point
(X along a building's length, Y across it, Z up) projects to the screen as (X - Y, K * (X + Y) - Z). The light comes from
the upper left, so the X-max faces read lit and the Y-max faces take the shade. Shade is a 4x4 Bayer dither of the
shadow colour over the lit colour, so every texel stays on the zone palette (gen_cozy.py roles). Each sprite is fitted
to its canvas with its ground's front corner on row h - 2, the same foot the farm places by.

Buildings: a gabled barn with a porch, columns, moldings, a loft hatch and a cellar hatch; a gabled shed with moldings.
Props: a round hay bale, a two-wheeled cart and a crate. The scarecrow stays in gen_farm.py.
"""
import math

from gen_cozy import Canvas, INK, SHADE, DEEP, BASE, LIGHT, ACCENT, EARTH, PAPER

K = 0.6                  # vertical squash of the ground: higher looks more down on the farm
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def bayer(x: int, y: int) -> float:
    return (BAYER[y % 4][x % 4] + 0.5) / 16.0


def dither(a: int, b: int, frac_a: float):
    """Colour a on frac_a of the texels in a 4x4 Bayer pattern, b on the rest."""
    return lambda x, y: a if bayer(x, y) < frac_a else b


def solid(c: int):
    return lambda x, y: c


def inpoly(px: float, py: float, pts) -> bool:
    inside = False
    n = len(pts)
    for i in range(n):
        x0, y0 = pts[i]
        x1, y1 = pts[(i + 1) % n]
        if (y0 > py) != (y1 > py) and px < (x1 - x0) * (py - y0) / (y1 - y0) + x0:
            inside = not inside
    return inside


class Iso:
    """Projects world points into one canvas. `extent` lists the world points the sprite must hold; the fit centres them
    left to right and puts the lowest ground corner on row h - 2."""

    def __init__(self, cv: Canvas, extent):
        self.cv = cv
        raw = [(X - Y, K * (X + Y) - Z) for (X, Y, Z) in extent]
        min_x = min(p[0] for p in raw)
        max_x = max(p[0] for p in raw)
        min_y = min(p[1] for p in raw)
        max_y = max(p[1] for p in raw)
        self.ox = (cv.w - (max_x - min_x)) / 2.0 - min_x
        self.oy = (cv.h - 2) - max_y
        if min_y + self.oy < 0 or max_x + self.ox > cv.w - 1 or min_x + self.ox < 0:
            raise ValueError('sprite does not fit %dx%d: y %.1f..%.1f, x %.1f..%.1f' % (
                cv.w, cv.h, min_y + self.oy, max_y + self.oy, min_x + self.ox, max_x + self.ox))

    def p(self, X: float, Y: float, Z: float = 0.0):
        return (self.ox + X - Y, self.oy + K * (X + Y) - Z)

    def fill(self, pts, fn) -> None:
        """Fills a world polygon. fn(x, y) gives the palette index at each texel centre inside it."""
        scr = [self.p(*q) for q in pts]
        xs = [q[0] for q in scr]
        ys = [q[1] for q in scr]
        for y in range(max(0, int(math.floor(min(ys)))), min(self.cv.h - 1, int(math.ceil(max(ys)))) + 1):
            for x in range(max(0, int(math.floor(min(xs)))), min(self.cv.w - 1, int(math.ceil(max(xs)))) + 1):
                if inpoly(x + 0.5, y + 0.5, scr):
                    self.cv.set(x, y, fn(x, y))

    def line(self, a, b, c: int) -> None:
        ax, ay = self.p(*a)
        bx, by = self.p(*b)
        self.cv.seg(ax, ay, bx, by, c)

    def dot(self, a, c: int) -> None:
        x, y = self.p(*a)
        self.cv.set(int(round(x)), int(round(y)), c)


def tile_fn(base: int, joint: int, x_off: float = 0.0):
    """Roof tiles: courses 3 texels tall, a joint line at the top of each course, staggered by half a tile."""
    def fn(x: int, y: int) -> int:
        course = y // 3
        at_top = y % 3 == 0
        return joint if at_top and (x + course * 3 + int(x_off)) % 6 < 5 else base
    return fn


def gable_building(cv: Canvas, L: float, W: float, H: float, rise: float, porch: bool, loft_hatch: bool,
                   door_w: float = 8.0) -> None:
    """A gabled building with its ridge along X. Walls, a gable, two roof slopes, moldings, a door and windows."""
    xr, y1 = L, W
    ym = W / 2.0
    extent = [(0, 0, 0), (L, 0, 0), (L, W, 0), (0, W, 0), (0, 0, H), (L, 0, H), (L, W, H), (0, W, H),
              (0, ym, H + rise), (L, ym, H + rise)]
    if porch:
        extent += [(L + 8, ym - 9, 0), (L + 8, ym + 9, 0), (L + 8, ym + 9, H - 3)]
    iso = Iso(cv, extent)

    # Roof: far slope (Y small) lit DEEP with SHADE joints, near slope (Y large) in SHADE with DEEP joints.
    iso.fill([(0, 0, H), (xr, 0, H), (xr, ym, H + rise), (0, ym, H + rise)], tile_fn(DEEP, BASE))
    iso.fill([(0, ym, H + rise), (xr, ym, H + rise), (xr, y1, H), (0, y1, H)], tile_fn(SHADE, DEEP, 1))
    iso.line((0, ym, H + rise), (xr, ym, H + rise), LIGHT)          # ridge cap catches the light
    iso.line((0, 0, H), (xr, 0, H), LIGHT)                          # far eave

    # Shaded wall (Y face): EARTH with a SHADE dither, so the shadow stays inside the palette.
    iso.fill([(0, y1, 0), (xr, y1, 0), (xr, y1, H), (0, y1, H)], dither(SHADE, EARTH, 0.22))
    for X in _steps(3, xr - 1, 3):
        iso.line((X, y1, 0), (X, y1, H), SHADE)

    # Lit wall (X face): EARTH with board lines.
    iso.fill([(xr, 0, 0), (xr, y1, 0), (xr, y1, H), (xr, 0, H)], solid(EARTH))
    for Y in _steps(2, y1 - 1, 3):
        iso.line((xr, Y, 0), (xr, Y, H), SHADE)

    # Moldings: a PAPER crown under the eaves, a SHADE drip line below it, and a PAPER base course.
    iso.line((0, y1, H), (xr, y1, H), PAPER)
    iso.line((xr, 0, H), (xr, y1, H), PAPER)
    iso.line((0, y1, H - 1), (xr, y1, H - 1), SHADE)
    iso.line((xr, 0, H - 1), (xr, y1, H - 1), SHADE)
    iso.line((xr, 0, 1), (xr, y1, 1), PAPER)

    # Gable end: EARTH triangle, PAPER fascia along both roof edges.
    iso.fill([(xr, 0, H), (xr, y1, H), (xr, ym, H + rise)], solid(EARTH))
    iso.line((xr, 0, H), (xr, ym, H + rise), PAPER)
    iso.line((xr, y1, H), (xr, ym, H + rise), PAPER)

    # Double door centred on the lit wall, framed in PAPER, with a split.
    dh = 11.0
    iso.fill([(xr, ym - door_w / 2, 0), (xr, ym + door_w / 2, 0), (xr, ym + door_w / 2, dh),
              (xr, ym - door_w / 2, dh)], solid(INK))
    iso.line((xr, ym, 0), (xr, ym, dh), SHADE)
    iso.line((xr, ym - door_w / 2 - 0.5, 0), (xr, ym - door_w / 2 - 0.5, dh + 0.5), PAPER)
    iso.line((xr, ym + door_w / 2 + 0.5, 0), (xr, ym + door_w / 2 + 0.5, dh + 0.5), PAPER)
    iso.line((xr, ym - door_w / 2 - 0.5, dh + 0.5), (xr, ym + door_w / 2 + 0.5, dh + 0.5), PAPER)

    # Two windows on the lit wall, warm glass with a PAPER frame and an INK mullion.
    for Y0 in (2.5, y1 - 7.0):
        iso.fill([(xr, Y0, 6), (xr, Y0 + 3.5, 6), (xr, Y0 + 3.5, 11), (xr, Y0, 11)], solid(ACCENT))
        iso.line((xr, Y0 + 1.75, 6), (xr, Y0 + 1.75, 11), INK)
        iso.line((xr, Y0, 8.5), (xr, Y0 + 3.5, 8.5), INK)

    if loft_hatch:
        # A square loft hatch in the gable: INK frame, SHADE cross-bracing, a PAPER sill.
        h0, h1 = H + 2.0, H + 6.0
        iso.fill([(xr, ym - 2, h0), (xr, ym + 2, h0), (xr, ym + 2, h1), (xr, ym - 2, h1)], solid(INK))
        iso.line((xr, ym - 2, h0), (xr, ym + 2, h1), SHADE)
        iso.line((xr, ym + 2, h0), (xr, ym - 2, h1), SHADE)
        iso.line((xr, ym - 2.5, h0 - 0.5), (xr, ym + 2.5, h0 - 0.5), PAPER)

    if porch:
        # Porch: two PAPER columns with SHADE edges, a PAPER beam and a DEEP roof slab over a cellar hatch.
        px = L + 8
        for Yc in (ym - 9, ym + 9):
            iso.fill([(px, Yc - 0.7, 0), (px, Yc + 0.7, 0), (px, Yc + 0.7, H - 3), (px, Yc - 0.7, H - 3)], solid(PAPER))
            iso.line((px, Yc + 0.7, 0), (px, Yc + 0.7, H - 3), SHADE)          # shaded edge of the shaft
            iso.line((px, Yc - 0.7, H - 4), (px, Yc + 0.7, H - 4), SHADE)      # capital course
        iso.fill([(xr, ym - 10, H - 3), (px, ym - 10, H - 3), (px, ym + 10, H - 3), (xr, ym + 10, H - 3),
                  (xr, ym + 10, H - 1), (px, ym + 10, H - 1), (px, ym - 10, H - 1), (xr, ym - 10, H - 1)],
                 solid(DEEP))
        iso.line((px, ym - 10, H - 3), (px, ym + 10, H - 3), PAPER)
        # Cellar hatch on the ground in front of the door: a SHADE slab with a LIGHT rim.
        hx0, hx1, hy0, hy1 = L + 2, L + 7, ym - 3.5, ym + 3.5
        iso.fill([(hx0, hy0, 0), (hx1, hy0, 0), (hx1, hy1, 0), (hx0, hy1, 0)], solid(SHADE))
        iso.line((hx0, hy0, 0), (hx1, hy0, 0), LIGHT)
        iso.line((hx0, hy0, 0), (hx0, hy1, 0), LIGHT)
        iso.line((hx0 + 2.5, hy0, 0), (hx0 + 2.5, hy1, 0), EARTH)


def scarecrow() -> Canvas:
    """A scarecrow, 18x34, in the elevated view: a pole, an arm bar running across the field, a shirt, trousers, a
    sack head with its hat crown and brim. The tops show, so it reads from above like the buildings do."""
    cv = Canvas(18, 34)
    iso = Iso(cv, [(4.5, 4.5, 0), (6.5, 6.5, 22), (3, 0, 0), (8, 11, 14), (0, 3, 0), (11, 8, 22)])
    iso.fill([(4.5, 4.5, 0), (5.5, 4.5, 0), (5.5, 4.5, 16), (4.5, 4.5, 16)], solid(EARTH))     # pole, front edge
    iso.fill([(4.5, 4.5, 0), (4.5, 5.5, 0), (4.5, 5.5, 16), (4.5, 4.5, 16)], solid(EARTH))     # pole, side edge
    iso.fill([(4.2, 3.0, 13), (4.8, 3.0, 13), (4.8, 11.0, 13), (4.2, 11.0, 13)], solid(EARTH))  # arm bar, top
    iso.fill([(4.2, 3.0, 11), (4.8, 3.0, 11), (4.8, 11.0, 11), (4.2, 11.0, 11)], solid(SHADE))   # arm bar, underside
    # Trousers.
    iso.fill([(4, 4, 0), (7, 4, 0), (7, 7, 0), (4, 7, 0)], solid(SHADE))
    iso.fill([(4, 4, 0), (7, 4, 0), (7, 4, 7), (4, 4, 7)], solid(SHADE))
    # Shirt: a box with an ACCENT top and lit side, a SHADE dither on the shaded side.
    iso.fill([(3.5, 3.5, 7), (7.5, 3.5, 7), (7.5, 7.5, 7), (3.5, 7.5, 7)], solid(ACCENT))
    iso.fill([(7.5, 3.5, 7), (7.5, 7.5, 7), (7.5, 7.5, 13), (7.5, 3.5, 13)], solid(ACCENT))
    iso.fill([(3.5, 7.5, 7), (7.5, 7.5, 7), (7.5, 7.5, 13), (3.5, 7.5, 13)], dither(SHADE, ACCENT, 0.4))
    iso.fill([(3.5, 3.5, 13), (7.5, 3.5, 13), (7.5, 7.5, 13), (3.5, 7.5, 13)], solid(ACCENT))
    iso.line((3.5, 5.5, 10), (7.5, 5.5, 10), EARTH)                                            # shirt stripe
    # Sack head: PAPER top and lit side, a SHADE dither on the shaded side, two INK eyes.
    iso.fill([(4.5, 4.5, 14), (6.5, 4.5, 14), (6.5, 6.5, 14), (4.5, 6.5, 14)], solid(PAPER))
    iso.fill([(6.5, 4.5, 14), (6.5, 6.5, 14), (6.5, 6.5, 19), (6.5, 4.5, 19)], solid(PAPER))
    iso.fill([(4.5, 6.5, 14), (6.5, 6.5, 14), (6.5, 6.5, 19), (4.5, 6.5, 19)], dither(SHADE, PAPER, 0.4))
    iso.dot((5.0, 4.5, 17), INK)
    iso.dot((6.0, 4.5, 17), INK)
    # Hat: a brim over the head, then a crown.
    iso.fill([(3.5, 3.5, 19), (7.5, 3.5, 19), (7.5, 7.5, 19), (3.5, 7.5, 19)], solid(SHADE))
    iso.fill([(4.5, 4.5, 19), (6.5, 4.5, 19), (6.5, 6.5, 19), (4.5, 6.5, 19)], solid(DEEP))
    iso.fill([(4.5, 4.5, 19), (6.5, 4.5, 19), (6.5, 4.5, 22), (4.5, 4.5, 22)], solid(SHADE))
    cv.outline(INK)
    return cv


def _steps(a: float, b: float, s: float):
    v = a
    while v <= b + 1e-9:
        yield v
        v += s


def barn() -> Canvas:
    """The main barn, 72x56: a gabled hall with a porch on the lit wall, columns, moldings, a loft hatch and a cellar
    hatch. It is the biggest building in the farm and reads first on the walk."""
    cv = Canvas(72, 56)
    gable_building(cv, L=30, W=20, H=16, rise=9, porch=True, loft_hatch=True, door_w=8.0)
    cv.outline(INK)
    return cv


def shed() -> Canvas:
    """A gabled tool shed, 40x34, with a real roof: a ridge, two tiled slopes, a fascia and a plank door."""
    cv = Canvas(40, 34)
    gable_building(cv, L=18, W=14, H=10, rise=6, porch=False, loft_hatch=False, door_w=5.0)
    cv.outline(INK)
    return cv


def hay_bale(variant: int) -> Canvas:
    """A round bale on its side, 16x12, seen from above: an ACCENT disc with straw rings, a cut face and a shaded lower
    rim. variant 1 has a second bale behind it, so stacks read as stacks."""
    cv = Canvas(16, 12)

    def disc(cx: float, cy: float, rx: float, ry: float) -> None:
        for y in range(12):
            for x in range(16):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                    rim = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 > 0.6 and y + 0.5 > cy
                    cv.set(x, y, SHADE if rim and bayer(x, y) < 0.5 else ACCENT)

    if variant == 1:
        disc(9, 3, 4.5, 2.6)
        cv.rect(5, 3, 13, 3, LIGHT)
    disc(8, 7, 6.8, 4.4)
    for k in (-3.5, -1.0, 1.5):                       # straw rings across the top of the bale
        cv.seg(8 + k, 4, 8 + k + 1.5, 9, LIGHT)
    cv.ellipse(8, 7, 2.6, 1.8, EARTH)                 # the cut face
    cv.ellipse(8, 7, 1.2, 0.8, SHADE)
    cv.outline(INK)
    return cv


def cart() -> Canvas:
    """A two-wheeled hay cart, 28x20, its bed on the ground with a heaped load and a shaft toward +X."""
    cv = Canvas(28, 20)
    iso = Iso(cv, [(0, 0, 0), (8, 5, 0), (8, 0, 0), (0, 5, 0), (0, 0, 8), (8, 5, 6), (13, 2.5, 4)])
    # Wheels first: the far one is hidden by the bed.
    for Y in (-0.5, 5.5):
        wx, wy = iso.p(4, Y, 3.5)
        cv.ellipse(wx, wy, 3.6, 3.6, INK)
        cv.ellipse(wx, wy, 1.5, 1.5, SHADE)
    iso.line((8, 2.5, 4), (13, 2.5, 2.5), EARTH)        # shaft
    iso.fill([(0, 0, 6), (8, 0, 6), (8, 5, 6), (0, 5, 6)], solid(EARTH))              # bed top
    iso.fill([(8, 0, 3), (8, 5, 3), (8, 5, 6), (8, 0, 6)], solid(EARTH))              # lit side
    iso.fill([(0, 5, 3), (8, 5, 3), (8, 5, 6), (0, 5, 6)], dither(SHADE, EARTH, 0.45))  # shaded side
    iso.line((0, 0, 6), (8, 0, 6), PAPER)                # rim
    iso.line((0, 5, 6), (8, 5, 6), PAPER)
    for X in (3, 6):
        iso.line((X, 5, 3), (X, 5, 6), SHADE)
    hx, hy = iso.p(4, 2.5, 6.5)
    cv.ellipse(hx, hy, 6.0, 3.0, ACCENT)                # hay load
    for k in (-3, 0, 3):
        cv.set(int(round(hx + k)), int(round(hy - 1)), LIGHT)
    cv.outline(INK)
    return cv


def crates() -> Canvas:
    """Two crates, 12x12: a full crate on the ground and a smaller one on its shoulder."""
    cv = Canvas(12, 12)
    iso = Iso(cv, [(0, 0, 0), (4, 4, 0), (4, 0, 0), (0, 4, 0), (0, 0, 3), (4, 4, 3), (0, 0, 5), (2, 2, 5)])
    # Ground crate: lit side, shaded side, top with a slat.
    iso.fill([(4, 0, 0), (4, 4, 0), (4, 4, 3), (4, 0, 3)], solid(EARTH))
    iso.fill([(0, 4, 0), (4, 4, 0), (4, 4, 3), (0, 4, 3)], dither(SHADE, EARTH, 0.45))
    iso.fill([(0, 0, 3), (4, 0, 3), (4, 4, 3), (0, 4, 3)], solid(ACCENT))
    iso.line((2, 0, 3), (2, 4, 3), EARTH)
    # Smaller crate on the shoulder, set back.
    iso.fill([(2, 0.2, 3), (4, 0.2, 3), (4, 2, 3), (2, 2, 3)], solid(EARTH))
    iso.fill([(2, 0.2, 3), (4, 0.2, 3), (4, 0.2, 5), (2, 0.2, 5)], solid(SHADE))
    cv.outline(INK)
    return cv
