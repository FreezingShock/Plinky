#!/usr/bin/env python3
"""Ember Quarry ground, v2 (wider starting area). numpy + Pillow only.

  python3 tools/art/gen_quarry.py [--preview out.png] [--fast]

One 1400x760 canvas (the quarry is as big as Larkmoor now): six terraces climb from the arch to the gate, each with
room for a row of three forge pads and a wide road, flanked by mesas, craters, lava rivers that spill down the terrace
steps as falls, lava pools and a lava moat crossed by a stone bridge. The ground is the same height-field render as
the meadow (2:1 projection, Bayer 4x4 dither, palette indices only), so cliff faces already face the screen; every
prop on top of it is a front-facing 2D sprite from tools/art/qprops.py. Lava glow is baked into the ground and the
props near it (warm shift along the ember ramp), and the lava itself ships as small 6 frame strips the scene cycles.

Writes assets/art/zone2/quarry/: ground.png, walkable.png, sprites/*.png, lava/*.png, placements3d.json."""
import json, math, os, sys, time
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'art', 'zone2', 'quarry')
FAST = '--fast' in sys.argv
T0 = time.time()


def log(*a):
    print('[%5.1fs]' % (time.time() - T0), *a, flush=True)


N = 720
C = 360.0
OXS, OYS = 700, 80          # screen = (OXS + u - v, OYS + (u+v)/2 - h)
CW, CH = 1400, 760
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
PAL = ['1a1116', '4a1f2a', '8a3a2e', 'd0602f', 'e9a845', 'b77a7a', '5b3d5c', 'f1d9b5']
PALRGB = np.array([[int(h[k:k + 2], 16) for k in (0, 2, 4)] for h in PAL], np.uint8)
LD = np.array([-0.42, 0.46, 0.78]); LD /= np.linalg.norm(LD)

M_FLOOR, M_WALL, M_PATH, M_LAVA, M_SEAM, M_VENT, M_ASH, M_BRIDGE, M_CRUST = range(9)
RAMPS = {M_FLOOR: [0, 1, 1, 2, 6], M_WALL: [0, 0, 1, 1, 6], M_PATH: [6, 5, 5, 7, 7], M_LAVA: [2, 3, 3, 4, 4],
         M_SEAM: [2, 3, 4, 4, 7], M_VENT: [3, 3, 4, 4, 7], M_ASH: [1, 1, 6, 6, 5], M_BRIDGE: [0, 1, 6, 6, 5],
         M_CRUST: [0, 1, 2, 1, 6]}
# warm shift along the ember ramp: palette index -> rank, rank -> palette index
RANK = {0: 0, 1: 1, 6: 1, 2: 2, 5: 2, 3: 3, 4: 4, 7: 5}
UNRANK = [0, 1, 2, 3, 4, 7]


# ---------------------------------------------------------------- noise
def h2(ix, iy, s):
    n = (ix.astype(np.int64) * 374761393 + iy.astype(np.int64) * 668265263 + np.int64(s) * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def vnoise(x, y, s=0):
    xi = np.floor(x); yi = np.floor(y)
    fx = x - xi; fy = y - yi
    fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy)
    a, b, c, d = h2(xi, yi, s), h2(xi + 1, yi, s), h2(xi, yi + 1, s), h2(xi + 1, yi + 1, s)
    top = a + (b - a) * fx
    return top + ((c + (d - c) * fx) - top) * fy


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


def boxblur(A, r):
    """Separable box blur, radius r texels across and r/2 down (a ground circle is a 2:1 ellipse on screen)."""
    ry = max(1, r // 2)
    k = 2 * ry + 1
    P = np.pad(A, ((ry, ry), (0, 0)), mode='edge')
    cs = np.cumsum(P, 0); cs = np.vstack([np.zeros((1, P.shape[1])), cs])
    P = (cs[k:] - cs[:-k]) / k
    k = 2 * r + 1
    P = np.pad(P, ((0, 0), (r, r)), mode='edge')
    cs = np.cumsum(P, 1); cs = np.hstack([np.zeros((P.shape[0], 1)), cs])
    return (cs[:, k:] - cs[:, :-k]) / k


UU, VV = np.meshgrid(np.arange(N, dtype=np.float64), np.arange(N, dtype=np.float64), indexing='ij')
WW = (UU + VV) / 2 - C          # depth: negative = far (high), positive = near (low)
DD = UU - VV                    # screen x offset
D2 = DD / 2.0                   # ground metric: a ground circle of radius r is 2r wide and r tall on screen


def uv(w, d):
    return C + w + d / 2.0, C + w - d / 2.0


def scr(w, d, h=0.0):
    return OXS + d, OYS + C + w - h


def gdist(w, d):
    return np.hypot(WW - w, D2 - d / 2.0)


def pl_dist(pts):
    """Ground distance to a (w, d) polyline."""
    best = np.full(WW.shape, 1e9)
    P = [(w, d / 2.0) for w, d in pts]
    for (aw, ad), (bw, bd) in zip(P[:-1], P[1:]):
        dw, dd = bw - aw, bd - ad
        L2 = dw * dw + dd * dd + 1e-9
        t = np.clip(((WW - aw) * dw + (D2 - ad) * dd) / L2, 0, 1)
        best = np.minimum(best, np.hypot(WW - (aw + t * dw), D2 - (ad + t * dd)))
    return best


# ---------------------------------------------------------------- layout
ROWW = [150, 78, 6, -66, -138, -210]            # pad row depth (w)
BND = [106, 34, -38, -110, -182, -254]          # terrace step k lies between row k and k+1
TH_K = [16.0, 20.0, 17.0, 21.0, 18.0, 22.0]       # terrace rise at each step
RAMP_D = [110, -120, 125, -115, 120]            # where the road climbs step k
FRONT = 12                                      # the road runs this far in front of a pad row
HUB = (206, 0)
ARCH = (250, 0)
PAD_DX = 72
# the road: arch, bridge over the moat, hub, then a switchback past every row of pads and up the ramps
ROAD = [ARCH, (236, 0), (222, 0), HUB, (182, -50), (ROWW[0] + FRONT, -95), (ROWW[0] + FRONT, RAMP_D[0])]
for r in range(5):
    a = RAMP_D[r]
    ROAD += [(BND[r] + 10, a), (BND[r] - 20, a), (ROWW[r + 1] + FRONT, a)]
    if r < 4:
        ROAD.append((ROWW[r + 1] + FRONT, RAMP_D[r + 1]))
GATE_WD = (-246, 46)
ROAD += [(ROWW[5] + FRONT, 46), (GATE_WD[0] + 14, GATE_WD[1])]
ROW_SPAN = [(-95, 110)] + [(RAMP_D[r - 1], RAMP_D[r]) for r in range(1, 5)]
# row 5 (Emberheart) sits west of the gate approach
PAD_ROWS = []
for r in range(5):
    a, b = ROW_SPAN[r]
    c = (a + b) / 2.0
    PAD_ROWS.append([(ROWW[r], c - PAD_DX), (ROWW[r], c), (ROWW[r], c + PAD_DX)])
PAD_ROWS.append([(ROWW[5], -150), (ROWW[5], -80), (ROWW[5], -10)])
PADS = [p for row in PAD_ROWS for p in row]
VENTS = [(200, 96), (150, -190), (18, 190), (-100, -190), (-170, 188)]
SPAWN = (HUB[0] - 6, HUB[1])

# lava: rivers are (w, d) polylines with a half width in ground units; falls happen where one crosses a terrace step
RIVERS = [
    dict(w=6.5, pts=[(-250, 322), (-232, 330), (-205, 318), (-190, 306), (-166, 300), (-140, 312), (-120, 322), (-96, 312), (-72, 296),
                     (-50, 300), (-26, 316), (0, 326), (24, 320), (48, 306), (78, 308), (100, 318), (126, 334), (160, 338)]),
    dict(w=5.0, pts=[(-246, -330), (-228, -318), (-200, -326), (-188, -340), (-166, -352), (-142, -344), (-124, -330), (-100, -336),
                     (-74, -352), (-46, -346), (-30, -330), (-10, -312)]),
    dict(w=7.0, pts=[(229, -330), (229, -240), (229, -120), (229, 0), (229, 120), (229, 240), (229, 330)]),   # the moat
]
POOLS = [(-228, 296, 13), (-232, -330, 12), (176, 336, 26), (-6, -300, 26), (-62, 192, 11), (60, -200, 10), (-178, 220, 9),
         (150, 214, 10), (92, 290, 9), (-96, -230, 9), (-212, -196, 9), (-212, 150, 9)]
BRIDGE = dict(w=229, d=0, hw=7.5, hd=16.0)
# raised mesas (not walkable): centre, radii (ground units), rise above the terrace
MESAS = [(150, -330, 24, 90, 26), (110, 300, 22, 70, 22), (62, -300, 20, 70, 30), (60, 360, 22, 60, 28), (-6, -380, 26, 70, 34),
         (-20, 270, 16, 54, 24), (-84, 300, 18, 70, 28), (-90, -280, 20, 70, 26), (-160, -300, 18, 80, 30), (-156, 380, 20, 60, 24),
         (-236, -170, 14, 60, 24), (-236, 190, 14, 60, 24), (190, -330, 20, 70, 20), (186, 190, 12, 50, 18)]
CRATERS = [(120, -240, 20, 9), (-30, 240, 22, 8), (-170, -250, 18, 8), (46, 220, 16, 6)]


def build():
    log('terrain')
    w, d = WW, DD
    E = np.hypot(w / 285.0, d / 470.0)
    E = E * (1 + (fbm(UU / 70.0, VV / 70.0, 3, 3) - .5) * 0.13)
    flat0 = pl_dist(ROAD)
    wob = ((fbm(UU / 70.0, VV / 70.0, 3, 11) - .5) * 70 + np.sin(d / 83.0 + 1.0) * 14 + w * 0.0) * (1 - smooth(18, 46, 64 - flat0).clip(0, 1) * 0 - smooth(46, 20, flat0))
    # ramps: the step is a slope where the road climbs and a cliff everywhere else
    corr = np.zeros(WW.shape)
    for r in range(5):
        seg = pl_dist([(BND[r] + 34, RAMP_D[r]), (BND[r] - 34, RAMP_D[r])])
        corr = np.maximum(corr, smooth(15, 5, seg))
    H = np.zeros((N, N))
    for k, bw in enumerate(BND):
        wid = 1.6 + (TH_K[k] * 0.95 - 1.6) * corr if k < 5 else 1.6
        H += TH_K[k] * smooth(bw + wob * 0.6 * (1 - corr) + wid, bw + wob * 0.6 * (1 - corr) - wid, w)
    roll = (fbm(UU / 26.0, VV / 26.0, 3, 5) - .5)
    flat = pl_dist(ROAD)
    H += roll * 4.0 * smooth(10, 26, flat)
    # mesas: irregular raised blocks with cliff sides
    mesa = np.zeros((N, N), bool)
    for i, (mw, md, rw, rd, rise) in enumerate(MESAS):
        dist = np.hypot((w - mw) / rw, (D2 - md / 2.0) / (rd / 2.0))
        dist = dist * (1 + (fbm(UU / 17.0, VV / 17.0, 2, 90 + i) - .5) * 0.45)
        H += rise * smooth(1.0, 0.82, dist) * (0.85 + 0.3 * fbm(UU / 9.0, VV / 9.0, 2, 33 + i))
        mesa |= dist < 1.0
    crater = np.zeros((N, N), bool)
    for i, (cw, cd, cr, dep) in enumerate(CRATERS):
        dist = gdist(cw, cd) * (1 + (fbm(UU / 12.0, VV / 12.0, 2, 70 + i) - .5) * 0.4)
        H -= dep * smooth(cr, cr * 0.45, dist)
        H += 3.0 * smooth(cr * 1.35, cr * 0.95, dist) * smooth(cr * 0.55, cr * 0.95, dist)   # raised lip
        crater |= dist < cr * 0.5
    # the rim: a canyon wall that is a berm in front of the camera
    rim = smooth(0.97, 1.07, E)
    nearw = smooth(30, 200, w)
    rim_scale = 1.0 - 0.9 * nearw
    H += rim * (46 + 26 * fbm(UU / 28.0, VV / 28.0, 2, 41)) * rim_scale
    H += smooth(1.07, 1.5, E) * 44 * rim_scale
    H += smooth(1.0, 1.1, E) * (fbm(UU / 7.0, VV / 7.0, 2, 8) - .5) * 14
    # lava
    lava = np.zeros((N, N), bool)
    depth = np.zeros((N, N))
    for rv in RIVERS:
        dist = pl_dist(rv['pts']) + (fbm(UU / 9.0, VV / 9.0, 2, 21) - .5) * 3.0
        wv = rv['w'] * (1 + 0.25 * (fbm(UU / 31.0, VV / 31.0, 2, 14) - .5))
        lava |= dist < wv
        depth = np.maximum(depth, smooth(wv + 3, wv - 2.5, dist))
    for (pw, pd, pr) in POOLS:
        dist = gdist(pw, pd) + (fbm(UU / 8.0, VV / 8.0, 2, 22) - .5) * 4.0
        lava |= dist < pr
        depth = np.maximum(depth, smooth(pr + 3, pr - 3, dist))
    lava &= E < 1.0
    # the bridge keeps its deck above the moat
    bridge = (np.abs(w - BRIDGE['w']) < BRIDGE['hw']) & (np.abs(D2 - BRIDGE['d'] / 2.0) < BRIDGE['hd'] / 2.0 + 8)
    bridge = bridge & (np.abs(DD - BRIDGE['d']) < BRIDGE['hd'] * 1.0 + 14)
    lava &= ~bridge
    depth = np.where(bridge, 0.0, depth)
    H -= 5.0 * depth
    # a stone landing on the far side of the moat and the hub plaza get flat ground
    sc = types_scene()
    sc['H'] = H
    slope = np.hypot(*np.gradient(blur(H, 1)))
    M = np.full((N, N), M_FLOOR, np.int32)
    M[(slope > 0.9)] = M_WALL
    M[rim > 0.35] = M_WALL
    M[mesa & (slope <= 0.9)] = M_CRUST
    M[crater] = M_ASH
    ash = (fbm(UU / 24.0, VV / 24.0, 3, 61) > 0.63) & (M == M_FLOOR)
    M[ash] = M_ASH
    ridge = np.abs(fbm(UU / 15.0, VV / 15.0, 3, 31) - .5)
    seam = (ridge < 0.012) & (flat > 14) & (M == M_FLOOR)
    M[seam] = M_SEAM
    # roads, plazas, landings
    pcore = flat
    plaza = np.zeros((N, N), bool)
    for (pw, pd, pr) in [(HUB[0], HUB[1], 17), (GATE_WD[0] + 8, GATE_WD[1], 20), (ARCH[0], ARCH[1], 16)]:
        plaza |= gdist(pw, pd) < pr
    # a short pad apron under every pad
    for (pw, pd) in PADS:
        plaza |= gdist(pw, pd) < 12.5
    roadm = ((pcore < 4.6) | plaza) & (slope < 0.95) & (E < 0.96)
    M[roadm & ~lava] = M_PATH
    M[bridge] = M_BRIDGE
    for (vw, vd) in VENTS:
        M[gdist(vw, vd) < 7] = M_VENT
    M[lava] = M_LAVA
    walk = (slope < 0.9) & (E < 0.93) & ~lava & np.isin(M, [M_FLOOR, M_PATH, M_SEAM, M_VENT, M_ASH, M_BRIDGE]) & ~mesa
    # hub plaza etc. are flat enough already; keep a clear lip back from the moat
    return dict(H=H, M=M, walk=walk, lava=lava, E=E, slope=slope, mesa=mesa, bridge=bridge, depth=depth, flat=flat)


def types_scene():
    return {}


# ---------------------------------------------------------------- render
def render(T):
    log('render')
    H = T['H']
    Hs = blur(H, 1)
    gu, gv = np.gradient(Hs)
    nrm = np.stack([-gu, -gv, np.ones_like(H)], -1)
    nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
    lam = np.clip(nrm @ LD, 0, 1)
    cav = np.clip((blur(H, 6) - H) / 7.0, 0, 1)
    patch = (fbm(UU / 38.0, VV / 38.0, 3, 77) - .5) * 0.34 + (fbm(UU / 7.0, VV / 7.0, 2, 78) - .5) * 0.16
    shade_c = lam * 0.75 + 0.2 - cav * 0.45 + patch
    hp_u = np.roll(H, -1, 0); hp_v = np.roll(H, -1, 1)
    nd_u = np.maximum(0, H - hp_u); nd_v = np.maximum(0, H - hp_v)
    face_s = blur(np.where(nd_u + nd_v > 1e-6, (0.22 * nd_u + 0.68 * nd_v) / (nd_u + nd_v + 1e-9), 0.4), 4)
    drop = np.maximum(nd_u, nd_v)
    S = np.zeros((CH, CW)); Mat = np.full((CH, CW), -1, np.int32); F = np.zeros((CH, CW), np.int8)
    DR = np.zeros((CH, CW)); PU = np.zeros((CH, CW), np.float32); PV = np.zeros((CH, CW), np.float32)
    Hl = H.tolist(); Ml = T['M'].tolist(); fl = face_s.tolist(); sl = shade_c.tolist(); dl = drop.tolist()
    for s in range(0, 2 * N - 1):
        ulo, uhi = max(0, s - N + 1), min(N - 1, s)
        for u in range(ulo, uhi + 1):
            v = s - u
            x = OXS + u - v
            if x < 0 or x >= CW:
                continue
            h = Hl[u][v]
            y0 = int(math.floor(OYS + s / 2.0 - h))
            base = int(y0 + max(h, 0) + 3)
            if y0 >= CH or base < 0:
                continue
            ya, yb = max(y0, 0), min(base, CH)
            if yb <= ya:
                continue
            S[ya:yb, x] = fl[u][v]; Mat[ya:yb, x] = Ml[u][v]; F[ya:yb, x] = 1; DR[ya:yb, x] = dl[u][v]
            PU[ya:yb, x] = u; PV[ya:yb, x] = v
            if y0 >= 0:
                S[y0, x] = sl[u][v]; F[y0, x] = 0
            if yb - ya > 1 and dl[u][v] < 30:
                ys = np.arange(max(ya, y0 + 1), yb)
                S[ys, x] = S[ys, x] - 0.07 * (((ys) // 4) % 3 == 0)
    return S, Mat, F, DR, PU, PV


def lava_index(x, y, t, face):
    """Palette index of a lava pixel at animation frame t (0..5; the loop is exactly 6 frames). Tops boil and drift,
    falls stream down in thin bright threads."""
    th = BAYER[y % 4, x % 4]
    tt = t / 6.0
    off = h2(x // 2, np.zeros_like(x), 5)
    ph = y / 6.0 - tt + off
    vf = 0.5 + 0.5 * np.sin(2 * np.pi * ph)
    vf = vf * 0.7 + 0.3 * h2(x, (y + 2 * t) // 3 % 4, 9)
    a = 0.5 + 0.5 * np.sin(2 * np.pi * (x / 19.0 + y / 9.0 - tt))
    b = 0.5 + 0.5 * np.sin(2 * np.pi * (x / 11.0 - y / 13.0 + tt))
    v = np.where(face, vf, 0.55 * a + 0.45 * b)
    crust = h2(x // 3, y // 3, 17) < 0.16
    pos = np.clip(v, 0, 0.999) * 4 + (th - .5) * 0.7
    ramp = np.array([2, 3, 3, 4, 4], np.int32)
    idx = ramp[np.clip(np.floor(pos + .5).astype(int), 0, 4)]
    idx = np.where(crust & ~face, np.where(v > 0.6, 2, 1), idx)
    spark = ((h2(x, y, 3) + tt) % 1.0 < 0.012) & ~crust
    return np.where(spark, 7, idx)


def shade(T, S, Mat, F, DR, PU, PV, glow=None, frame=0):
    log('shade')
    out = np.zeros((CH, CW), np.uint8)
    alpha = Mat >= 0
    yy, xx = np.mgrid[0:CH, 0:CW]
    th = BAYER[yy % 4, xx % 4]
    for m, ramp in RAMPS.items():
        sel = alpha & (Mat == m)
        if not sel.any():
            continue
        ln = len(ramp) - 1
        pos = np.clip(S[sel], 0, 0.999) * ln + (th[sel] - .5) * 0.9
        idx = np.clip(np.floor(pos + .5).astype(int), 0, ln)
        out[sel] = np.array(ramp, np.uint8)[idx]
    quarry_cliff(out, S, Mat, F, DR, th, yy, xx)
    stairs_and_roads(out, T, Mat, F, th, yy, xx, PU, PV)
    lv = alpha & (Mat == M_LAVA)
    out[lv] = lava_index(xx[lv], yy[lv], frame, F[lv] == 1).astype(np.uint8)
    # ink outlines at silhouettes, around lava and at the base of tall cliffs
    edge = np.zeros((CH, CW), bool)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        ash = np.roll(np.roll(alpha, dy, 0), dx, 1)
        edge |= alpha & ~ash
    below = np.roll(F, -1, 0)
    cliff_base = (F == 1) & (below == 0) & (DR > 5) & alpha
    edge |= cliff_base & (Mat != M_LAVA)
    lava_rim = np.zeros((CH, CW), bool)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        lava_rim |= np.roll(np.roll(Mat == M_LAVA, dy, 0), dx, 1)
    lava_rim &= alpha & (Mat != M_LAVA)
    out[(edge | lava_rim) & alpha & (Mat != M_LAVA)] = 0
    above = np.roll(F, 1, 0)
    lip = (F == 1) & (above == 0) & (DR > 5) & alpha & (Mat != M_LAVA)
    out[lip & ~edge & ~lava_rim] = 5
    if glow is not None:
        gl = np.clip(glow, 0, 1)
        band = np.floor(gl * 3.2 + (th - .5) * 0.55 + 0.0).astype(int)
        band = np.clip(band, 0, 3)
        notlava = alpha & (Mat != M_LAVA)
        rk = np.vectorize(lambda i: RANK[int(i)])(np.arange(8))
        rank = rk[out]
        sh = np.where(rank >= 4, 0, band)
        new = np.array(UNRANK)[np.clip(rank + sh, 0, 5)]
        out = np.where(notlava & (band > 0), new, out).astype(np.uint8)
        out[(Mat == M_LAVA) & alpha & (out == 0)] = 0
    return out, alpha


def quarry_cliff(out, S, Mat, F, DR, th, yy, xx):
    face = (Mat == M_WALL) & (F == 1)
    if not face.any():
        return
    depth = np.zeros((CH, CW), np.int32)
    for y in range(1, CH):
        depth[y] = np.where(face[y], np.where(face[y - 1], depth[y - 1] + 1, 1), 0)
    wob = (3.0 * np.sin(xx / 23.0 + 1.3) + 2.0 * np.sin(xx / 9.0) + 6.0 * (h2(xx // 6, np.zeros_like(xx), 5) - .5)).astype(np.int64)
    rows = yy + wob
    band = rows // 6
    tone = h2(band.astype(np.int64), np.zeros_like(band, dtype=np.int64), 17)
    fade = np.clip(1.0 - depth / 120.0, 0.0, 1.0)
    v = np.clip(0.32 + 0.45 * S + 0.28 * (tone - .5) + 0.30 * fade - 0.28, 0.0, 1.0) * (0.35 + 0.65 * fade)
    ramp = np.array([0, 1, 6, 2], np.uint8)
    pos = v * 3.0 + (th - .5) * 0.9
    idx = ramp[np.clip(np.floor(pos + .5).astype(int), 0, 3)]
    idx = np.where((rows % 6 == 0) & (depth > 2), 0, idx)
    hi = (rows % 6 == 1) & (tone > .55) & (depth > 2) & (fade > .25)
    idx = np.where(hi & (th > 5 / 16), 6, idx)
    # vertical joints give the strata the look of stacked basalt blocks
    joint = (h2((xx // 9).astype(np.int64), band.astype(np.int64), 23) > 0.72) & (xx % 9 == 0) & (depth > 2)
    idx = np.where(joint, 0, idx)
    cell = h2((xx // 5).astype(np.int64), band.astype(np.int64), 29)
    dash = (cell > 0.90 + 0.09 * (1.0 - fade)) & (rows % 6 == 3) & (depth > 4) & (depth < 95)
    idx = np.where(dash, np.where(((xx // 5) % 2) == 0, 3, 2), idx)
    core = dash & (cell > 0.965) & (xx % 5 == 2)
    idx = np.where(core, 4, idx)
    out[face] = idx[face]


def stairs_and_roads(out, T, Mat, F, th, yy, xx, PU, PV):
    """Ramps read as stone stairs (tread lines across the slope), the road gets worn edges and pebbles."""
    path = (Mat == M_PATH)
    if not path.any():
        return
    sl = T['slope']
    iu = np.clip(PU.astype(int), 0, N - 1); iv = np.clip(PV.astype(int), 0, N - 1)
    sp = sl[iu, iv]
    stair = path & (sp > 0.28) & (F == 0)
    out[stair & (yy % 4 == 0)] = 5
    out[stair & (yy % 4 == 1)] = 6
    peb = path & (F == 0) & (h2(xx // 2, yy // 2, 41) > 0.975)
    out[peb & ~stair] = 6
    chip = path & (F == 0) & (h2(xx, yy, 43) > 0.985)
    out[chip & ~stair] = 7
    br = (Mat == M_BRIDGE) & (F == 0)
    out[br & (xx % 6 == 0)] = 0           # plank gaps across the bridge
    sm = (Mat == M_SEAM)
    out[sm & (h2(xx // 3, yy // 3, 44) > 0.6)] = 2


def glow_field(Mat, F, extra_pts=()):
    """0..1 warm light on the canvas: a wide soft halo plus a tighter one around every lava pixel."""
    lv = (Mat == M_LAVA).astype(np.float64)
    for (x, y, r) in extra_pts:
        yy0, yy1 = max(0, int(y - r)), min(CH, int(y + r))
        xx0, xx1 = max(0, int(x - r * 2)), min(CW, int(x + r * 2))
        gy, gx = np.mgrid[yy0:yy1, xx0:xx1]
        lv[yy0:yy1, xx0:xx1] = np.maximum(lv[yy0:yy1, xx0:xx1], (((gx - x) / 2.0) ** 2 + (gy - y) ** 2 < (r * .5) ** 2) * 0.7)
    g1 = boxblur(boxblur(lv, 10), 10)
    g2 = boxblur(boxblur(boxblur(lv, 22), 22), 22)
    return np.clip(g1 * 1.7 + g2 * 2.3, 0, 1)


def top_walk_image(T, Fimg, PU, PV):
    """Screen-space walk mask: the cells that are walkable AND whose top is the visible pixel (not hidden by a wall)."""
    H = T['H']
    us, vs = np.nonzero(T['walk'])
    xs = (OXS + us - vs).astype(int)
    ys = np.floor(OYS + (us + vs) / 2.0 - H[us, vs]).astype(int)
    ok = (xs >= 0) & (xs < CW) & (ys >= 0) & (ys < CH)
    us, vs, xs, ys = us[ok], vs[ok], xs[ok], ys[ok]
    vis = (Fimg[ys, xs] == 0) & (PU[ys, xs] == us) & (PV[ys, xs] == vs)
    img = np.zeros((CH, CW), bool)
    img[ys[vis], xs[vis]] = True
    for _ in range(3):     # close the pinholes the sampling leaves (steep ramps give one top pixel every 2 rows)
        img = img | (np.roll(img, 1, 0) & np.roll(img, -1, 0)) | (np.roll(img, 1, 1) & np.roll(img, -1, 1))
    return img


def erode(img, n=1):
    for _ in range(n):
        e = img.copy()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            e &= np.roll(np.roll(img, dy, 0), dx, 1)
        img = e
    return img


def label_regions(mask, step=4):
    """4-connected regions of a coarse version of the mask, returned as lists of full-resolution bounding boxes."""
    gh, gw = CH // step, CW // step
    coarse = mask[:gh * step, :gw * step].reshape(gh, step, gw, step).any(axis=(1, 3))
    seen = np.zeros_like(coarse)
    boxes = []
    for y in range(gh):
        for x in range(gw):
            if coarse[y, x] and not seen[y, x]:
                stack = [(y, x)]; seen[y, x] = True
                x0 = x1 = x; y0 = y1 = y
                while stack:
                    cy, cx = stack.pop()
                    x0, x1, y0, y1 = min(x0, cx), max(x1, cx), min(y0, cy), max(y1, cy)
                    for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                        if 0 <= ny < gh and 0 <= nx < gw and coarse[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True; stack.append((ny, nx))
                boxes.append((x0 * step, y0 * step, (x1 + 1) * step, (y1 + 1) * step))
    return boxes


def flood(walk, start, goals):
    """Walker reachability: flood fill over the walk mask from `start`; returns the goals it cannot reach."""
    h, w = walk.shape
    seen = np.zeros_like(walk)
    sx, sy = int(start[0]), int(start[1])
    q = [(sx, sy)]; seen[sy, sx] = True
    for x, y in q:
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and walk[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True; q.append((nx, ny))
    return [g for g in goals if not seen[int(g[1]), int(g[0])]], seen


def sample_h(T, w, d):
    u, v = uv(w, d)
    return float(T['H'][int(round(u)), int(round(v))])


def lit_sprite(img, x0, y0, GL):
    """Shift a prop's pixels along the ember ramp by the lava glow under it (props use the 8 quarry colours only)."""
    a = np.array(img)
    h, w = a.shape[:2]
    gl = GL[y0:y0 + h, x0:x0 + w]
    if gl.shape[:2] != (h, w):
        return img
    op = a[..., 3] > 0
    d = ((a[..., None, :3].astype(int) - PALRGB[None, None].astype(int)) ** 2).sum(-1)
    idx = np.argmin(d, -1)
    yy, xx = np.mgrid[0:h, 0:w]
    th = BAYER[(yy + y0) % 4, (xx + x0) % 4]
    # props are lit more at their feet, where the lava light lands
    vert = 0.55 + 0.45 * (yy / max(h - 1, 1))
    band = np.clip(np.floor(np.clip(gl * vert, 0, 1) * 3.2 + (th - .5) * 0.55).astype(int), 0, 3)
    rk = np.array([RANK[i] for i in range(8)])
    rank = rk[idx]
    new = np.array(UNRANK)[np.clip(rank + np.where(rank >= 4, 0, band), 0, 5)]
    new = np.where(op & (band > 0) & (idx != 0), new, idx)
    a[..., :3] = PALRGB[new]
    return Image.fromarray(a, 'RGBA')


def region_has(mask, w, d, r):
    iu, iv = uv(w, d)
    return bool(mask[int(iu), int(iv)])


def place_props(T, rng, GL):
    """Scatter front-facing props by district. Returns [(kind, seed, w, d)] with ground positions."""
    import qprops
    flat = T['flat']; lava = T['lava']; mesa = T['mesa']; E = T['E']; walk = T['walk']; H = T['H']
    padpts = PADS + [GATE_WD, ARCH, HUB] + VENTS
    lavad = np.full((N, N), 99.0)
    items = []
    placed = []

    def ok(kind, w, d, on_mesa=False, need_walk=True, road=14, lava_gap=3):
        iu, iv = (int(round(x)) for x in uv(w, d))
        if not (4 < iu < N - 4 and 4 < iv < N - 4) or E[iu, iv] > (0.9 if need_walk else 1.0):
            return False
        if lava[iu, iv] or T['bridge'][iu, iv]:
            return False
        if on_mesa:
            if not mesa[iu, iv]:
                return False
        else:
            if need_walk and not walk[iu, iv]:
                return False
            if mesa[iu, iv]:
                return False
        if flat[iu, iv] < road:
            return False
        r = qprops.FOOT[kind]
        for pw, pd in padpts:
            if abs(d - pd) < 40 and -52 < (w - pw) < 14:     # keep pads and their art clear
                return False
            if math.hypot(w - pw, (d - pd) / 2.0) < 16 + r:
                return False
        for (kw, kd, kr) in placed:
            if math.hypot(w - kw, (d - kd) / 2.0) < kr + r + 1.5:
                return False
        # keep clear of lava edges
        for dw, dd in ((r + lava_gap, 0), (-r - lava_gap, 0), (0, 2 * (r + lava_gap)), (0, -2 * (r + lava_gap))):
            ju, jv = (int(round(x)) for x in uv(w + dw, d + dd))
            if 0 <= ju < N and 0 <= jv < N and lava[ju, jv] and not kind == 'lava_rock':
                return False
        return True

    def scatter(kind, n, region=None, tries=3000, **kw):
        got = 0
        for _ in range(tries):
            if got >= n:
                break
            w = rng.uniform(-262, 262); d = rng.uniform(-455, 455)
            if region and not region(w, d):
                continue
            if ok(kind, w, d, **kw):
                items.append((kind, int(rng.integers(1, 9999)), w, d)); placed.append((w, d, qprops.FOOT[kind])); got += 1
        return got

    near_mesa = lambda w, d: any(abs(w - mw) < rw * 1.2 and abs(d - md) < rd * 0.55 for mw, md, rw, rd, _ in MESAS)
    scatter('columns', 14, near_mesa, on_mesa=True, need_walk=False)
    scatter('boulder_big', 6, lambda w, d: abs(d) > 120)
    scatter('boulder', 34)
    scatter('stalag', 16)
    scatter('dead_tree', 9, lambda w, d: abs(d) > 150)
    scatter('crystals', 12, lambda w, d: abs(d) > 100)
    scatter('boulder', 10, near_mesa, on_mesa=True, need_walk=False)
    scatter('crystals', 5, near_mesa, on_mesa=True, need_walk=False)
    scatter('dead_tree', 4, near_mesa, on_mesa=True, need_walk=False)
    scatter('ore_vein', 9, lambda w, d: 20 < w < 120 and abs(d) > 130)
    scatter('ruin', 8, lambda w, d: -130 < w < 20 and abs(d) > 120)
    scatter('stele', 5, lambda w, d: abs(d) > 110)
    scatter('timber', 3, lambda w, d: 30 < w < 130 and d < -200, road=20)
    scatter('cart', 3, lambda w, d: 30 < w < 130 and d < -190, road=16)
    scatter('iron_lamp', 6, lambda w, d: w < -150 or w > 160, road=8)
    # braziers beside the road, a pair at every ramp and one by each row
    for r in range(5):
        for side in (-1, 1):
            w, d = BND[r] + 4, RAMP_D[r] + side * 16
            if ok('brazier', w, d, road=2):
                items.append(('brazier', 100 + r, w, d)); placed.append((w, d, 3))
    for r in range(6):
        for dd in (-130, 150):
            w = ROWW[r] + FRONT - 2; d = dd + (30 if r == 5 else 0)
            if ok('brazier', w, d, road=2) and abs(d - ROW_SPAN[min(r, 4)][0]) > 8:
                items.append(('brazier', 140 + r, w, d)); placed.append((w, d, 3))
    # bridge posts
    for dd in (-18, 18):
        for ww in (229 - 11, 229 + 11):
            items.append(('post', 200, ww, dd)); placed.append((ww, dd, 1.5))
    # rocks hugging the lava
    got = 0
    for _ in range(4000):
        if got >= 22:
            break
        w = rng.uniform(-260, 260); d = rng.uniform(-450, 450)
        iu, iv = (int(round(x)) for x in uv(w, d))
        if not (6 < iu < N - 6 and 6 < iv < N - 6):
            continue
        near = any(lava[int(round(a)), int(round(b))] for a, b in (uv(w + 6, d), uv(w - 6, d), uv(w, d + 12), uv(w, d - 12)))
        if near and ok('lava_rock', w, d, lava_gap=-3):
            items.append(('lava_rock', int(rng.integers(1, 9999)), w, d)); placed.append((w, d, 5)); got += 1
    return items


def bake():
    import qprops
    rng = np.random.default_rng(11)
    T = build()
    S, Mat, F, DR, PU, PV = render(T)
    lavamask = (Mat == M_LAVA)
    glow = glow_field(Mat, F, [scr(vw, vd, sample_h(T, vw, vd)) + (7,) for vw, vd in VENTS])
    log('glow')
    frames = []
    for t in range(6):
        o, alpha = shade(T, S, Mat, F, DR, PU, PV, glow, t)
        frames.append(o)
    ground_idx = frames[0]
    alpha = Mat >= 0
    walk = top_walk_image(T, F, PU, PV)
    walk = erode(walk, 2)
    # a cliff is never walkable and never joins two terraces: block every pixel of a drop and a 3 px margin around it
    cliff = (DR > 4.0) & (Mat >= 0)
    for _ in range(3):
        c2 = cliff.copy()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
            c2 |= np.roll(np.roll(cliff, dy, 0), dx, 1)
        cliff = c2
    walk &= ~cliff
    # lava pixels and a margin around them are never walkable; neither is the void
    near_lava = lavamask.copy()
    for _ in range(3):
        n = near_lava.copy()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (0, 2), (0, -2)):
            n |= np.roll(np.roll(near_lava, dy, 0), dx, 1)
        near_lava = n
    walk &= ~near_lava & alpha
    # props
    items = place_props(T, rng, glow)
    log('props', len(items))
    os.makedirs(os.path.join(OUT, 'sprites'), exist_ok=True)
    for f in os.listdir(os.path.join(OUT, 'sprites')):
        os.remove(os.path.join(OUT, 'sprites', f))
    sprites = []
    yy, xx = np.mgrid[0:CH, 0:CW]
    for i, (kind, seed, w, d) in enumerate(sorted(items, key=lambda it: it[2] + 0 * it[3])):
        img, fx, fy = qprops.make(kind, seed)
        h = sample_h(T, w, d)
        px, py = scr(w, d, h)
        x0 = int(round(px - fx)); y0 = int(round(py - fy))
        img = lit_sprite(img, x0, y0, glow)
        name = 'sprites/%s_%03d.png' % (kind, i)
        img.save(os.path.join(OUT, name))
        sprites.append(dict(file=name, kind=kind, x=x0, y=y0, w=img.width, h=img.height, foot=[round(px, 1), round(py, 1)], sort_y=round(py, 1)))
        r = qprops.FOOT[kind]
        if kind not in ('post',) or True:
            walk &= ~(((xx - px) / (2.0 * r)) ** 2 + ((yy - py) / float(r)) ** 2 <= 1.0)
    # arch and gate footprints
    ax, ay = scr(ARCH[0], ARCH[1], sample_h(T, *ARCH))
    gx, gy = scr(GATE_WD[0], GATE_WD[1], sample_h(T, *GATE_WD))
    for (px, py) in ((ax - 26, ay), (ax + 26, ay), (gx - 26, gy), (gx + 26, gy)):
        walk &= ~(((xx - px) / 8.0) ** 2 + ((yy - py) / 4.0) ** 2 <= 1.0)
    # ground png: unpainted pixels are the dark void
    rgb = PALRGB[np.where(alpha, ground_idx, 0)]
    Image.fromarray(rgb, 'RGB').save(os.path.join(OUT, 'ground.png'))
    Image.fromarray((walk * 255).astype(np.uint8), 'L').convert('RGB').save(os.path.join(OUT, 'walkable.png'))
    # anchors
    anchors = []
    for (w, d) in PADS:
        x, y = scr(w, d, sample_h(T, w, d)); anchors.append(dict(kind='pad', state='ready', sx=round(x, 1), sy=round(y, 1)))
    anchors.append(dict(kind='gate', sx=round(gx, 1), sy=round(gy, 1)))
    anchors.append(dict(kind='arch', sx=round(ax, 1), sy=round(ay, 1)))
    sx_, sy_ = scr(SPAWN[0], SPAWN[1], sample_h(T, *SPAWN))
    anchors.append(dict(kind='player_spawn', sx=round(sx_, 1), sy=round(sy_, 1)))
    for (w, d) in VENTS:
        x, y = scr(w, d, sample_h(T, w, d)); anchors.append(dict(kind='vent', sx=round(x, 1), sy=round(y, 1), radius=14))
    # lava embers: the middle of each pool and the foot of each fall
    spots = [(w, d) for (w, d, r) in POOLS if r >= 9][:8]
    for (w, d) in spots:
        u, v = uv(w, d)
        if lava[int(u)][int(v)] if False else T['lava'][int(round(u)), int(round(v))]:
            x, y = scr(w, d, sample_h(T, w, d)); anchors.append(dict(kind='lava', sx=round(x, 1), sy=round(y, 1)))
    # reachability: every anchor the walker has to reach must connect to the spawn
    goals = [(a['sx'], a['sy']) for a in anchors if a['kind'] in ('pad', 'gate', 'arch', 'vent')]
    bad, seen = flood(walk, (sx_, sy_), goals)
    for a in anchors:
        if (a['sx'], a['sy']) in bad:
            log('UNREACHABLE', a)
    # lava strips: 6 frames per 128 px tile that holds lava
    lavadir = os.path.join(OUT, 'lava')
    os.makedirs(lavadir, exist_ok=True)
    for f in os.listdir(lavadir):
        os.remove(os.path.join(lavadir, f))
    lava_tiles = []
    TS = 128
    xx_, yy_ = xx, yy
    for ty in range(0, CH, TS):
        for tx in range(0, CW, TS):
            m = lavamask[ty:ty + TS, tx:tx + TS]
            if not m.any():
                continue
            ys, xs = np.nonzero(m)
            x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
            strip = np.zeros((y1 - y0, (x1 - x0) * 6, 4), np.uint8)
            mm = m[y0:y1, x0:x1]
            for t in range(6):
                fr = frames[t][ty + y0:ty + y1, tx + x0:tx + x1]
                blk = strip[:, t * (x1 - x0):(t + 1) * (x1 - x0)]
                blk[..., :3] = PALRGB[fr]; blk[..., 3] = np.where(mm, 255, 0)
            name = 'lava/lava_%02d_%02d.png' % (ty // TS, tx // TS)
            Image.fromarray(strip, 'RGBA').save(os.path.join(OUT, name))
            lava_tiles.append(dict(file=name, x=int(tx + x0), y=int(ty + y0), w=int(x1 - x0), h=int(y1 - y0), frames=6))
    data = dict(size=[CW, CH], world=[40, 10, CW - 80, CH - 20], bleed=dict(left=0, right=0, top=0, bottom=0, ground_size=[CW, CH], ground_offset=[0, 0]),
                projection=dict(ox=OXS, oy=OYS, note='canvas texels; ground is a full-size backdrop at (0, 0)'),
                sprites=sprites, anchors=anchors, lava=lava_tiles)
    with open(os.path.join(OUT, 'placements3d.json'), 'w') as f:
        json.dump(data, f, indent=1)
    # composed preview, for review only
    comp = Image.fromarray(rgb, 'RGB').convert('RGBA')
    for s_ in sprites:
        im = Image.open(os.path.join(OUT, s_['file']))
        comp.alpha_composite(im, (s_['x'], s_['y']))
    comp = comp.convert('RGB')
    comp.save(os.path.join(OUT, 'preview_full.png'))
    return T, comp, walk, anchors, bad, seen


if __name__ == '__main__':
    T, comp, walk, anchors, bad, seen = bake()
    log('walkable frac %.3f, unreachable %d' % (walk.mean(), len(bad)))
    if '--preview' in sys.argv:
        comp.save(sys.argv[sys.argv.index('--preview') + 1])
    if bad:
        sys.exit(1)
