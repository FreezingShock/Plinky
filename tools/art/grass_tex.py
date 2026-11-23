"""Plinky grass texture: light offsets for grass texels, in world-anchored image space (the baked ground is
world-aligned, so every pattern here is pinned to the world). Pure numpy.
apply(style, l, mask, XX, YY, noise) returns l with the grass design added; the caller dithers it through the
grass ramp [1, 2, 3, 3, 4] (dark teal, mid, mid, light). Offsets: DARK crosses to ramp 2, LIGHT crosses to ramp 4."""
import numpy as np

DARK, LIGHT = -.38, .22


def _h(ix, iy, s):
    n = (ix.astype(np.int64) * 374761393 + iy.astype(np.int64) * 668265263 + np.int64(s) * 2147483647) & 0xffffffff
    n = ((n ^ (n >> 13)) * 1274126177) & 0xffffffff
    return ((n ^ (n >> 16)) & 0xffff) / 65535.0


def _anchors(W, H, cw, ch, seed):
    gx, gy = np.meshgrid(np.arange(-1, W // cw + 2), np.arange(-1, H // ch + 2))
    px = gx * cw + np.floor(_h(gx, gy, seed) * cw).astype(int)
    py = gy * ch + np.floor(_h(gx, gy, seed + 1) * ch).astype(int)
    return px.ravel(), py.ravel(), _h(gx, gy, seed + 2).ravel()


def _stamp(D, px, py, shape):
    H, W = D.shape
    for dx, dy, val in shape:
        x, y = px + dx, py + dy
        ok = (x >= 0) & (x < W) & (y >= 0) & (y < H)
        np.add.at(D, (y[ok], x[ok]), val)


def style_clusters(XX, YY, nz):
    """A: blade tufts that gather into clumps, with open lawn between and soft broad value drift."""
    H, W = XX.shape; fbm2 = nz['fbm2']
    D = (fbm2(XX / 34.0, YY * 2 / 34.0, 3, 71) - .5) * .30            # broad drift, crosses the 3/4 line only on its crests
    px, py, r = _anchors(W, H, 6, 4, 11)
    dens = fbm2(px / 24.0, py * 2 / 24.0, 3, 72)                       # clumping: tufts gather where this is high
    keep = r < np.clip((dens - .38) * 3.2, 0, .92)
    px, py, r2 = px[keep], py[keep], r[keep]
    big = (r2 * 7919 % 1.0) < .5
    T = np.zeros((H, W))
    for sel, shape in ((big, [(0, -3, LIGHT), (0, -2, LIGHT), (0, -1, LIGHT), (-2, -2, LIGHT), (-2, -1, LIGHT), (2, -2, LIGHT), (2, -1, LIGHT),
                              (-1, 0, DARK), (0, 0, DARK), (1, 0, DARK), (2, 0, DARK)]),
                       (~big, [(0, -2, LIGHT), (0, -1, LIGHT), (1, -1, LIGHT), (0, 0, DARK), (1, 0, DARK), (-1, 0, DARK)])):
        _stamp(T, px[sel], py[sel], shape)
    return D + np.clip(T, DARK, LIGHT)


def style_bands(XX, YY, nz):
    """B: noise-driven soft value bands (ellipses on the iso plane), sparse single flicks, no tufts."""
    H, W = XX.shape; fbm2 = nz['fbm2']; vn2 = nz['vn2']
    wx = (vn2(XX / 19.0, YY * 2 / 19.0, 81) - .5) * 14; wy = (vn2(XX / 19.0, YY * 2 / 19.0, 82) - .5) * 14
    a = fbm2((XX + wx) / 30.0, (YY * 2 + wy) / 30.0, 3, 83)
    b = fbm2((XX - wy) / 11.0, (YY * 2 + wx) / 11.0, 2, 84)
    D = (a - .5) * .62 + (b - .5) * .20
    px, py, r = _anchors(W, H, 9, 6, 21)
    keep = r < .30 * np.clip((fbm2(px / 30.0, py * 2 / 30.0, 2, 85) - .3) * 3, 0, 1) + .06
    T = np.zeros((H, W))
    _stamp(T, px[keep], py[keep], [(0, -1, LIGHT), (1, -1, LIGHT), (0, 0, DARK * .8)])
    return D + T


def style_strokes(XX, YY, nz):
    """C: short 2:1 iso dashes in drifting directional fields (hatching), shadow dash under each."""
    H, W = XX.shape; fbm2 = nz['fbm2']
    D = (fbm2(XX / 40.0, YY * 2 / 40.0, 3, 91) - .5) * .26
    px, py, r = _anchors(W, H, 7, 4, 31)
    dens = fbm2(px / 20.0, py * 2 / 20.0, 3, 92)
    keep = r < np.clip((dens - .30) * 3.0, 0, .95)
    px, py, r = px[keep], py[keep], r[keep]
    dirn = fbm2(px / 46.0, py * 2 / 46.0, 2, 93) > .5
    T = np.zeros((H, W))
    for sel, s in ((dirn, 1), (~dirn, -1)):
        _stamp(T, px[sel], py[sel], [(0, 0, LIGHT), (s, 0, LIGHT), (2 * s, 1, LIGHT), (3 * s, 1, LIGHT), (s, 1, DARK), (2 * s, 2, DARK), (3 * s, 2, DARK)])
    return D + np.clip(T, DARK, LIGHT)


def style_clumps(XX, YY, nz):
    """D: iso-plane Voronoi clumps. Lit rim top-left, dark seams between clumps, per-clump tone, ragged edges."""
    H, W = XX.shape; vn2 = nz['vn2']
    s = YY * 2.0; d = XX.astype(float)
    u = (s + d) / 2 + (vn2(XX / 7.0, YY / 4.0, 61) - .5) * 3.2; v = (s - d) / 2 + (vn2(XX / 7.0, YY / 4.0, 62) - .5) * 3.2
    cs = 5.2
    iu, iv = np.floor(u / cs), np.floor(v / cs)
    f1 = np.full(u.shape, 1e9); f2 = np.full(u.shape, 1e9); sx = np.zeros(u.shape); sy = np.zeros(u.shape); tone = np.zeros(u.shape)
    for ox in (-1, 0, 1):
        for oy in (-1, 0, 1):
            cu, cv = iu + ox, iv + oy
            su = (cu + .15 + .7 * _h(cu, cv, 41)) * cs; sv = (cv + .15 + .7 * _h(cu, cv, 42)) * cs
            dist = np.hypot(u - su, v - sv)
            new = dist < f1
            f2 = np.where(new, f1, np.minimum(f2, dist)); sx = np.where(new, su, sx); sy = np.where(new, sv, sy)
            tone = np.where(new, _h(cu, cv, 43), tone); f1 = np.where(new, dist, f1)
    gap = (f2 - f1) / cs
    rel_x = ((u - sx) - (v - sy)) / (cs * .5); rel_y = ((u - sx) + (v - sy)) / cs      # screen-space offset inside the clump
    lit = np.clip(-(rel_x * .45 + rel_y * .9), -1, 1)
    D = (tone - .5) * .26 + lit * .30 - np.clip((.20 - gap) / .20, 0, 1) * .55
    return D


STYLES = {'a': style_clusters, 'b': style_bands, 'c': style_strokes, 'd': style_clumps}


def apply(style, l, mask, XX, YY, nz):
    if style not in STYLES:
        return l
    return np.where(mask, l + STYLES[style](XX, YY, nz), l)
