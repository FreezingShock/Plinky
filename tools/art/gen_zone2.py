#!/usr/bin/env python3
"""Zone 2 art: concept mockups and the Ember Quarry blockout. numpy + Pillow only.

  python3 tools/art/gen_zone2.py concepts OUTDIR   three 640x360 concept mockups plus a contact sheet
  python3 tools/art/gen_zone2.py quarry            writes assets/art/zone2/quarry/ (ground, walkable, sprites, json)

Same projection as gen_meadow3d.py: screen = (320 + u - v, 4 + (u + v) / 2 - h) in the 640x360 frame, ground
frame is 840x480 placed at (-100,-60). Terrain is a height field drawn back to front, props are prisms and blobs
on top of it. Shade is dithered with the 4x4 Bayer matrix into the zone's 8-colour palette (indices only).
"""
import json, math, os, sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
N = 400
CU = CV = 200.0
R = 182.0
OX, OY = 100, 60            # ground frame offset (bleed)
GW, GH = 840, 480
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
PALS = {
    'quarry': ['1a1116', '4a1f2a', '8a3a2e', 'd0602f', 'e9a845', 'b77a7a', '5b3d5c', 'f1d9b5'],
    'tidewater': ['0d1420', '13324a', '1f6378', '46a3a0', '9fd4b5', 'f7d37a', 'e67e6b', 'dfeee8'],
    'hollow': ['0e0b16', '2a2340', '2f4a52', '4f8a6e', 'a4d37c', 'f2e68a', 'b8567a', 'efe6e0'],
}
LD = np.array([-0.42, 0.46, 0.78]); LD /= np.linalg.norm(LD)


def pal(name):
    return np.array([[int(h[k:k + 2], 16) for k in (0, 2, 4)] for h in PALS[name]], np.uint8)


def h2(ix, iy, s):
    n = (ix * 374761393 + iy * 668265263 + s * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def vnoise(x, y, s=0):
    xi = np.floor(x).astype(np.int64); yi = np.floor(y).astype(np.int64)
    fx = x - xi; fy = y - yi
    fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy)
    a, b, c, d = h2(xi, yi, s), h2(xi + 1, yi, s), h2(xi, yi + 1, s), h2(xi + 1, yi + 1, s)
    return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fy


def fbm(x, y, o=4, s=0):
    t = 0.0; amp = 1.0; tot = 0.0
    for i in range(o):
        t = t + amp * vnoise(x, y, s + i * 7); tot += amp; x = x * 2.03; y = y * 2.03; amp *= 0.5
    return t / tot


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def blur(A, k=2):
    for _ in range(k):
        A = (A + np.roll(A, 1, 0) + np.roll(A, -1, 0) + np.roll(A, 1, 1) + np.roll(A, -1, 1)) / 5.0
    return A


def wd_uv(w, d):
    """(w, d): w = (u+v)/2 - 200 (negative = far), d = u - v. Returns u, v."""
    return 200 + w + d / 2.0, 200 + w - d / 2.0


def polyline_dist(U, V, pts):
    best = np.full(U.shape, 1e9)
    for (ax, ay), (bx, by) in zip(pts[:-1], pts[1:]):
        dx, dy = bx - ax, by - ay
        L2 = dx * dx + dy * dy + 1e-9
        t = np.clip(((U - ax) * dx + (V - ay) * dy) / L2, 0, 1)
        best = np.minimum(best, np.hypot(U - (ax + t * dx), V - (ay + t * dy)))
    return best


UU, VV = np.meshgrid(np.arange(N, dtype=np.float64), np.arange(N, dtype=np.float64), indexing='ij')
RR = np.hypot(UU - CU, VV - CV)
TH = np.arctan2(VV - CV, UU - CU)
RE = R * (1 + .07 * np.sin(3 * TH + 1.0) + .05 * np.sin(5 * TH + 2.3) + .03 * np.sin(9 * TH + .5))

# terrain materials
M_FLOOR, M_WALL, M_PATH, M_LAVA, M_SEAM, M_VENT, M_SAND, M_WATER, M_PLANK, M_GRASS, M_DIKE = range(11)
# prop materials
P_SPIRE, P_BOULDER, P_CRYSTAL, P_BLOCK, P_WOOD, P_CANOPY, P_SALT, P_GLOW, P_TRUNK = range(20, 29)
RAMPS = {  # palette index ramps, dark to light
    'quarry': {M_FLOOR: [0, 1, 1, 2, 6], M_WALL: [0, 0, 1, 1, 6], M_PATH: [6, 5, 5, 7, 7], M_LAVA: [2, 3, 3, 4, 4],
               M_SEAM: [2, 3, 4, 4, 7], M_VENT: [3, 3, 4, 4, 7], P_SPIRE: [0, 1, 6, 6, 5], P_BOULDER: [0, 1, 6, 5, 5],
               P_CRYSTAL: [2, 3, 4, 4, 7], P_BLOCK: [1, 6, 5, 5, 7], P_WOOD: [0, 1, 2, 3, 4], P_GLOW: [3, 4, 4, 7, 7]},
    'tidewater': {M_FLOOR: [1, 2, 2, 3, 3], M_WALL: [0, 1, 1, 2, 2], M_PATH: [6, 5, 5, 7, 7], M_SAND: [5, 5, 7, 7, 7],
                  M_WATER: [1, 2, 2, 3, 4], M_PLANK: [1, 6, 6, 5, 5], M_DIKE: [2, 3, 5, 7, 7], P_SALT: [3, 4, 7, 7, 7],
                  P_WOOD: [1, 6, 6, 5, 5], P_BOULDER: [1, 2, 3, 3, 4], P_GLOW: [4, 5, 5, 7, 7], P_SPIRE: [1, 2, 3, 4, 7]},
    'hollow': {M_FLOOR: [1, 1, 2, 2, 3], M_WALL: [0, 1, 1, 2, 2], M_PATH: [6, 6, 5, 5, 7], M_GRASS: [1, 2, 2, 3, 3],
               M_WATER: [1, 2, 2, 3, 4], P_CANOPY: [1, 2, 2, 3, 3], P_TRUNK: [0, 1, 1, 6, 6], P_GLOW: [4, 5, 5, 7, 7],
               P_BOULDER: [0, 1, 2, 2, 3], P_SPIRE: [1, 2, 3, 4, 4]},
}


class Scene:
    def __init__(self, palette):
        self.pal = palette
        self.H = np.zeros((N, N)); self.M = np.full((N, N), M_FLOOR, np.int32)
        self.walk = np.ones((N, N), bool)
        self.PT = np.full((N, N), -1e9); self.PM = np.zeros((N, N), np.int32); self.PI = np.zeros((N, N), np.int32)
        self.nid = 0
        self.props = []   # dicts: id, kind, u, v, tall, cells

    def prop(self, kind, u, v, mat, tall=False, shape='oct', r=3.0, height=20.0, base=None, taper=0.0, tilt=0.0, jitter=0.0):
        """Prism or blob. Height is added on the terrain under the centre unless base is given."""
        self.nid += 1
        pid = self.nid
        iu, iv = int(round(u)), int(round(v))
        b = self.H[iu, iv] if base is None else base
        rr = int(math.ceil(r)) + 1
        n_cells = 0
        for du in range(-rr, rr + 1):
            for dv in range(-rr, rr + 1):
                x, y = iu + du, iv + dv
                if not (0 <= x < N and 0 <= y < N):
                    continue
                if shape == 'oct':
                    q = max(abs(du), abs(dv), (abs(du) + abs(dv)) * 0.72)
                    ok = q <= r
                    top = b + height * (1 - taper * (q / max(r, 1e-6)) ** 2) + jitter * (h2(x, y, pid) - .5)
                elif shape == 'sphere':
                    dd = math.hypot(du, dv)
                    ok = dd <= r
                    top = b + height - r + math.sqrt(max(r * r - dd * dd, 0)) if ok else 0
                elif shape == 'dome':
                    dd = math.hypot(du, dv)
                    ok = dd <= r
                    top = b + height * math.sqrt(max(1 - (dd / r) ** 2, 0)) if ok else 0
                elif shape == 'cone':
                    dd = math.hypot(du, dv)
                    ok = dd <= r
                    top = b + height * (1 - dd / r) if ok else 0
                else:
                    ok = abs(du) <= r and abs(dv) <= r
                    top = b + height
                if ok and top > self.PT[x, y]:
                    self.PT[x, y] = top; self.PM[x, y] = mat; self.PI[x, y] = pid
                    n_cells += 1
        self.props.append(dict(id=pid, kind=kind, u=u, v=v, tall=tall, foot=b))
        return pid

    # ---------------------------------------------------------------- rendering
    def render(self, only_prop=None, skip_tall=False):
        H = self.H
        Hs = blur(H, 1)
        gu, gv = np.gradient(Hs)
        nrm = np.stack([-gu, -gv, np.ones_like(H)], -1)
        nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
        lam = np.clip(nrm @ LD, 0, 1)
        cav = np.clip((blur(H, 6) - H) / 7.0, 0, 1)
        slope = np.hypot(gu, gv)
        top_h = H.copy(); top_m = self.M.copy(); top_id = np.zeros((N, N), np.int32)
        pt, pm, pi = self.PT, self.PM, self.PI
        tall_ids = {p['id'] for p in self.props if p['tall']}
        if only_prop is not None:
            use = pi == only_prop
        elif skip_tall:
            use = (pt > H) & ~np.isin(pi, list(tall_ids))
        else:
            use = pt > H
        top_h = np.where(use, pt, H); top_m = np.where(use, pm, self.M); top_id = np.where(use, pi, 0)
        # prop top shade: flat lambert of an up normal plus a little noise so tops catch the light
        shade_c = np.where(use, 0.62 + 0.25 * (h2(UU.astype(np.int64), VV.astype(np.int64), 3) - .5), lam * 0.75 + 0.2 - cav * 0.45)
        # face exposure
        hp_u = np.roll(top_h, -1, 0); hp_v = np.roll(top_h, -1, 1)
        nd_u = np.maximum(0, top_h - hp_u); nd_v = np.maximum(0, top_h - hp_v)
        face_s = blur(np.where(nd_u + nd_v > 1e-6, (0.22 * nd_u + 0.68 * nd_v) / (nd_u + nd_v + 1e-9), 0.4), 4)
        drop = np.maximum(nd_u, nd_v)
        S = np.zeros((GH, GW)); Mat = np.full((GH, GW), -1, np.int32); F = np.zeros((GH, GW), np.int8)
        ID = np.zeros((GH, GW), np.int32); DR = np.zeros((GH, GW))
        only = only_prop is not None
        for s in range(0, 2 * N - 1):
            ulo, uhi = max(0, s - N + 1), min(N - 1, s)
            for u in range(ulo, uhi + 1):
                v = s - u
                if only and top_id[u, v] != only_prop:
                    continue
                x = int(320 + u - v + OX)
                if x < 0 or x >= GW:
                    continue
                h = top_h[u, v]
                y0 = int(math.floor(4 + s / 2.0 - h + OY))
                base = int(math.floor(4 + s / 2.0 - (H[u, v] if use[u, v] else 0.0) + OY)) if only else GH + 40
                if not only:
                    base = int(y0 + max(h, 0) + 3)
                if y0 >= GH or base < 0:
                    continue
                ya, yb = max(y0, 0), min(base, GH)
                if yb <= ya:
                    continue
                m = int(top_m[u, v])
                S[ya:yb, x] = face_s[u, v]; Mat[ya:yb, x] = m; F[ya:yb, x] = 1; ID[ya:yb, x] = top_id[u, v]; DR[ya:yb, x] = drop[u, v]
                if y0 >= 0:
                    S[y0, x] = shade_c[u, v]; F[y0, x] = 0
                # strata bands on faces
                if yb - ya > 1:
                    ys = np.arange(max(ya, y0 + 1), yb)
                    S[ys, x] = S[ys, x] - 0.07 * (((ys) // 4) % 3 == 0) * (drop[u, v] < 30)
        return S, Mat, F, ID, DR, (top_h, top_m, slope, use)

    def shade_to_index(self, S, Mat, F, ID, DR, extra=None):
        ramps = RAMPS[self.pal]
        out = np.zeros((GH, GW), np.uint8)
        alpha = Mat >= 0
        yy, xx = np.mgrid[0:GH, 0:GW]
        th = BAYER[yy % 4, xx % 4]
        for m, ramp in ramps.items():
            sel = alpha & (Mat == m)
            if not sel.any():
                continue
            ln = len(ramp) - 1
            pos = np.clip(S[sel], 0, 0.999) * ln + (th[sel] - .5) * 0.9
            idx = np.clip(np.floor(pos + .5).astype(int), 0, ln)
            out[sel] = np.array(ramp, np.uint8)[idx]
        # fallback for unknown materials
        miss = alpha & ~np.isin(Mat, list(ramps.keys()))
        out[miss] = 6
        # ink outlines: prop silhouettes and the base of tall cliffs
        edge = np.zeros((GH, GW), bool)
        pid = ID
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sh = np.roll(np.roll(pid, dy, 0), dx, 1)
            edge |= (pid > 0) & (sh != pid)
            ash = np.roll(np.roll(alpha, dy, 0), dx, 1)
            edge |= alpha & ~ash
        below = np.roll(F, -1, 0)
        cliff_base = (F == 1) & (below == 0) & (DR > 5) & alpha
        edge |= cliff_base
        out[edge & alpha] = 0
        # warm rim light on the lip of cliffs
        above = np.roll(F, 1, 0)
        lip = (F == 1) & (above == 0) & (DR > 5) & alpha & (pid == 0)
        out[lip & ~edge] = 5 if self.pal == 'quarry' else 4
        return out, alpha

    def terrain_masks(self):
        return None


def to_rgba(idx, alpha, palette):
    cols = pal(palette)
    img = np.zeros((GH, GW, 4), np.uint8)
    img[..., :3] = cols[idx]
    img[..., 3] = np.where(alpha, 255, 0)
    return Image.fromarray(img, 'RGBA')


# ---------------------------------------------------------------- Ember Quarry
TIER_H = 21.0
BOUNDS_W = (70.0, 10.0, -50.0)         # tier boundaries along w (near to far); tier 0 is nearest and lowest
PATH_WD = [(128, -10), (112, -44), (92, -52), (70, -48), (52, -10), (36, 44), (14, 50), (0, 18), (-14, -40), (-34, -48),
           (-52, -36), (-72, 0), (-98, 12)]
PADS_WD = [(102, -46), (36, 40), (-30, -42)]
VENTS_WD = [(110, 14), (50, 72), (-22, -4)]
GATE_WD = (-100, 12)
SPAWN_WD = (128, -12)


def build_quarry(seed=0):
    sc = Scene('quarry')
    path_pts = [wd_uv(w, d) for w, d in PATH_WD]
    dpath = polyline_dist(UU, VV, path_pts)
    corridor = blur(smooth(30, 8, dpath), 3)           # 1 on the path, 0 away from it
    w = (UU + VV) / 2 - 200
    d = UU - VV
    wob = (fbm(UU / 38.0, VV / 38.0, 3, 11) - .5) * 34 + np.sin(d / 55.0) * 9
    H = np.zeros((N, N))
    for k, bw in enumerate(BOUNDS_W):
        wid = 2.2 + 26.0 * corridor
        H += TIER_H * smooth(bw - wid, bw + wid, -w + wob * 0.55 + (-bw + bw) ) if False else TIER_H * smooth(-bw - wid, -bw + wid, -w + wob * 0.55) * 0 + 0
    # rebuild: height rises as w falls. step k sits at w = bw (+wobble)
    H = np.zeros((N, N))
    for bw in BOUNDS_W:
        wid = 2.0 + 24.0 * corridor
        H += TIER_H * smooth(bw + wob * 0.6 + wid, bw + wob * 0.6 - wid, w)
    # rough floors and rock noise
    H += (fbm(UU / 9.0, VV / 9.0, 3, 5) - .5) * 2.4 * (1 - corridor * .7)
    # lava pools (carved) and seams
    pools = [(wd_uv(40, -58), 13.0), (wd_uv(-18, 62), 13.0), (wd_uv(-78, -44), 11.0)]
    lava = np.zeros((N, N), bool)
    for (pu, pv), pr in pools:
        rr = np.hypot(UU - pu, VV - pv) + (fbm(UU / 8.0, VV / 8.0, 2, 21) - .5) * 6
        lava |= rr < pr
        H -= 5.0 * smooth(pr + 4, pr - 5, rr)
    ridge = np.abs(fbm(UU / 17.0, VV / 17.0, 3, 31) - .5)
    seam = (ridge < 0.011) & (corridor < 0.5) & (dpath > 16)
    # rim wall (the quarry bowl)
    rim = smooth(RE * 0.97, RE * 1.06, RR)
    H += rim * (50 + 22 * fbm(UU / 30.0, VV / 30.0, 2, 41))
    outer = smooth(RE * 1.06, RE * 1.5, RR)
    H += outer * 40
    sc.H = H
    slope = np.hypot(*np.gradient(blur(H, 1)))
    M = np.full((N, N), M_FLOOR, np.int32)
    M[slope > 0.9] = M_WALL
    M[rim > 0.35] = M_WALL
    M[seam & (M == M_FLOOR)] = M_SEAM
    M[(dpath < 6.2) & (slope < 0.95) & (rim < .2)] = M_PATH
    M[lava] = M_LAVA
    vents = [wd_uv(*v) for v in VENTS_WD]
    for vu, vv in vents:
        M[np.hypot(UU - vu, VV - vv) < 7.5] = M_VENT
    sc.M = M
    walk = (slope < 0.9) & (rim < 0.12) & ~lava & np.isin(M, [M_FLOOR, M_PATH, M_SEAM, M_VENT])
    sc.walk = walk
    sc.paths = (path_pts, vents)
    return sc


def blocked_disc(sc, u, v, r):
    iu, iv = int(round(u)), int(round(v))
    k = int(math.ceil(r)) + 1
    u0, u1, v0, v1 = max(iu - k, 0), min(iu + k + 1, N), max(iv - k, 0), min(iv + k + 1, N)
    sc.walk[u0:u1, v0:v1] &= ~(np.hypot(UU[u0:u1, v0:v1] - u, VV[u0:u1, v0:v1] - v) <= r)


def pad_clear(sc, wd, r=14):
    u, v = wd_uv(*wd)
    return all(math.hypot(u - pu, v - pv) > r for pu, pv in [wd_uv(*p) for p in PADS_WD + [GATE_WD, SPAWN_WD]])


def populate_quarry(sc, rng):
    path_pts, vents = sc.paths
    dpath = polyline_dist(UU, VV, path_pts)
    anchor_pts = [wd_uv(*p) for p in PADS_WD + VENTS_WD + [GATE_WD, SPAWN_WD]]

    def free(u, v, r, pad=14, vent=11, pathgap=9, lavagap=3):
        iu, iv = int(round(u)), int(round(v))
        if not (6 < iu < N - 6 and 6 < iv < N - 6):
            return False
        if not sc.walk[iu, iv] or RR[iu, iv] > RE[iu, iv] * 0.9:
            return False
        if dpath[iu, iv] < pathgap + r:
            return False
        for au, av in anchor_pts:
            if math.hypot(u - au, v - av) < pad + r:
                return False
        if sc.M[iu, iv] in (M_LAVA, M_VENT):
            return False
        for p in sc.props:
            if math.hypot(u - p['u'], v - p['v']) < r + 2.5:
                return False
        return True

    def scatter(n, region, fn, tries=300):
        (wlo, whi), (dlo, dhi) = region
        done = 0
        for _ in range(tries):
            if done >= n:
                break
            ww = rng.uniform(wlo, whi); dd = rng.uniform(dlo, dhi)
            u, v = wd_uv(ww, dd)
            if fn(u, v):
                done += 1
        return done

    def spire_cluster(u, v):
        if not free(u, v, 5):
            return False
        n = rng.integers(2, 5)
        for i in range(n):
            a = rng.uniform(0, 6.28); rr = 0 if i == 0 else rng.uniform(4, 8)
            su, sv = u + math.cos(a) * rr, v + math.sin(a) * rr
            r = rng.uniform(2.6, 4.2)
            hgt = rng.uniform(22, 56) if i else rng.uniform(40, 62)
            sc.prop('spire', su, sv, P_SPIRE, tall=True, r=r, height=hgt, taper=0.12, jitter=3.0)
        return True

    def boulder(u, v):
        if not free(u, v, 4, pathgap=6):
            return False
        sc.prop('boulder', u, v, P_BOULDER, tall=False, shape='sphere', r=rng.uniform(3.0, 5.2), height=rng.uniform(6, 9))
        return True

    def crystals(u, v):
        if not free(u, v, 5, pathgap=8):
            return False
        for i in range(rng.integers(2, 5)):
            a = rng.uniform(0, 6.28); rr = rng.uniform(0, 5)
            sc.prop('crystal', u + math.cos(a) * rr, v + math.sin(a) * rr, P_CRYSTAL, tall=False, shape='cone', r=rng.uniform(1.8, 3.0), height=rng.uniform(10, 24))
        return True

    def blocks(u, v):
        if not free(u, v, 5, pathgap=7):
            return False
        for i in range(rng.integers(1, 4)):
            sc.prop('block', u + rng.uniform(-4, 4), v + rng.uniform(-4, 4), P_BLOCK, tall=False, shape='box', r=rng.uniform(2.4, 3.6), height=rng.uniform(4, 8))
        return True

    def post(u, v):
        if not free(u, v, 2, pathgap=7):
            return False
        sc.prop('post', u, v, P_WOOD, tall=False, shape='box', r=0.9, height=rng.uniform(14, 20))
        return True

    # tall basalt: tier edges and far corners, never on the path
    scatter(5, ((-150, 140), (-150, 150)), spire_cluster, 800)
    scatter(14, ((-150, 140), (-170, 170)), lambda u, v: spire_cluster(u, v) if rng.random() < 0.5 else boulder(u, v), 1500)
    scatter(8, ((-140, 140), (-160, 160)), crystals, 800)
    scatter(9, ((-140, 140), (-160, 160)), blocks, 800)
    scatter(10, ((-140, 140), (-130, 130)), boulder, 800)
    # posts lining the path
    for (pu, pv), (qu, qv) in zip(path_pts[:-1:2], path_pts[1::2]):
        for off in (-1, 1):
            u, v = (pu + qu) / 2 + off * 9, (pv + qv) / 2 - off * 9
            post(u, v)
    # gate arch: two tall pillars and a lintel
    gu, gv = wd_uv(*GATE_WD)
    sc.prop('gate_pillar', gu - 13, gv + 13, P_SPIRE, tall=True, shape='box', r=3.2, height=46)
    sc.prop('gate_pillar', gu + 13, gv - 13, P_SPIRE, tall=True, shape='box', r=3.2, height=46)
    for j in range(-3, 4):
        sc.prop('lintel', gu + j * 3.5, gv - j * 3.5, P_BLOCK, tall=True, shape='box', r=2.2, height=6, base=sc.H[int(gu), int(gv)] + 46)
    blocked_disc(sc, gu - 13, gv + 13, 5); blocked_disc(sc, gu + 13, gv - 13, 5)


def finalize_props_walk(sc):
    for p in sc.props:
        if p['kind'] in ('spire', 'boulder', 'crystal', 'block', 'gate_pillar'):
            blocked_disc(sc, p['u'], p['v'], 4.5 if p['kind'] != 'boulder' else 5.2)


def screen_of(sc, u, v):
    h = float(sc.H[int(round(u)), int(round(v))])
    return 320 + u - v, 4 + (u + v) / 2 - h


def bake_quarry(outdir, preview=None):
    rng = np.random.default_rng(7)
    sc = build_quarry()
    populate_quarry(sc, rng)
    finalize_props_walk(sc)
    os.makedirs(os.path.join(outdir, 'sprites'), exist_ok=True)
    # ground: terrain plus short props, no tall props
    S, Mat, F, ID, DR, aux = sc.render(skip_tall=True)
    idx, alpha = sc.shade_to_index(S, Mat, F, ID, DR)
    # unpainted pixels (outside the sampled grid) take the darkest rock
    idx = np.where(alpha, idx, 0)
    Image.fromarray(np.stack([pal('quarry')[idx][..., c] for c in range(3)], -1), 'RGB').save(os.path.join(outdir, 'ground.png'))
    ground_idx = idx
    # walk mask in screen space: visible top pixels over walkable cells
    walk_img = np.zeros((GH, GW), bool)
    top_h = aux[0]
    cellwalk = sc.walk
    cells = np.argwhere(cellwalk)
    for u, v in cells:
        x = int(320 + u - v + OX); y = int(math.floor(4 + (u + v) / 2.0 - top_h[u, v] + OY))
        if 0 <= x < GW and 0 <= y < GH:
            walk_img[y, x] = True
    # visibility: a walkable top pixel must still be a top pixel in the render
    walk_img &= (F == 0)
    for _ in range(2):   # close pinholes
        g = walk_img.copy()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            g |= np.roll(np.roll(walk_img, dy, 0), dx, 1) & np.roll(np.roll(walk_img, 2 * dy, 0), 2 * dx, 1)
        walk_img = g & (alpha) & (Mat != M_LAVA) | (walk_img)
    # veto pixels covered by any prop sprite footprint base: props block through the cell mask already
    Image.fromarray((walk_img * 255).astype(np.uint8), 'L').convert('RGB').save(os.path.join(outdir, 'walkable.png'))
    # tall sprites
    sprites = []
    full_comp = ground_idx.copy()
    for p in sorted([p for p in sc.props if p['tall']], key=lambda q: q['u'] + q['v']):
        S2, M2, F2, I2, D2, _ = sc.render(only_prop=p['id'])
        i2, a2 = sc.shade_to_index(S2, M2, F2, I2, D2)
        ys, xs = np.where(a2)
        if len(xs) == 0:
            continue
        x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        rgba = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
        rgba[..., :3] = pal('quarry')[i2[y0:y1, x0:x1]]
        rgba[..., 3] = np.where(a2[y0:y1, x0:x1], 255, 0)
        name = 'sprites/%s_%03d.png' % (p['kind'], p['id'])
        Image.fromarray(rgba, 'RGBA').save(os.path.join(outdir, name))
        fx = 320 + p['u'] - p['v']; fy = 4 + (p['u'] + p['v']) / 2.0 - p['foot']
        sprites.append(dict(file=name, kind=p['kind'], x=int(x0 - OX), y=int(y0 - OY), w=int(x1 - x0), h=int(y1 - y0),
                            foot=[round(fx, 1), round(fy, 1)], sort_y=round(fy, 1)))
        sel = a2
        full_comp = np.where(sel, i2, full_comp)
    Image.fromarray(np.stack([pal('quarry')[full_comp][..., c] for c in range(3)], -1), 'RGB').crop((OX, OY, OX + 640, OY + 360)).save(os.path.join(outdir, 'preview_full.png'))
    # anchors
    anchors = []
    for i, wd in enumerate(PADS_WD):
        u, v = wd_uv(*wd); sx, sy = screen_of(sc, u, v)
        anchors.append(dict(kind='pad', state='ready', u=u, v=v, sx=round(sx, 1), sy=round(sy, 1)))
    gu, gv = wd_uv(*GATE_WD); sx, sy = screen_of(sc, gu, gv)
    anchors.append(dict(kind='gate', u=gu, v=gv, sx=round(sx, 1), sy=round(sy, 1)))
    su, sv = wd_uv(*SPAWN_WD); sx, sy = screen_of(sc, su, sv)
    anchors.append(dict(kind='player_spawn', u=su, v=sv, sx=round(sx, 1), sy=round(sy, 1)))
    for wd in VENTS_WD:
        u, v = wd_uv(*wd); sx, sy = screen_of(sc, u, v)
        anchors.append(dict(kind='vent', u=u, v=v, sx=round(sx, 1), sy=round(sy, 1), radius=14))
    data = dict(size=[GW, GH], projection=dict(ox=320, oy=4, note='screen = (ox + u - v, oy + (u+v)/2 - h), in the 640x360 frame'),
                bleed=dict(left=100, right=100, top=60, bottom=60, ground_size=[GW, GH], ground_offset=[-OX, -OY]),
                sprites=sprites, anchors=anchors)
    with open(os.path.join(outdir, 'placements3d.json'), 'w') as f:
        json.dump(data, f, indent=1)
    return sc, walk_img


# ---------------------------------------------------------------- concept mockups
def build_tidal(rng):
    sc = Scene('tidewater')
    # flat salt pans separated by low dikes in a diamond grid, boardwalk through the middle
    path_pts = [wd_uv(w, d) for w, d in [(150, -10), (110, 30), (60, -20), (20, 40), (-30, -10), (-80, 30), (-125, 0)]]
    dpath = polyline_dist(UU, VV, path_pts)
    cell = 60.0
    fx = np.abs(((UU / cell) % 1.0) - .5); fy = np.abs(((VV / cell) % 1.0) - .5)
    dike = ((fx > .455) | (fy > .455)) & (dpath > 7)
    H = np.where(dike, 3.0, 0.0) + (fbm(UU / 14.0, VV / 14.0, 3, 5) - .5) * 1.2
    pool = (~dike) & (fbm(UU / 30.0, VV / 30.0, 3, 17) > .47) & (dpath > 14)
    H[pool] -= 2
    rim = smooth(RE * 0.97, RE * 1.05, RR)
    H += rim * 20 + smooth(RE * 1.05, RE * 1.5, RR) * 22
    sc.H = H
    M = np.full((N, N), M_SAND, np.int32)
    M[dike] = M_DIKE; M[pool] = M_WATER; M[rim > .3] = M_WALL
    M[dpath < 5] = M_PLANK
    sc.M = M
    sc.walk = (rim < .1) & ~pool
    for _ in range(26):
        u = rng.uniform(40, 360); v = rng.uniform(40, 360)
        if RR[int(u), int(v)] > RE[int(u), int(v)] * .85 or dpath[int(u), int(v)] < 9 or M[int(u), int(v)] == M_WATER:
            continue
        for i in range(rng.integers(2, 5)):
            sc.prop('salt', u + rng.uniform(-4, 4), v + rng.uniform(-4, 4), P_SALT, shape='cone', r=rng.uniform(2, 3.4), height=rng.uniform(8, 22))
    for k in range(9):
        w = 140 - k * 32; d = (-1) ** k * 36
        u, v = wd_uv(w, d)
        if dpath[int(u), int(v)] > 8:
            sc.prop('tide_pole', u, v, P_WOOD, shape='box', r=1.1, height=rng.uniform(30, 44), tall=True)
    return sc


def build_hollow(rng):
    sc = Scene('hollow')
    path_pts = [wd_uv(w, d) for w, d in [(150, -10), (110, -40), (70, 10), (30, 50), (-10, 10), (-50, -40), (-90, -10), (-125, 10)]]
    dpath = polyline_dist(UU, VV, path_pts)
    H = (fbm(UU / 44.0, VV / 44.0, 4, 3) - .5) * 30 * (1 - blur(smooth(24, 6, dpath), 3) * .8)
    rim = smooth(RE * 0.97, RE * 1.05, RR)
    H += rim * 42 + smooth(RE * 1.05, RE * 1.5, RR) * 30
    sc.H = H
    M = np.full((N, N), M_GRASS, np.int32)
    M[dpath < 6] = M_PATH; M[rim > .3] = M_WALL
    pond = np.hypot(UU - wd_uv(-60, 60)[0], VV - wd_uv(-60, 60)[1]) < 22
    M[pond] = M_WATER; sc.H[pond] -= 3
    sc.M = M
    sc.walk = (rim < .1) & ~pond
    for _ in range(300):
        if len([p for p in sc.props if p['kind'] == 'tree']) >= 22:
            break
        u = rng.uniform(40, 360); v = rng.uniform(40, 360)
        iu, iv = int(u), int(v)
        if RR[iu, iv] > RE[iu, iv] * .88 or dpath[iu, iv] < 14 or M[iu, iv] == M_WATER:
            continue
        if any(math.hypot(u - p['u'], v - p['v']) < 14 for p in sc.props):
            continue
        b = sc.H[iu, iv]
        sc.prop('trunk', u, v, P_TRUNK, shape='box', r=1.3, height=22, base=b)
        sc.prop('tree', u, v, P_CANOPY, shape='dome', r=rng.uniform(8, 12), height=rng.uniform(30, 40), base=b)
        for k in range(rng.integers(2, 5)):
            a = rng.uniform(0, 6.28); rr = rng.uniform(5, 9)
            sc.prop('fruit', u + math.cos(a) * rr, v + math.sin(a) * rr, P_GLOW, shape='sphere', r=1.6, height=rng.uniform(26, 36), base=b)
    return sc


def mockup(sc, name, path, label):
    S, Mat, F, ID, DR, aux = sc.render()
    idx, alpha = sc.shade_to_index(S, Mat, F, ID, DR)
    idx = np.where(alpha, idx, 0)
    img = np.stack([pal(name)[idx][..., c] for c in range(3)], -1)
    Image.fromarray(img, 'RGB').crop((OX, OY, OX + 640, OY + 360)).save(path)


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'quarry'
    rng = np.random.default_rng(3)
    if cmd == 'quarry':
        out = os.path.join(ROOT, 'assets', 'art', 'zone2', 'quarry')
        sc, walk = bake_quarry(out)
        print('wrote', out, 'walkable frac %.3f' % walk.mean())
    elif cmd == 'concepts':
        out = sys.argv[2]
        os.makedirs(out, exist_ok=True)
        a = build_quarry(); populate_quarry(a, np.random.default_rng(7)); mockup(a, 'quarry', os.path.join(out, 'concept-a-ember-quarry.png'), 'A')
        b = build_tidal(rng); mockup(b, 'tidewater', os.path.join(out, 'concept-b-salt-pans.png'), 'B')
        c = build_hollow(rng); mockup(c, 'hollow', os.path.join(out, 'concept-c-glow-orchard.png'), 'C')


if __name__ == '__main__':
    main()
