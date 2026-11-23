#!/usr/bin/env python3
"""Plinky zone 1 meadow, rendered as real 3D (heightfield terrain + SDF-voxel props), shown as
pixel art per docs/art-bible.md: orthographic 2:1 iso, 3 light bands, Bayer 4x4 dither, palette-index colour,
ink outline per object id, cast shadows. Pure numpy + Pillow.
Run: python3 gen_meadow3d.py [--fast]  ->  meadow3d-1x.png (640x360), meadow3d.png (3x), placements3d.json"""
import numpy as np, math, random, json, os, sys, time
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
FAST = '--fast' in sys.argv
T0 = time.time()
def log(*a): print('[%5.1fs]' % (time.time() - T0), *a, flush=True)

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import larkmoor_layout as LAY
import depth_pass, grass_tex
GRASS = os.environ.get('GRASS', 'a')    # grass texture style (tools/art/grass_tex.py); 'old' = previous noise patches
DEPTH_ON = '--no-depth' not in sys.argv     # --no-depth reproduces the old flat render for before/after shots
DEPTH = None
OUT = os.environ.get('LARK_OUT') or os.path.join(HERE, '..', '..', 'assets', 'art', 'zone1b', 'larkmoor')
os.makedirs(OUT, exist_ok=True)
W, H = LAY.W, LAY.H                       # the whole world is one canvas (1520x920); texel coords = canvas pixels
BLX, BLY = 0, 0
N = LAY.N                                 # world grid (u,v) in texel units
CU, CV, R = LAY.CU, LAY.CV, LAY.R         # island centre / radius (uv)
OXS0, OYS0 = LAY.OX, LAY.OY
OXS, OYS = OXS0, OYS0
PAL = ['#14161c', '#1f3b35', '#2f6b55', '#5fa36a', '#b7d978', '#f2e6a0', '#c2784e', '#f6efd9']
COLS = np.array([[int(h[k:k + 2], 16) for k in (1, 3, 5)] for h in PAL], np.uint8)
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]])
def s2uv(sx, sy): d = sx - OXS0; s = (sy - OYS0) * 2; return (s + d) / 2.0, (s - d) / 2.0

# ---------------- noise ----------------
def _hash(ix, iy, s):
    n = (ix.astype(np.int64) * 374761393 + iy.astype(np.int64) * 668265263 + np.int64(s) * 2147483647) & 0xffffffff
    n = ((n ^ (n >> 13)) * 1274126177) & 0xffffffff
    return ((n ^ (n >> 16)) & 0xffff) / 65535.0
def vn2(x, y, s=0):
    x0, y0 = np.floor(x), np.floor(y); fx, fy = x - x0, y - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b, c, d = _hash(x0, y0, s), _hash(x0 + 1, y0, s), _hash(x0, y0 + 1, s), _hash(x0 + 1, y0 + 1, s)
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy
def vn3(x, y, z, s=0):
    x0, y0, z0 = np.floor(x), np.floor(y), np.floor(z); fx, fy, fz = x - x0, y - y0, z - z0
    fx, fy, fz = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy), fz * fz * (3 - 2 * fz)
    def h(i, j, k): return _hash(x0 + i + k * 1013, y0 + j + k * 2711, s)
    c00 = h(0, 0, 0) * (1 - fx) + h(1, 0, 0) * fx; c10 = h(0, 1, 0) * (1 - fx) + h(1, 1, 0) * fx
    c01 = h(0, 0, 0 + 1) * (1 - fx) + h(1, 0, 1) * fx; c11 = h(0, 1, 1) * (1 - fx) + h(1, 1, 1) * fx
    return (c00 * (1 - fy) + c10 * fy) * (1 - fz) + (c01 * (1 - fy) + c11 * fy) * fz
def fbm2(x, y, o=4, s=0):
    t, a, f, n = 0, 1.0, 1.0, 0
    for i in range(o): t = t + a * vn2(x * f, y * f, s + i); n += a; a *= .5; f *= 2.03
    return t / n
def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)
def samp(A, u, v):
    u = np.clip(u, 0, N - 1.001); v = np.clip(v, 0, N - 1.001)
    i = np.floor(u).astype(int); j = np.floor(v).astype(int); fu = u - i; fv = v - j
    return (A[i, j] * (1 - fu) + A[i + 1, j] * fu) * (1 - fv) + (A[i, j + 1] * (1 - fu) + A[i + 1, j + 1] * fu) * fv
def pl_dist(U, V, pts):
    best = np.full(U.shape, 1e9)
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        vx, vy = x1 - x0, y1 - y0; L2 = vx * vx + vy * vy
        t = np.clip(((U - x0) * vx + (V - y0) * vy) / L2, 0, 1)
        best = np.minimum(best, np.hypot(U - (x0 + vx * t), V - (y0 + vy * t)))
    return best

# ---------------- scene layout (screen px -> uv) ----------------
PATHS_UV = [[s2uv(*p) for p in pp] for pp in LAY.PATHS]
PADS_S = [(x, y, 'ready') for d_ in LAY.DISTRICTS for (x, y) in d_['pads']]
GATE = s2uv(*LAY.EMBER_GATE); GATE2 = s2uv(*LAY.HOLLOW_GATE)
STREAM = [s2uv(*p) for p in LAY.STREAM]
LAKE = dict(c=s2uv(*LAY.LAKE['c']), r=LAY.LAKE['rx'] / 1.414 * .9)
POND = dict(c=s2uv(*LAY.MERE['c']), r=LAY.MERE['rx'] / 1.414 * .9)
LEVEL = 0.0
LDIR = np.array([-0.42, 0.46, 0.78]); LDIR /= np.linalg.norm(LDIR)
LXY = LDIR[:2] / np.linalg.norm(LDIR[:2]); TANE = LDIR[2] / np.linalg.norm(LDIR[:2])

# ---------------- terrain fields ----------------
gu, gv = np.meshgrid(np.arange(N, dtype=float), np.arange(N, dtype=float), indexing='ij')
rr = np.hypot(gu - CU, gv - CV); th = np.arctan2(gv - CV, gu - CU)
def Re(t): return R * (1 + .07 * np.sin(3 * t + 1.0) + .05 * np.sin(5 * t + 2.3) + .03 * np.sin(9 * t + .5))
RE = Re(th)
dpath = np.minimum.reduce([pl_dist(gu, gv, pp) for pp in PATHS_UV])
dgate = np.minimum(np.hypot(gu - GATE[0], gv - GATE[1]), np.hypot(gu - GATE2[0], gv - GATE2[1]))
log('terrain fields')
thb = math.atan2(-1, -1)
a = np.abs((th - thb + np.pi) % (2 * np.pi) - np.pi)
env_ang = .36 + .64 * (1 - smooth(1.15, 2.7, a))
m_r = smooth(.76, .985, rr / RE)
wu_, wv_ = gu + 34 * (fbm2(gu / 60, gv / 60, 2, 20) - .5), gv + 34 * (fbm2(gu / 60, gv / 60, 2, 21) - .5)
rg = (1 - np.abs(2 * fbm2(wu_ / 64, wv_ / 64, 5, 2) - 1)) ** 1.1
big = fbm2(gu / 95, gv / 95, 3, 7)
Hm = env_ang * m_r ** 1.15 * (14 + 62 * rg * (.5 + .75 * big) + 3 * (fbm2(gu / 9, gv / 9, 3, 9) - .5))
Hm *= 1 - .95 * (1 - smooth(14, 48, dgate))         # alcove for the gate
Hm *= 1 - .9 * (1 - smooth(4, 14, dpath))
base = 2.6 + 4.0 * (fbm2(gu / 48, gv / 48, 3, 3) - .5) + 1.0 * (fbm2(gu / 9, gv / 9, 2, 4) - .5)
fl = 1 - smooth(3, 14, dpath)
base = base * (1 - .85 * fl) + 2.6 * .85 * fl
Hm += env_ang * m_r * 22 * (1 - np.abs(2 * fbm2(gu / 30, gv / 30, 3, 40) - 1)) ** 2 * smooth(8, 26, Hm)
Hm = 60 * np.tanh(Hm / 60)
_st = 6.5; _fr = Hm / _st - np.floor(Hm / _st)
Hm = Hm * (1 - .55 * smooth(14, 30, Hm)) + .55 * smooth(14, 30, Hm) * _st * (np.floor(Hm / _st) + smooth(.45, .95, _fr))
H0 = base * (1 - m_r * env_ang * .7) + Hm
# lakes: enclosed bowls with a gentle beach
def bowl(H0, B, depth):
    dx, dy = gu - B['c'][0], gv - B['c'][1]; t = np.arctan2(dy, dx)
    r_eff = B['r'] * (1 + .24 * np.sin(2 * t + .7) + .14 * np.sin(3 * t + 2) + .08 * np.sin(5 * t + 1))
    s = np.hypot(dx, dy) / r_eff
    hb = np.where(s < 1, 2.6 - (2.6 + depth) * np.clip(1 - s ** 2, 0, 1) ** .8, 2.6)
    w = 1 - smooth(.97, 1.55, s)
    return H0 * (1 - w) + hb * w * 1.0 + 0 * w, s
H0, sl_ = bowl(H0, LAKE, 8.0); H0, sp_ = bowl(H0, POND, 5.0)
LAKE_S, POND_S = sl_, sp_
Hpre = H0.copy()
GUp, GVp = np.gradient(Hpre)
# stream: carve a channel; the water ribbon follows the (downhill-only) centreline height
dstr = pl_dist(gu, gv, STREAM)
sw = 6.4 + 1.2 * np.sin(gu * .13 + gv * .09)
D = []
for (x0, y0), (x1, y1) in zip(STREAM, STREAM[1:]):
    n = int(math.hypot(x1 - x0, y1 - y0)); D += [(x0 + (x1 - x0) * k / n, y0 + (y1 - y0) * k / n) for k in range(n)]
D = np.array(D); hD = samp(Hpre, D[:, 0], D[:, 1])
k = 7; hD = np.convolve(np.pad(hD, (k, k), mode='edge'), np.ones(2 * k + 1) / (2 * k + 1), mode='valid')
hL = np.maximum(np.minimum.accumulate(hD) - .8, LEVEL + .15)
HLF = np.full((N, N), 99.0)                     # water height of the nearest stream point, around the channel
_bu, _bv = np.nonzero(dstr < sw + 3)
for c0 in range(0, len(_bu), 20000):
    uu, vv = _bu[c0:c0 + 20000].astype(float), _bv[c0:c0 + 20000].astype(float)
    dd = np.hypot(uu[:, None] - D[None, :, 0], vv[:, None] - D[None, :, 1]); HLF[_bu[c0:c0 + 20000], _bv[c0:c0 + 20000]] = hL[dd.argmin(1)]
wch = (1 - smooth(sw - 2.0, sw + 4.5, dstr)) * (1 - smooth(0, 6, LAKE['r'] * 1.3 - np.hypot(gu - LAKE['c'][0], gv - LAKE['c'][1])))
H0 = H0 * (1 - wch) + np.minimum(H0, HLF - 1.0) * wch       # bed always sits below the water ribbon
WH = np.full((N, N), -99.0)
mask_s = dstr < sw + 1
iu, iv = np.nonzero(mask_s)
for c0 in range(0, len(iu), 20000):
    uu, vv = iu[c0:c0 + 20000].astype(float), iv[c0:c0 + 20000].astype(float)
    dd = np.hypot(uu[:, None] - D[None, :, 0], vv[:, None] - D[None, :, 1]); WH[iu[c0:c0 + 20000], iv[c0:c0 + 20000]] = hL[dd.argmin(1)]
inlake = (H0 < LEVEL) & ((sl_ < 1.25) | (sp_ < 1.25))
WH[inlake] = LEVEL
smask = mask_s & (dstr < sw - .3) & (WH > H0 + .02) & ~inlake
WH[~(smask | inlake)] = -99
WD = np.where(WH > -50, WH - H0, -1.0)
def _blur(A):
    return (A * 4 + np.roll(A, 1, 0) + np.roll(A, -1, 0) + np.roll(A, 1, 1) + np.roll(A, -1, 1) + .5 * (np.roll(np.roll(A, 1, 0), 1, 1) + np.roll(np.roll(A, -1, 0), 1, 1) + np.roll(np.roll(A, 1, 0), -1, 1) + np.roll(np.roll(A, -1, 0), -1, 1))) / 10.0
H0s = H0.copy()
for _ in range(3): H0s = _blur(H0s)
GU, GV = np.gradient(H0s)
DW = np.full((N, N), 9.0); DW[WD > .04] = 0; _cur = WD > .04
for _k in range(1, 9):
    _n = _cur.copy()
    for _dx, _dy in ((1,0),(-1,0),(0,1),(0,-1),(1,1),(-1,-1),(1,-1),(-1,1)): _n |= np.roll(np.roll(_cur, _dx, 0), _dy, 1)
    DW[_n & ~_cur] = _k; _cur = _n
LAP = (np.roll(H0, 1, 0) + np.roll(H0, -1, 0) + np.roll(H0, 1, 1) + np.roll(H0, -1, 1) - 4 * H0)
log('terrain done; max h %.1f' % H0.max())
INSIDE = rr < RE * .985
HS = H0.copy()                                    # shadow-casting height field (props added later)
def terrain_h(u, v): return samp(H0, u, v)
def slope_at(u, v): return np.hypot(samp(GU, u, v), samp(GV, u, v))

# ---------------- voxel prop framework ----------------
STEP = .5
PT = dict(u=[], v=[], z=[], nx=[], ny=[], nz=[], mat=[], id=[], aux=[], wl=[])   # surface points from props
inst_id = [10]
placed = []                      # (u, v, radius) footprints, to keep props from piling on each other
TALL = []                        # instances exported as separate y-sortable sprites
anchors = []                     # dynamic things the game draws itself (pads, gate, shrine, player spawn)
def sdf_sphere(x, y, z, c, r): return np.sqrt((x - c[0]) ** 2 + (y - c[1]) ** 2 + (z - c[2]) ** 2) - r
def sdf_capsule(x, y, z, a, b, r0, r1=None):
    r1 = r0 if r1 is None else r1
    px, py, pz = x - a[0], y - a[1], z - a[2]; bx, by, bz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
    t = np.clip((px * bx + py * by + pz * bz) / (bx * bx + by * by + bz * bz), 0, 1)
    return np.sqrt((px - bx * t) ** 2 + (py - by * t) ** 2 + (pz - bz * t) ** 2) - (r0 + (r1 - r0) * t)
def sdf_box(x, y, z, c, h, r=0.0):
    qx, qy, qz = np.abs(x - c[0]) - h[0] + r, np.abs(y - c[1]) - h[1] + r, np.abs(z - c[2]) - h[2] + r
    return np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2 + np.maximum(qz, 0) ** 2) + np.minimum(np.maximum(qx, np.maximum(qy, qz)), 0) - r
def sdf_ell(x, y, z, c, r): return (np.sqrt(((x - c[0]) / r[0]) ** 2 + ((y - c[1]) / r[1]) ** 2 + ((z - c[2]) / r[2]) ** 2) - 1) * min(r)

def voxelize(sdf, half, top, u0, v0, z0, scale=1.0, rot=0.0, sid=1, wl=0.0, bottom=-1.0):
    hx, hy = half[0] * scale, half[1] * scale
    xs = np.arange(-hx, hx + 1e-6, STEP, dtype=np.float32); ys = np.arange(-hy, hy + 1e-6, STEP, dtype=np.float32)
    zs = np.arange(bottom, top * scale + 1e-6, STEP, dtype=np.float32)
    X, Y, Z = np.meshgrid(xs, ys, zs, indexing='ij')
    c, s = math.cos(rot), math.sin(rot)
    lx, ly, lz = (c * X + s * Y) / scale, (-s * X + c * Y) / scale, Z / scale
    d, m = sdf(lx, ly, lz)
    d = d * scale
    ins = d < 0
    sh = np.zeros_like(ins)
    sh[1:-1, 1:-1, 1:-1] = ins[1:-1, 1:-1, 1:-1] & ~(ins[2:, 1:-1, 1:-1] & ins[:-2, 1:-1, 1:-1] & ins[1:-1, 2:, 1:-1] & ins[1:-1, :-2, 1:-1] & ins[1:-1, 1:-1, 2:] & ins[1:-1, 1:-1, :-2])
    gx, gy, gz = np.gradient(d, STEP)
    idx = np.nonzero(sh)
    if len(idx[0]) == 0: return
    nx_, ny_, nz_ = gx[idx], gy[idx], gz[idx]
    nl = np.sqrt(nx_ ** 2 + ny_ ** 2 + nz_ ** 2) + 1e-6; nx_, ny_, nz_ = nx_ / nl, ny_ / nl, nz_ / nl
    # the voxel grid lives in world offsets, so the gradient is already a world normal
    PT['u'].append(u0 + X[idx]); PT['v'].append(v0 + Y[idx]); PT['z'].append(z0 + Z[idx])
    PT['nx'].append(nx_); PT['ny'].append(ny_); PT['nz'].append(nz_)
    PT['mat'].append(m[idx].astype(np.int16) if hasattr(m, 'shape') and m.shape == d.shape else np.full(len(idx[0]), int(m), np.int16))
    if sid == 'new': inst_id[0] += 1; sid = inst_id[0]
    PT['id'].append(np.full(len(idx[0]), sid, np.int32)); PT['aux'].append(np.zeros(len(idx[0]), np.float32)); PT['wl'].append(np.full(len(idx[0]), wl, np.float32))

# material codes
(M_FOL, M_BARK, M_PINE, M_ROCK, M_MOSS, M_CRYS, M_WOOD, M_PADT, M_PETA, M_PETB, M_STEM, M_LILY, M_REED, M_CAT, M_BERRY, M_CAP, M_CSTEM, M_PAPER, M_GRASS, M_BARKT, M_BARKT2, M_PEB, M_FACE, M_INK) = range(10, 34)

# ---------------- prop models (local coords: x right, y toward camera, z up) ----------------
def make_oak(rng):
    lx, ly = rng.uniform(-1.5, 1.5), rng.uniform(-1.5, 1.5)
    balls = [(0, 0, 27, 9.5)] + [(rng.uniform(-9.5, 9.5), rng.uniform(-9.5, 9.5), rng.uniform(21, 33), rng.uniform(6.5, 9)) for _ in range(6)]
    roots = [(rng.uniform(0, 6.28)) for _ in range(3)]
    seed = rng.randint(0, 99)
    def f(x, y, z):
        tr = sdf_capsule(x, y, z, (0, 0, -1), (lx, ly, 18), 3.0, 1.8)
        for a_ in roots: tr = np.minimum(tr, sdf_capsule(x, y, z, (0, 0, 2.5), (math.cos(a_) * 5, math.sin(a_) * 5, -.5), 1.3, .5))
        cd = np.full(x.shape, 99.0, np.float32)
        for b in balls: cd = np.minimum(cd, sdf_sphere(x, y, z, b[:3], b[3]))
        cd = cd + 2.2 * (vn3(x * .38, y * .38, z * .38, seed) - .5) + 1.0 * (vn3(x * .9, y * .9, z * .9, seed + 3) - .5)
        return np.minimum(tr, cd), np.where(tr < cd, M_BARK, M_FOL)
    return f, (24, 24), 44, 12.0
def make_pine(rng):
    seed = rng.randint(0, 99)
    def f(x, y, z):
        q = np.sqrt(x * x + y * y); ang = np.arctan2(y, x)
        d = sdf_capsule(x, y, z, (0, 0, -1), (0, 0, 10), 1.6, 1.3); m = np.full(x.shape, M_BARK, np.int16)
        for i in range(5):
            zb = 6 + i * 7.4; rb = 11.5 - i * 2.0; ht = 11.5
            t = np.clip((z - zb) / ht, 0, 1)
            rad = rb * (1 - t) * (1 + .13 * np.sin(6 * ang + i * 1.3 + seed))
            di = np.maximum(q - rad, np.maximum(-(z - zb), z - zb - ht)) * .8
            di = di + 1.0 * (vn3(x * .6, y * .6, z * .6, seed) - .5)
            m = np.where(di < d, M_PINE, m); d = np.minimum(d, di)
        return d, m
    return f, (14, 14), 52, 8.0
def make_bush(rng):
    seed = rng.randint(0, 99); balls = [(rng.uniform(-4, 4), rng.uniform(-4, 4), rng.uniform(3.5, 6), rng.uniform(4.2, 6)) for _ in range(4)]
    berries = [(rng.uniform(-6, 6), rng.uniform(-6, 6), rng.uniform(3, 8)) for _ in range(7)] if rng.random() < .6 else []
    def f(x, y, z):
        d = np.full(x.shape, 99.0, np.float32)
        for b in balls: d = np.minimum(d, sdf_sphere(x, y, z, b[:3], b[3]))
        d = d + 1.6 * (vn3(x * .45, y * .45, z * .45, seed) - .5); m = np.full(x.shape, M_FOL, np.int16)
        for b in berries:
            db = sdf_sphere(x, y, z, b, 1.0) ; sel = db < d; m = np.where(sel, M_BERRY, m); d = np.minimum(d, db)
        return d, m
    return f, (11, 11), 13, 6.5
def make_rock(rng, big=True):
    seed = rng.randint(0, 99); rx, ry, rz = (rng.uniform(6.5, 9), rng.uniform(5.5, 8), rng.uniform(4.5, 7)) if big else (rng.uniform(3, 4.5), rng.uniform(2.5, 4), rng.uniform(2, 3))
    def f(x, y, z):
        d = sdf_ell(x, y, z, (0, 0, rz * .55), (rx, ry, rz))
        d = d + (2.4 if big else 1.0) * (vn3(x * .26, y * .26, z * .26, seed) - .5) * 2 + .8 * (vn3(x * .7, y * .7, z * .7, seed + 5) - .5)
        return d, np.full(x.shape, M_ROCK, np.int16)
    return f, (rx + 3, ry + 3), rz * 1.6 + 2, max(rx, ry) + 1
def make_crystals(rng):
    items = []
    for i in range(rng.randint(3, 5)):
        a_ = rng.uniform(0, 6.28); rd = 0 if i == 0 else rng.uniform(3.5, 8)
        items.append((math.cos(a_) * rd, math.sin(a_) * rd, rng.uniform(-.3, .3), rng.uniform(-.3, .3), (34 if i == 0 else rng.uniform(14, 26)), rng.uniform(3.2, 5.0)))
    def f(x, y, z):
        d = np.full(x.shape, 99.0, np.float32)
        for (cx, cy, tx, ty, h, w) in items:
            px, py, pz = x - cx, y - cy, z + 1.0
            qx, qy = px - tx * pz, py - ty * pz            # lean
            hx = np.maximum(np.abs(qx * .866 + qy * .5), np.maximum(np.abs(qx * .866 - qy * .5), np.abs(qy)))
            tipf = np.clip((pz - h * .62) / (h * .38), 0, 1)
            ap = w * (1 - tipf * .97)
            dd = np.maximum(hx - ap, np.maximum(-pz, pz - h)) * .85
            d = np.minimum(d, dd)
        return d, np.full(x.shape, M_CRYS, np.int16)
    return f, (16, 16), 40, 10.0
def make_stump(rng):
    seed = rng.randint(0, 99)
    def f(x, y, z):
        q = np.sqrt(x * x + y * y); ang = np.arctan2(y, x)
        rad = 5.2 + 2.2 * np.clip(1 - z / 3, 0, 1) * (.5 + .5 * np.sin(3 * ang + seed)) + .5 * (vn3(x * .5, y * .5, z * .5, seed) - .5)
        d = np.maximum(q - rad, np.maximum(-z, z - 7)) * .9
        m = np.where((z > 6.2), M_BARKT + (np.floor(q * .9) % 2).astype(np.int16), M_BARK)
        return d, m.astype(np.int16)
    return f, (9, 9), 8, 6.5
def make_mush(rng):
    caps = [(rng.uniform(-4, 4), rng.uniform(-4, 4), rng.uniform(2.2, 3.4), rng.uniform(3, 6)) for _ in range(3)]
    def f(x, y, z):
        d = np.full(x.shape, 99.0, np.float32); m = np.full(x.shape, M_CSTEM, np.int16)
        for (cx, cy, r, h) in caps:
            ds = sdf_capsule(x, y, z, (cx, cy, 0), (cx, cy, h), r * .38)
            dc = sdf_ell(x, y, z, (cx, cy, h), (r, r, r * .62))
            dc = np.where(z < h - .2, 9, dc)
            dot = vn3(x * 1.3, y * 1.3, z * 1.3, 4) > .73
            m = np.where(dc < np.minimum(d, ds), np.where(dot, M_PAPER, M_CAP), np.where(ds < d, M_CSTEM, m)); d = np.minimum(d, np.minimum(ds, dc))
        return d, m
    return f, (8, 8), 10, 6.0
def make_flower(rng):
    """Layered bloom: two leaves on the stem, a ring of cupped outer petals (darker underside), a raised inner ring
    in a second tint, and a centre. Each layer is a different height and material so the depth pass can separate them."""
    h = rng.uniform(5.0, 9.0); lx, ly = rng.uniform(-1.2, 1.2), rng.uniform(-1.2, 1.2)
    outer, inner = rng.choice(((M_PETB, M_PETA), (M_PETA, M_PETA), (M_PETB, M_PAPER), (M_PETA, M_PAPER)))
    ph = rng.uniform(0, 6.28); np_ = rng.randint(5, 7); leaf = [rng.uniform(0, 6.28) for _ in range(2)]
    def f(x, y, z):
        d = sdf_capsule(x, y, z, (0, 0, 0), (lx, ly, h), .45); m = np.full(x.shape, M_STEM, np.int16)
        for k, a_ in enumerate(leaf):                       # leaves: flat blades that arc out and down from the stem
            t = .35 + .2 * k; bx, by, bz = lx * t, ly * t, h * t
            dl = sdf_capsule(x, y, z, (bx, by, bz), (bx + math.cos(a_) * 3.6, by + math.sin(a_) * 3.6, bz + 1.6 - k), .55, .12)
            m = np.where(dl < d, M_GRASS, m); d = np.minimum(d, dl)
        c = (lx, ly, h + .5)
        for k in range(np_):                                # outer ring: petals splay out and cup up
            a_ = ph + k * 6.2832 / np_; ca, sa = math.cos(a_), math.sin(a_)
            dp = sdf_capsule(x, y, z, (c[0] + ca * .6, c[1] + sa * .6, c[2] - .2), (c[0] + ca * 2.3, c[1] + sa * 2.3, c[2] + .9), .85, .6)
            m = np.where(dp < d, outer, m); d = np.minimum(d, dp)
        for k in range(4):                                  # inner ring: smaller, raised, rotated half a step
            a_ = ph + .8 + k * 1.5708; ca, sa = math.cos(a_), math.sin(a_)
            dp = sdf_capsule(x, y, z, (c[0] + ca * .3, c[1] + sa * .3, c[2] + .5), (c[0] + ca * 1.1, c[1] + sa * 1.1, c[2] + 1.5), .7, .5)
            m = np.where(dp < d, inner, m); d = np.minimum(d, dp)
        dc = sdf_sphere(x, y, z, (c[0], c[1], c[2] + 1.2), .8); m = np.where(dc < d, M_PAPER, m); d = np.minimum(d, dc)
        return d, m
    return f, (5, 5), h + 4, 2.4

def make_tuft(rng):
    bl = [(rng.uniform(-2.2, 2.2), rng.uniform(-2.2, 2.2), rng.uniform(4.5, 9), rng.uniform(-2.2, 2.2), rng.uniform(-2.2, 2.2)) for _ in range(rng.randint(5, 8))]
    def f(x, y, z):
        d = np.full(x.shape, 99.0, np.float32)
        for (bx, by, h, tx, ty) in bl: d = np.minimum(d, sdf_capsule(x, y, z, (bx, by, -.5), (bx + tx, by + ty, h), .75, .15))
        return d, np.full(x.shape, M_GRASS, np.int16)
    return f, (6, 6), 10, 2.5
def make_reed(rng):
    st = [(rng.uniform(-2.5, 2.5), rng.uniform(-2.5, 2.5), rng.uniform(9, 15), rng.uniform(-1.5, 1.5), rng.uniform(-1.5, 1.5), rng.random() < .5) for _ in range(rng.randint(3, 5))]
    def f(x, y, z):
        d = np.full(x.shape, 99.0, np.float32); m = np.full(x.shape, M_REED, np.int16)
        for (bx, by, h, tx, ty, cat) in st:
            ds = sdf_capsule(x, y, z, (bx, by, -1), (bx + tx, by + ty, h), .6, .25); m = np.where(ds < d, M_REED, m); d = np.minimum(d, ds)
            if cat:
                dc = sdf_capsule(x, y, z, (bx + tx * .95, by + ty * .95, h - 4), (bx + tx, by + ty, h), 1.05, .8); m = np.where(dc < d, M_CAT, m); d = np.minimum(d, dc)
        return d, m
    return f, (7, 7), 17, 3.0
def make_lily(rng, r, flower):
    a0 = rng.uniform(0, 6.28)
    def f(x, y, z):
        q = np.sqrt(x * x + y * y); ang = np.arctan2(y, x)
        notch = (np.abs((ang - a0 + 3.14159) % 6.28318 - 3.14159) < .22) & (q > .8)
        d = np.maximum(q - r, np.maximum(-.7 - z, z - (.35 + .5 * smooth(r * .6, r, q)))) 
        d = np.where(notch, 9, d); m = np.full(x.shape, M_LILY, np.int16)
        if flower:
            for k in range(5):
                a_ = k * 1.2566; dp = sdf_sphere(x, y, z, (math.cos(a_) * 1.4, math.sin(a_) * 1.4, 1.1), 1.0); m = np.where(dp < d, M_PETA, m); d = np.minimum(d, dp)
            dc = sdf_sphere(x, y, z, (0, 0, 1.2), .9); m = np.where(dc < d, M_PAPER, m); d = np.minimum(d, dc)
        return d, m
    return f, (r + 2, r + 2), 3.5, r
def make_sign(rng):
    def f(x, y, z):
        d = sdf_box(x, y, z, (0, 0, 7), (.9, .9, 7.2)); m = np.full(x.shape, M_BARK, np.int16)
        db = sdf_box(x, y, z, (1.5, 0, 12.5), (9, 1.1, 3.1), .4); sel = db < d; m = np.where(sel, M_WOOD, m); d = np.minimum(d, db)
        dt = sdf_box(x, y, z, (10.6, 0, 12.5), (2.2, 1.1, 2.2), .3); dt = np.maximum(dt, (np.abs(z - 12.5) - (3.3 - (x - 9) * .9)) * .7); sel = dt < d; m = np.where(sel, M_WOOD, m); d = np.minimum(d, dt)
        for k in range(5):
            dd = sdf_sphere(x, y + 1.0, z, (-5 + k * 2.2, 0, 12.5), .6); sel = dd < d; m = np.where(sel, M_INK, m); d = np.minimum(d, dd)
        return d, m
    return f, (14, 4), 17, 3.0
def make_lantern(rng):
    def f(x, y, z):
        d = sdf_capsule(x, y, z, (0, 0, -1), (0, 0, 13), .9); m = np.full(x.shape, M_BARK, np.int16)
        dl = sdf_box(x, y, z, (0, 0, 17), (2.6, 2.6, 3.2), .4); sel = dl < d; m = np.where(sel, M_PAPER + 20, m); d = np.minimum(d, dl)
        dc = sdf_box(x, y, z, (0, 0, 20.8), (3.6, 3.6, .8), .3); sel = dc < d; m = np.where(sel, M_INK, m); d = np.minimum(d, dc)
        return d, m
    return f, (7, 7), 23, 2.5
def make_windmill(rng):
    def f(x, y, z):
        r = 9.5 - z * .12
        d = np.sqrt(x ** 2 + y ** 2) - r; d = np.maximum(d, -z); d = np.maximum(d, z - 34); m = np.full(x.shape, M_PAPER, np.int16)
        door = sdf_box(x, y + 8.5, z, (0, 0, 4.2), (2.4, 1.6, 4.2), .3); sel = door < d + 1.2; m = np.where(sel, M_BARK, m); d = np.where(sel, np.maximum(d, -door + .4) * 0 + np.minimum(d, door + 1.2) * 0 + d, d)
        band = (np.abs(z - 16) < 1.2); m = np.where(band & (d < 1.5), M_BARKT, m)
        roof = np.maximum(np.sqrt(x ** 2 + y ** 2) - (7.2 - (z - 32) * .85), np.abs(z - 36.0) - 4.4)
        sel = roof < d; m = np.where(sel, M_BARKT2, m); d = np.minimum(d, roof)
        for k in range(4):
            ang = .62 + k * 1.5708; ex, ez = math.cos(ang) * 27, math.sin(ang) * 27
            arm = sdf_capsule(x, y, z, (0, 10.4, 35), (ex, 10.4, 35 + ez), .75); sel = arm < d; m = np.where(sel, M_WOOD, m); d = np.minimum(d, arm)
            sail = sdf_capsule(x, y, z, (ex * .35 - math.sin(ang) * 2.6, 10.6, 35 + ez * .35 + math.cos(ang) * 2.6), (ex * .95 - math.sin(ang) * 2.6, 10.6, 35 + ez * .95 + math.cos(ang) * 2.6), 2.4, 3.0)
            sel = sail < d; m = np.where(sel, M_PAPER + 20, m); d = np.minimum(d, sail)
        hub = sdf_sphere(x, y, z, (0, 10.4, 35), 1.8); sel = hub < d; m = np.where(sel, M_BARK, m); d = np.minimum(d, hub)
        return d, m
    return f, (26, 24), 58, 11
def make_gateway(rng):
    def f(x, y, z):
        d = np.full(x.shape, 1e3); m = np.full(x.shape, M_ROCK, np.int16)
        for px in (-9.5, 9.5):
            dp = sdf_box(x, y, z, (px, 0, 9.5), (2.7, 2.4, 9.5), .7) + (vn3(x * .5, y * .5, z * .5, 4) - .5) * 1.0; sel = dp < d; d = np.minimum(d, dp)
            dc = sdf_box(x, y, z, (px, 0, 19.6), (3.4, 3.1, .9), .4); sel = dc < d; m = np.where(sel, M_BARKT, m); d = np.minimum(d, dc)
            dl = sdf_box(x, y, z, (px, 0, 22.3), (1.2, 1.2, 1.6), .4); sel = dl < d; m = np.where(sel, M_PAPER + 20, m); d = np.minimum(d, dl)
        db = sdf_box(x, y, z, (0, 0, 17.8), (11.5, 1.8, 1.5), .5); sel = db < d; m = np.where(sel, M_BARK, m); d = np.minimum(d, db)
        return d, m
    return f, (16, 6), 26, 3
def make_tower(rng, banded=False, h=44.0):
    def f(x, y, z):
        r = 9.0 - z * .05
        d = np.sqrt(x ** 2 + y ** 2) - r; d = np.maximum(d, -z); d = np.maximum(d, z - h); m = np.full(x.shape, M_ROCK, np.int16)
        if banded: m = np.where((np.floor(z / 6.0) % 2) == 0, M_PAPER, M_BARKT2)
        door = sdf_box(x, y + 8, z, (0, 0, 4), (2.2, 1.8, 4), .3); sel = door < 0.6; m = np.where(sel & (d < 1.5), M_BARK, m)
        gal = np.maximum(np.sqrt(x ** 2 + y ** 2) - (r + 2.4), np.abs(z - (h + 1)) - .9); sel = gal < d; m = np.where(sel, M_BARK, m); d = np.minimum(d, gal)
        room = np.maximum(np.sqrt(x ** 2 + y ** 2) - 4.6, np.abs(z - (h + 5.2)) - 3.4); sel = room < d; m = np.where(sel, M_PAPER + 20, m); d = np.minimum(d, room)
        cap = np.maximum(np.sqrt(x ** 2 + y ** 2) - (6.4 - (z - (h + 8.6)) * .9), np.abs(z - (h + 11)) - 2.6); sel = cap < d; m = np.where(sel, M_BARKT2, m); d = np.minimum(d, cap)
        return d, m
    return f, (14, 14), h + 16, 10
def make_obelisk(rng):
    def f(x, y, z):
        w = 5.2 - z * .06
        d = sdf_box(x, y, z, (0, 0, 20), (w, w, 20), .5) + (vn3(x * .4, y * .4, z * .4, 6) - .5) * 1.2; m = np.full(x.shape, M_ROCK, np.int16)
        cr = sdf_ell(x, y, z, (0, 0, 46), (3.2, 3.2, 8)); sel = cr < d; m = np.where(sel, M_CRYS, m); d = np.minimum(d, cr)
        return d, m
    return f, (9, 9), 56, 6
def make_menhir(rng):
    h = rng.uniform(9, 14); tilt = rng.uniform(-.12, .12)
    def f(x, y, z):
        d = sdf_box(x + tilt * z, y, z, (0, 0, h / 2), (2.1, 1.7, h / 2), .9); d = d + (vn3(x * .5, y * .5, z * .5, 3) - .5) * 1.2
        return d, np.full(x.shape, M_ROCK, np.int16)
    return f, (5, 5), h + 3, 2.6
def make_jetty(rng):
    def f(x, y, z):
        d = sdf_box(x, y, z, (0, 0, .5), (15, 2.4, .45), .15); m = np.full(x.shape, M_WOOD, np.int16)
        for px in (-12, -4, 4, 12):
            for py in (-2.4, 2.4):
                dp = sdf_capsule(x, y, z, (px, py, -1), (px, py, 3), .55); sel = dp < d; m = np.where(sel, M_BARK, m); d = np.minimum(d, dp)
        m = np.where(((np.floor(x / 1.6) % 2) == 0) & (d < .4), M_BARKT2, m)
        return d, m
    return f, (17, 5), 4, 2
def make_bridge(rng):
    def f(x, y, z):
        d = sdf_box(x, y, z, (0, 0, -.6), (14, 4.6, 1.3), .4); m = np.full(x.shape, M_WOOD, np.int16)
        for sy_ in (-4.0, 4.0):
            dr = sdf_box(x, y, z, (0, sy_, 3.0), (14, .7, .7), .25); sel = dr < d; m = np.where(sel, M_BARK, m); d = np.minimum(d, dr)
            for px in (-13, -6.5, 0, 6.5, 13):
                dp = sdf_capsule(x, y, z, (px, sy_, -3.0), (px, sy_, 3.4), .8); sel = dp < d; m = np.where(sel, M_BARK, m); d = np.minimum(d, dp)
        m = np.where(((np.floor(x / 1.5) % 2) == 0) & (z > .3) & (d < .5), M_WOOD + 0, m)
        return d, m
    return f, (16, 7), 5, 2
log('props defined')

# ---------------- placement (Poisson-style spacing, no stacking, off-grid) ----------------
prng = random.Random(7)
WATERNEAR = None
def ok_spot(u, v, r, slope_max=.55, shore=True, path=True, hmax=9.0, gap=1.5):
    if not (0 < u < N - 1 and 0 < v < N - 1): return False
    if np.hypot(u - CU, v - CV) > Re(math.atan2(v - CV, u - CU)) * .9 - r * .5: return False
    h = float(terrain_h(u, v))
    if h > hmax or float(slope_at(u, v)) > slope_max: return False
    for a_ in range(0, 360, 60):
        uu, vv = u + math.cos(math.radians(a_)) * r * .8, v + math.sin(math.radians(a_)) * r * .8
        if float(samp(WD, uu, vv)) > -.5: return False
        if shore and float(samp(DW, uu, vv)) < 3.5: return False
    if float(samp(WD, u, v)) > -.5: return False
    if path and float(samp(dpath, u, v)) < r + 4.5: return False
    if min(np.hypot(u - GATE[0], v - GATE[1]), np.hypot(u - GATE2[0], v - GATE2[1])) < r + 26: return False
    for (pu, pv, pr) in placed:
        if math.hypot(u - pu, v - pv) < r + pr + gap: return False
    return True
def put(kind, u, v, scale=1.0, rot=None, sid='new', z_extra=0.0, count=True, **kw):
    rng = random.Random(prng.randint(0, 1 << 30))
    rot = rng.uniform(0, 6.283) if rot is None else rot
    big = kw.get('big', True)
    if sid == 'new': inst_id[0] += 1; sid = inst_id[0]
    mk = dict(oak=make_oak, pine=make_pine, bush=make_bush, rock=lambda r: make_rock(r, big), crystals=make_crystals, stump=make_stump,
              mush=make_mush, flower=make_flower, tuft=make_tuft, reed=make_reed, sign=make_sign, lantern=make_lantern, windmill=make_windmill, tower=lambda r: make_tower(r), lighthouse=lambda r: make_tower(r, True, 56.0), obelisk=make_obelisk, gateway=make_gateway, menhir=make_menhir, jetty=make_jetty, bridge=make_bridge)[kind](rng)
    f, half, top, rad = mk
    z0 = float(terrain_h(u, v)) + z_extra
    voxelize(f, half, top, u, v, z0, scale, rot, sid)
    if isinstance(sid, int) and sid >= 10 and (kind in ('oak', 'pine', 'bush', 'crystals', 'windmill', 'tower', 'lighthouse', 'obelisk', 'gateway', 'menhir', 'lantern', 'sign') or (kind == 'rock' and big)):
        TALL.append(dict(id=sid, kind=kind, u=u, v=v, z=z0))
    if count: placed.append((u, v, rad * scale))
    return z0
def try_region(kind, cu_, cv_, rad, n, scale_rng=(.9, 1.15), tries=60, **kw):
    got = 0
    r_fp = dict(oak=10, pine=7, bush=6, rock=7, stump=6.5, mush=6, crystals=9, sign=6, lantern=3, windmill=12, tower=11, lighthouse=11, obelisk=6, gateway=10, menhir=3, jetty=3, bridge=3)[kind]
    for _ in range(n):
        for t in range(tries):
            a_, rd = prng.uniform(0, 6.283), math.sqrt(prng.random()) * rad
            u, v = cu_ + math.cos(a_) * rd, cv_ + math.sin(a_) * rd
            sc = prng.uniform(*scale_rng)
            if ok_spot(u, v, r_fp * sc, **{k: w for k, w in kw.items() if k in ('slope_max', 'shore', 'path', 'hmax', 'gap')}):
                put(kind, u, v, sc, **{k: w for k, w in kw.items() if k == 'big'}); got += 1; break
    return got
SC = lambda p: s2uv(*p)
# anchors the game draws itself (player spawn, pads, arrival and far gates): positions only, nothing baked
for (sx, sy, st) in PADS_S: anchors.append(dict(kind='pad', state=st, **dict(zip(('u', 'v'), s2uv(sx, sy))), sx=sx, sy=sy))
anchors.append(dict(kind='gate', u=GATE[0], v=GATE[1], sx=LAY.EMBER_GATE[0], sy=LAY.EMBER_GATE[1]))
anchors.append(dict(kind='arch', u=GATE2[0], v=GATE2[1], sx=LAY.HOLLOW_GATE[0], sy=LAY.HOLLOW_GATE[1]))
anchors.append(dict(kind='player_spawn', sx=LAY.SPAWN[0], sy=LAY.SPAWN[1], u=s2uv(*LAY.SPAWN)[0], v=s2uv(*LAY.SPAWN)[1]))
for d_ in LAY.DISTRICTS: anchors.append(dict(kind='district', name=d_['name'], id=d_['id'], u=s2uv(*d_['c'])[0], v=s2uv(*d_['c'])[1], sx=d_['c'][0], sy=d_['c'][1]))
for a_ in anchors:
    if a_['kind'] in ('pad', 'gate', 'arch', 'player_spawn'): placed.append((a_['u'], a_['v'], 12 if a_['kind'] == 'pad' else 18 if a_['kind'] != 'player_spawn' else 8))
# the two gateways (onboarding arch in the south, Emberwatch gate in the north), framing the walk-through
for _g in (GATE, GATE2): put('gateway', _g[0], _g[1], 1.0, rot=-.785, count=False)
# landmarks first so groves flow around them
for lm in LAY.LANDMARKS:
    u, v = s2uv(*lm['at'])
    if lm['kind'] == 'elder_oak': put('oak', u, v, 1.9, rot=.7, sid='new')
    elif lm['kind'] in ('tower', 'lighthouse', 'obelisk'): put(lm['kind'], u, v, 1.0, rot=0.0)
    elif lm['kind'] == 'great_lantern': put('lantern', u, v, 2.6, rot=0.0)
    elif lm['kind'] == 'windmill': put('windmill', u, v, 1.0, rot=-.785)
    elif lm['kind'] == 'stones':
        for k in range(7):
            a_ = k / 7 * 6.283 + .3; put('menhir', u + math.cos(a_) * 15, v + math.sin(a_) * 15, prng.uniform(.9, 1.2), rot=a_)
    elif lm['kind'] == 'jetty':
        ju, jv = LAKE['c']
        for k in range(120):
            ju += .7; jv += .7
            if float(samp(WD, ju, jv)) < -.5 and LAKE_S[int(min(max(ju, 0), N - 1)), int(min(max(jv, 0), N - 1))] > 1.0: break
        put('jetty', ju - 7, jv - 7, 1.0, rot=.785, z_extra=-.3)
        JETTY_AT = (ju, jv)
    elif lm['kind'] == 'sign': put('sign', u, v, 1.0)
# bridge where the main road crosses the stream
bu, bv = s2uv(*LAY.BRIDGE); put('bridge', bu, bv, 1.0, rot=.785, z_extra=3.0, count=False)
# groves: oaks, pines, bushes, rocks, crystals, never stacked
for kind, c_, rad, n in LAY.GROVES:
    kw = dict(scale_rng=(.75, 1.4)) if kind == 'pine' else dict(scale_rng=(.9, 1.2))
    if kind == 'crystals': kw = dict(tries=120, slope_max=.7, hmax=14)
    try_region(kind, *SC(c_), rad * .72, n if not FAST else max(1, n // 3), **kw)
for _ in range(14): try_region('rock', prng.uniform(80, 740), prng.uniform(80, 740), 90, 1, scale_rng=(.8, 1.25), big=prng.random() < .6)
# lanterns along the north roads and the arrival lawn
for pp in (LAY.PATH_NE, LAY.PATH_MAIN[:4]):
    for (x0, y0), (x1, y1) in zip(pp, pp[1:]):
        if prng.random() < .8:
            mx, my = (x0 + x1) / 2 + 16, (y0 + y1) / 2 + 6; u, v = s2uv(mx, my)
            if ok_spot(u, v, 3, path=False, gap=0, slope_max=.7): put('lantern', u, v, 1.0)
log('trees/rocks placed', len(placed))

# ground cover: tufts and flower drifts in clusters, flowers lean toward the path edges
def cluster(kind, cu_, cv_, spread, n, **kw):
    for _ in range(n):
        u, v = cu_ + prng.gauss(0, spread), cv_ + prng.gauss(0, spread)
        if ok_spot(u, v, 1.2, slope_max=.7, path=False, gap=-1.0) and float(samp(dpath, u, v)) > (7.5 if kind == 'flower' else 5.5) and float(terrain_h(u, v)) < 10:
            put(kind, u, v, prng.uniform(.85, 1.2) * (1.45 if kind == 'flower' else 1.0), count=False, sid=1)
for _ in range(150 if not FAST else 8): cluster('tuft', prng.uniform(60, 760), prng.uniform(60, 760), 7, prng.randint(3, 7))
for _ in range(100 if not FAST else 6): cluster('flower', prng.uniform(60, 760), prng.uniform(60, 760), 6, prng.randint(5, 10))
for _ in range(50 if not FAST else 0): cluster('flower', *SC((1030 + prng.uniform(-110, 110), 560 + prng.uniform(-50, 50))), 8, prng.randint(8, 14))   # Thistle Rise fields
for (sx, sy, st) in PADS_S:
    u, v = s2uv(sx, sy); cluster('tuft', u + 14, v - 6, 6, 4); cluster('flower', u - 12, v + 8, 5, 5)
log('cover placed', len(placed))
# shore: reeds, pebbles; lilies on open water
def shore_spots(n, lo, hi):
    out = []
    for _ in range(n * 40):
        u, v = prng.uniform(0, N - 1), prng.uniform(0, N - 1)
        h = float(terrain_h(u, v))
        if lo < float(samp(DW, u, v)) < hi and float(samp(WD, u, v)) < -.3 and abs(float(samp(dpath, u, v))) > 6 and INSIDE[int(u), int(v)]:
            out.append((u, v))
        if len(out) >= n: break
    return out
for (u, v) in shore_spots(150 if not FAST else 8, 1.3, 3.2):
    if prng.random() < .8: put('reed', u, v, prng.uniform(.9, 1.2), count=False, sid=1)
for (u, v) in shore_spots(110 if not FAST else 6, .8, 4.0):
    f_, half, top, rad = make_rock(random.Random(prng.randint(0, 1 << 30)), False); voxelize(f_, half, top, u, v, float(terrain_h(u, v)) - .4, prng.uniform(.5, .9), prng.uniform(0, 6.28), 1)
for B, nl, rmin in ((LAKE, 90, 2.2), (POND, 30, 2.0)):
    got = 0
    for _ in range(nl * 30):
        u = B['c'][0] + prng.uniform(-B['r'] * 1.5, B['r'] * 1.5); v = B['c'][1] + prng.uniform(-B['r'] * 1.5, B['r'] * 1.5)
        if float(samp(WD, u, v)) > 3.2 and float(samp(WD, u + 3, v)) > 2.5 and float(samp(WD, u, v + 3)) > 2.5 and float(samp(WD, u - 3, v - 3)) > 2.5:
            r = prng.choice((2.1, 2.6, 3.0, 3.6, 4.2)); mk = make_lily(random.Random(prng.randint(0, 1 << 30)), r, prng.random() < .22)
            ok = all(math.hypot(u - pu, v - pv) > r + pr + .6 for (pu, pv, pr) in placed[-400:] if pr < 5.5)
            if ok:
                voxelize(mk[0], mk[1], mk[2], u, v, LEVEL, 1.0, 0.0, 1, bottom=-.9); placed.append((u, v, r)); got += 1
        if got >= nl: break
log('shore + lilies placed')

# ---------------- gather prop points & shadow height field ----------------
P = {k: (np.concatenate(v) if v else np.zeros(0)) for k, v in PT.items()}
log('prop surface points: %d' % len(P['u']))
if len(P['u']):
    ci = np.clip(P['u'].astype(int), 0, N - 1); cj = np.clip(P['v'].astype(int), 0, N - 1)
    np.maximum.at(HS, (ci, cj), P['z'])
# ---------------- terrain points ----------------
fu = np.arange(8, N - 8, .45); FU, FV = np.meshgrid(fu, fu, indexing='ij'); FU, FV = FU.ravel(), FV.ravel()
sel = np.hypot(FU - CU, FV - CV) < Re(np.arctan2(FV - CV, FU - CU)); FU, FV = FU[sel], FV[sel]
h = samp(H0, FU, FV); gu_, gv_ = samp(GU, FU, FV), samp(GV, FU, FV); slope = np.hypot(gu_, gv_)
nrm = np.stack([-gu_, -gv_, np.ones_like(gu_)], 1); nrm /= np.linalg.norm(nrm, axis=1, keepdims=True)
wd = samp(WD, FU, FV); wh = samp(WH, FU, FV)
dp = samp(dpath, FU, FV)
tone = fbm2(FU / 14, FV / 14, 2, 11); n1 = vn2(FU / 5, FV / 5, 3); n2 = vn2(FU / 2.2, FV / 2.2, 8)
# materials: 0 grass 1 rock 2 sand 3 wet 4 path 5 frost
T_GRASS, T_ROCK, T_SAND, T_WET, T_PATH, T_FROST, T_EARTH, T_WATER, T_FOAM = 100, 101, 102, 103, 104, 105, 106, 107, 108
mat = np.full(len(FU), T_GRASS, np.int16)
rockness = smooth(.42, .85, slope + np.clip(h - 10, 0, 50) / 50 + (n1 - .5) * .25)
mat[rockness > .5] = T_ROCK
mat[(h > 54) & (slope < 2.6) & (n2 > .3) & (rockness > .3)] = T_FROST
dwt = samp(DW, FU, FV) + (n2 - .5) * 2.2
beach = (dwt < 5.5) & (slope < 1.1) & (h < 6)
mat[beach] = T_SAND; mat[(dwt < 2.0) & beach] = T_WET
pw = 5.4 + 1.6 * (n1 - .5)
mat[(dp < pw) & (rockness < .5)] = T_PATH
L = LDIR
diff = np.clip(nrm @ L, 0, 1)
if GRASS == 'old': lt = .13 + .87 * diff + (tone - .5) * .26 * (mat == T_GRASS) + (n2 - .5) * .06
else: lt = .13 + .87 * diff + (tone - .5) * .10 * (mat == T_GRASS) + (n2 - .5) * .06 * (mat != T_GRASS)    # grass detail comes from grass_tex.py
strata = (np.floor(h / 3.1 + vn2(FU / 18, FV / 18, 5) * 2.5) % 2)
lt -= .07 * strata * (mat == T_ROCK)
lap = samp(LAP, FU, FV); lt -= np.clip(lap * .5, 0, .32); lt += np.clip(-lap * .25, 0, .12)
lt -= .22 * ((dp > pw - 1.4) & (dp < pw + .2) & (mat == T_PATH)) * (n2 > .45)        # ruts / worn edge
# water points
isw = wd > .04
mat = np.where(isw, T_WATER, mat)
pre_slope = np.hypot(samp(GUp, FU, FV), samp(GVp, FU, FV))
foam = isw & (pre_slope > .5) & (wh > LEVEL + .3)
mat = np.where(foam, T_FOAM, mat)
zt = np.where(isw, wh, h)
nrm[isw] = np.array([0, 0, 1.0])
aux = np.where(isw, wd, 0.0)
T = dict(u=FU, v=FV, z=zt, nx=nrm[:, 0], ny=nrm[:, 1], nz=nrm[:, 2], mat=mat, id=np.ones(len(FU), np.int32), aux=aux, wl=lt)
# ---------------- plinth (earth sides) ----------------
ths = np.linspace(-np.pi, np.pi, 4200, endpoint=False); ru = CU + Re(ths) * np.cos(ths); rv = CV + Re(ths) * np.sin(ths)
vis = (np.cos(ths) + np.sin(ths)) > .02
ths, ru, rv = ths[vis], ru[vis], rv[vis]
he = samp(H0, ru, rv); depth = 13 + 5 * vn2(ths * 3, ths * 0, 4)
ks = np.arange(0, 30, .4)
WU = (ru[:, None] + 0 * ks[None, :]).ravel(); WV = (rv[:, None] + 0 * ks[None, :]).ravel(); TH = (ths[:, None] + 0 * ks[None, :]).ravel()
WZ = (he[:, None] - ks[None, :]).ravel(); KS = (0 * he[:, None] + ks[None, :]).ravel(); DEP = (depth[:, None] + 0 * ks[None, :]).ravel()
keep = KS < DEP; WU, WV, TH, WZ, KS = WU[keep], WV[keep], TH[keep], WZ[keep], KS[keep]
lw = np.clip(np.cos(TH) * L[0] + np.sin(TH) * L[1], 0, 1) * .9 + .12 + (np.floor(KS / 2.6 + vn2(WU / 6, WV / 6, 2) * 1.6) % 2) * .13 + (vn2(WU * .8, WZ * .8, 6) - .5) * .35 - KS / 60
Wd = dict(u=WU, v=WV, z=WZ, nx=np.cos(TH), ny=np.sin(TH), nz=np.zeros(len(WU)), mat=np.full(len(WU), T_EARTH, np.int16), id=np.ones(len(WU), np.int32), aux=np.zeros(len(WU)), wl=lw)
log('terrain points %d, plinth %d' % (len(FU), len(WU)))

# ---------------- combine, shade, resolve ----------------
def cat(*ds):
    return {k: np.concatenate([np.asarray(d[k], np.float64 if k in ('u', 'v', 'z', 'nx', 'ny', 'nz', 'aux', 'wl') else np.int64) for d in ds]) for k in ds[0]}
Pp = dict(P); Pp['wl_light'] = None
allp = cat(T, Wd, P if len(P['u']) else T)
isprop = np.zeros(len(allp['u']), bool); isprop[len(T['u']) + len(Wd['u']):] = True
u_, v_, z_ = allp['u'], allp['v'], allp['z']
sx = np.round(OXS + (u_ - v_)).astype(int); sy = np.round(OYS + (u_ + v_) / 2 - z_).astype(int)
depthk = (u_ + v_) / 2 + z_
# cast shadows by marching toward the light through the height field
shadow = np.zeros(len(u_), bool)
for c0 in range(0, len(u_), 1500000):
    sl_ = slice(c0, c0 + 1500000); uu, vv, zz = u_[sl_], v_[sl_], z_[sl_]; s_ = np.zeros(len(uu), bool)
    for kk in np.arange(1.6, 78, 2.0 if not FAST else 3.0):
        iu_ = np.clip((uu + LXY[0] * kk).astype(int), 0, N - 1); iv_ = np.clip((vv + LXY[1] * kk).astype(int), 0, N - 1)
        s_ |= HS[iu_, iv_] > zz + kk * TANE + .7
    shadow[sl_] = s_
shadow[len(T['u']):len(T['u']) + len(Wd['u'])] = False
log('shadows done')
RAMP = {T_GRASS: [1, 2, 3, 3, 4], T_ROCK: [1, 2, 6, 6, 5], T_SAND: [6, 6, 5, 7], T_WET: [1, 6, 6, 5], T_PATH: [6, 5, 5, 7], T_FROST: [6, 5, 7, 7], T_EARTH: [1, 6, 6, 5],
        M_FOL: [1, 2, 3, 4], M_BARK: [1, 6, 6, 5], M_PINE: [1, 2, 2, 3], M_ROCK: [1, 2, 6, 5], M_MOSS: [2, 3, 4, 4], M_CRYS: [2, 3, 4, 7], M_WOOD: [1, 6, 5, 7],
        M_PETA: [3, 5, 5, 7], M_PETB: [2, 6, 6, 5], M_STEM: [1, 2, 3, 3], M_LILY: [1, 2, 3, 4], M_REED: [1, 2, 3, 3], M_CAT: [1, 6, 6, 5], M_BERRY: [1, 6, 6, 5],
        M_CAP: [1, 6, 6, 5], M_CSTEM: [6, 5, 7, 7], M_PAPER: [5, 7, 7, 7], M_GRASS: [2, 3, 3, 4], M_BARKT: [6, 5, 7, 7], M_BARKT2: [1, 6, 5, 7], M_INK: [0, 0, 1, 1], M_PAPER + 20: [5, 7, 7, 7]}
mat_ = allp['mat']; nz_ = allp['nz']; lraw = allp['wl'].copy()
light = np.where(isprop | (np.arange(len(u_)) >= len(T['u'])) & False, 0, 0).astype(float)
# lighting for props (terrain/plinth carried theirs in 'wl')
pi_ = isprop
dif = np.clip(allp['nx'] * L[0] + allp['ny'] * L[1] + allp['nz'] * L[2], 0, 1)
lp = .04 + 1.05 * dif
tex = vn3(u_ * .8, v_ * .8, z_ * .8, 3) - .5
lp += np.where(np.isin(mat_, [M_FOL, M_PINE, M_MOSS]), tex * .55 + (vn3(u_ * 2.2, v_ * 2.2, z_ * 2.2, 9) - .5) * .4, 0)
lp += np.where(np.isin(mat_, [M_ROCK]), tex * .5, 0) + np.where(mat_ == M_BARK, tex * .35, 0) + np.where(mat_ == M_FOL, (z_ - 20) * .012, 0)
lp += np.where(mat_ == M_CRYS, .10, 0) + np.where(mat_ == M_PAPER + 20, .5, 0) + np.where(mat_ == M_GRASS, (z_ - samp(H0, u_, v_)) * .035 - .05, 0)
lp += np.where(mat_ == M_LILY, .12, 0)
light = np.where(pi_, lp, lraw)
# rock: moss caps on upward faces
mossy = (mat_ == M_ROCK) & (nz_ > .62) & (vn3(u_ * .35, v_ * .35, z_ * .35, 12) > .38)
mat_ = np.where(mossy, M_MOSS, mat_)
BAKED_SHADOW = .2   # fraction of the old cast-shadow darkening kept; the runtime sun (world/sky_shadows.gd) draws the moving shadows
light = np.where(shadow, light * (1 - .45 * BAKED_SHADOW) - .03 * BAKED_SHADOW, light)
sd_water = shadow & (mat_ == T_WATER)
log('shaded')

def far_layer(pad, hor0, skyd, ranges, farh):
    """The far backdrop (sky and mountains) as its own image, `pad` texels wider than the scene each side, for the
    runtime parallax layer. Same maths as the surroundings block of render_scene, rows above the horizon only."""
    xs = np.arange(-pad, W + pad)
    Yf, Xf = np.mgrid[0:farh, -pad:W + pad]
    bayf = (BAYER[Yf & 3, Xf & 3] + .5) / 16
    def dithf(ramp, l):
        r = np.array(ramp); n = len(r) - 1; l = np.clip(l, 0, .9999); vv = l * n; lo = np.floor(vv).astype(int); f = np.clip((vv - lo - .30) / .40, 0, 1)
        hi = (f > bayf) & (lo < n); return r[np.where(hi, lo + 1, lo)]
    HORf = hor0 + 3 * np.sin(Xf * .05)
    res = dithf([0, 1, 1, 2], .15 + .75 * (Yf / float(skyd)) ** 1.2)
    for k, (base, amp, fr, ramp, sd) in enumerate(ranges):
        rid = 1 - np.abs(2 * fbm2(xs / float(fr) + k * 17, np.zeros(len(xs)), 4, sd) - 1)
        top_ = base - amp * rid ** 1.3 - 14
        below = Yf >= top_[None, :]
        slope_ = np.roll(top_, -2) - np.roll(top_, 2)
        lit = np.clip(.45 - slope_[None, :] * .09 + (vn2(Xf / 5.0, Yf / 4.0, sd + 3) - .5) * .35 + (Yf - top_[None, :]) * -.004, 0, .99)
        res = np.where(below & (Yf < HORf), dithf(ramp, lit), res)
    return res, HORf


def render_scene(keep):
    global mat_
    order_pix = sy * W + sx
    inb = (sx >= 0) & (sx < W) & (sy >= 0) & (sy < H) & keep
    idx_all = np.nonzero(inb)[0]
    op = order_pix[idx_all]; dk = depthk[idx_all]
    srt = np.lexsort((dk, op)); idx_s = idx_all[srt]; op_s = op[srt]
    last = np.r_[op_s[1:] != op_s[:-1], True]
    win = idx_s[last]
    px = sx[win]; py = sy[win]
    global LAST_WIN; LAST_WIN = (win, px, py)
    img_id = np.full((H, W), -1, np.int64); img_id[py, px] = allp['id'][win]
    img_mat = np.full((H, W), -1, np.int64); img_mat[py, px] = mat_[win]
    img_l = np.zeros((H, W)); img_l[py, px] = light[win]
    img_aux = np.zeros((H, W)); img_aux[py, px] = allp['aux'][win]
    img_sh = np.zeros((H, W), bool); img_sh[py, px] = shadow[win]
    img_z = np.zeros((H, W)); img_z[py, px] = z_[win]
    img_nu = np.zeros((H, W)); img_nu[py, px] = allp['nx'][win]
    img_nv = np.zeros((H, W)); img_nv[py, px] = allp['ny'][win]
    for _pass in range(2):          # close pin-holes left by steep surfaces (empty pixel with 3+ filled neighbours)
        emp = img_id == -1
        cnt = np.zeros((H, W), int); src = [None]
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nbm = np.roll(np.roll(img_id, dx, 1), dy, 0) != -1; cnt += nbm
        fillm = emp & (cnt >= 3)
        fillm[0, :] = fillm[-1, :] = False; fillm[:, 0] = fillm[:, -1] = False
        for arr in (img_id, img_mat, img_l, img_aux, img_sh, img_z, img_nu, img_nv):
            got = np.zeros_like(arr)
            done = np.zeros((H, W), bool)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nb_ = np.roll(np.roll(arr, dx, 1), dy, 0); nid = np.roll(np.roll(img_id, dx, 1), dy, 0)
                take = fillm & ~done & (nid != -1); got = np.where(take, nb_, got); done |= take
            arr[fillm] = got[fillm]
    # depth pass (tools/art/depth_pass.py), computed once from the full scene so ground and sprites agree
    global DEPTH
    if DEPTH is None:
        sun = np.array([LDIR[0] - LDIR[1], (LDIR[0] + LDIR[1]) / 2 - LDIR[2]]); sun /= np.linalg.norm(sun)
        DEPTH = depth_pass.compute(img_z, img_id, sun, np.isin(img_mat, [M_PETA, M_PETB, M_STEM, M_PAPER, M_GRASS])) + (img_id.copy(),)
    if DEPTH_ON:
        # where the full scene had a prop, only the prop's own render takes the terms (the ground beneath it is hidden)
        own = (DEPTH[3] < 10) | (img_id == DEPTH[3])
        img_l = img_l + np.where(own, -DEPTH[0] + DEPTH[1] + DEPTH[2], 0)
    YY, XX = np.mgrid[0:H, 0:W]
    bay = (BAYER[YY & 3, XX & 3] + .5) / 16
    def dith(ramp, l, mask):
        r = np.array(ramp); n = len(r) - 1; l = np.clip(l, 0, .9999); vv = l * n; lo = np.floor(vv).astype(int); f = np.clip((vv - lo - .30) / .40, 0, 1)
        hi = (f > bay) & (lo < n); return r[np.where(hi, lo + 1, lo)]
    img_l = grass_tex.apply(GRASS, img_l, img_mat == T_GRASS, XX, YY, dict(vn2=vn2, fbm2=fbm2))
    out = np.full((H, W), -1, np.int64)
    for m_, ramp in RAMP.items():
        sel_ = img_mat == m_
        if sel_.any(): out[sel_] = dith(ramp, img_l, sel_)[sel_]
    # water: depth bands, stepped glints, foam, white water on slopes
    wsel = img_mat == T_WATER
    if wsel.any():
        d_ = img_aux; band = np.clip(d_ / 5.5, 0, 1)
        lw_ = .78 - .62 * band ** .65 + (vn2(XX / 7.0, YY / 3.0, 31) - .5) * .30 - (img_sh * .22)
        wi = dith([1, 2, 2, 3, 3], lw_, wsel)
        wi = np.where((d_ < 1.0) & (((XX + YY) & 1) == 0) & (vn2(XX / 3, YY / 2, 7) > .5), 7, wi)             # foam fringe
        wi = np.where((d_ >= 1.0) & (d_ < 2.2) & (bay < .22), 4, wi)
        gl = (vn2(XX / 4.0, YY / 1.5, 40) > .88) & ((YY % 3) == 0) & (d_ > 1.6) & ~img_sh
        wi = np.where(gl, 4, wi); wi = np.where(gl & (vn2(XX / 2.0, YY / 1.0, 41) > .8), 7, wi)
        out[wsel] = wi[wsel]
    fsel = img_mat == T_FOAM
    if fsel.any():
        fl_ = .55 + (vn2(XX / 2.0, YY / 5.0, 50) - .5) * .9
        out[fsel] = dith([3, 4, 7, 7], fl_, fsel)[fsel]
    # outline: ink on object pixels next to a different object; ground next to empty
    ink = np.zeros((H, W), bool)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nb = np.full((H, W), -2, np.int64)
        ys0, ys1 = max(0, -dy), H - max(0, dy); xs0, xs1 = max(0, -dx), W - max(0, dx)
        nb[ys0:ys1, xs0:xs1] = img_id[ys0 + dy:ys1 + dy, xs0 + dx:xs1 + dx]
        me = img_id
        ink |= (me >= 10) & (nb != me)
        ink |= (me >= 1) & (nb == -1) & (me < 10)
        ink |= (me >= 10) & (nb == -2)
    out[ink & (img_id >= 0)] = 0
    # ---- surroundings: layered distant mountains and open water, so wide windows never see the void ----
    emp = out < 0
    if emp.any():
        HOR = 118 + 3 * np.sin(XX * .05)
        sky = dith([0, 1, 1, 2], .15 + .75 * (YY / 118.0) ** 1.2, emp)
        res = np.where(YY < HOR, sky, -1)
        for k, (base, amp, fr, ramp, sd) in enumerate(((122, 52, 70, [1, 2], 5), (126, 38, 48, [2, 2, 3], 6), (130, 24, 34, [2, 3, 3, 4], 7))):
            rid = 1 - np.abs(2 * fbm2(np.arange(W) / float(fr) + k * 17, np.zeros(W), 4, sd) - 1)
            top_ = base - amp * rid ** 1.3 - 14
            below = YY >= top_[None, :]
            slope_ = np.roll(top_, -2) - np.roll(top_, 2)
            lit = np.clip(.45 - slope_[None, :] * .09 + (vn2(XX / 5.0, YY / 4.0, sd + 3) - .5) * .35 + (YY - top_[None, :]) * -.004, 0, .99)
            mt = dith(ramp, lit, emp)
            res = np.where(below & (YY < HOR + 6), mt, res)
        wt = np.clip(.52 - (YY - HOR) / 520.0 + (vn2(XX / 9.0, YY / 2.5, 60) - .5) * .30, 0, .99)
        wat = dith([1, 2, 2, 3], wt, emp)
        wat = np.where((wat <= 2) & (YY % 4 == 0) & (vn2(XX / 3.0, YY / 1.0, 61) > .86), 3, wat)
        wat = np.where((vn2(XX / 3.0, YY / 1.2, 62) > .93) & (YY % 3 == 0), 4, wat)
        res = np.where(YY >= HOR, wat, res)
        global FAR_CUT; FAR_CUT = emp & (YY < HOR)   # texels the runtime far layer draws (sky and mountains)
        out[emp] = res[emp]
    rgb = np.zeros((H, W, 3), np.uint8); rgb[:] = COLS[0]
    have = out >= 0; rgb[have] = COLS[out[have]]

    global LAST_AUX; LAST_AUX = dict(nu=img_nu, nv=img_nv, l=img_l, mat=img_mat, out=out, z=img_z)
    return rgb, img_id
tall_ids = np.array([t['id'] for t in TALL])
rgb_full, id_full = render_scene(np.ones(len(u_), bool))
AUX_FULL = LAST_AUX
rgb_gnd, id_gnd = render_scene(~np.isin(allp['id'], tall_ids))
AUX_GND = LAST_AUX
im = Image.fromarray(rgb_full); Image.fromarray(rgb_gnd).save(os.path.join(OUT, 'ground.png'))
# parallax layers: the far backdrop on its own (wider than the scene), and the ground with those texels cut to transparent
_FARPAD = 64
_far_idx, _ = far_layer(_FARPAD, 118, 118, ((122, 52, 70, [1, 2], 5), (126, 38, 48, [2, 2, 3], 6), (130, 24, 34, [2, 3, 3, 4], 7)), 128)
_far_rgb = COLS[_far_idx].astype(np.uint8)
Image.fromarray(_far_rgb).save(os.path.join(OUT, 'backdrop_far.png'))
_fg = np.dstack([rgb_gnd, np.full(rgb_gnd.shape[:2], 255, np.uint8)])
_fg[FAR_CUT, 3] = 0
Image.fromarray(_fg).save(os.path.join(OUT, 'ground_fg.png'))

# ground G-buffer (same contract as gen_meadow3d.py): normal + material + baked light, and world height
depth_pass.write_relight_data(os.path.join(OUT, 'ground_n.png'), AUX_GND, 0, H - 1, 0, W - 1, id_gnd >= 0)
depth_pass.write_height(os.path.join(OUT, 'ground_h.png'), AUX_GND['z'], id_gnd >= 0)
os.makedirs(os.path.join(OUT, 'sprites'), exist_ok=True); sprites = []
for t in TALL:
    ys_, xs_ = np.nonzero(id_full == t['id'])
    if len(xs_) < 12: continue
    x0, x1, y0, y1 = xs_.min(), xs_.max(), ys_.min(), ys_.max()
    spr = np.zeros((y1 - y0 + 1, x1 - x0 + 1, 4), np.uint8)
    m_ = id_full[y0:y1 + 1, x0:x1 + 1] == t['id']
    spr[m_, :3] = rgb_full[y0:y1 + 1, x0:x1 + 1][m_]; spr[m_, 3] = 255
    fn = 'sprites/%s_%03d.png' % (t['kind'], t['id']); Image.fromarray(spr).save(os.path.join(OUT, fn))
    depth_pass.write_relight_data(os.path.join(OUT, fn[:-4] + '_n.png'), AUX_FULL, y0, y1, x0, x1, m_)
    fx, fy = OXS0 + (t['u'] - t['v']), OYS0 + (t['u'] + t['v']) / 2 - t['z']
    sprites.append(dict(file=fn, nrm=fn[:-4] + '_n.png', kind=t['kind'], x=int(x0) - BLX, y=int(y0) - BLY, w=int(x1 - x0 + 1), h=int(y1 - y0 + 1), foot=[round(float(fx), 1), round(float(fy), 1)], sort_y=round(float(fy), 1)))

# ---------------- walkable mask (terrain-only pass; tall props / rocks / bushes block by footprint) ----------------
nT = len(T['u']); BLOCK_R = dict(oak=4.0, pine=3.5, crystals=9.0, crystal=9.0, rock=8.0, bush=5.5, stump=3.0, windmill=10.0, tower=9.5, lighthouse=9.5, obelisk=5.5, gateway=0.0, menhir=3.2, lantern=1.6, sign=2.0)
wk = (wd <= .04) & (DW[np.clip(FU.astype(int), 0, N - 1), np.clip(FV.astype(int), 0, N - 1)] >= 1.4) & (slope < .75) & (h < 14) & (mat != T_FROST) & (mat != T_ROCK)
for t in TALL:
    r_ = BLOCK_R.get(t['kind'], 4.0)
    wk &= np.hypot(FU - t['u'], FV - t['v']) > r_
_dn = ((FU - bu) + (FV - bv)) / 1.414; _dc = ((FU - bu) - (FV - bv)) / 1.414
wk |= (np.abs(_dn) < 15) & (np.abs(_dc) < 3.2)      # the footbridge is walkable over the stream
keep_t = np.zeros(len(u_), bool); keep_t[:nT] = True
render_scene(keep_t)
_win, _px, _py = LAST_WIN
wimg = np.full((H, W), -1, np.int8); tm = _win < nT
wimg[_py[tm], _px[tm]] = wk[_win[tm]].astype(np.int8)
for _ in range(3):
    unk = wimg == -1; vals = []
    nsum = np.zeros((H, W), int); ncnt = np.zeros((H, W), int)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            r_ = np.roll(np.roll(wimg, dx, 1), dy, 0); ncnt += (r_ >= 0); nsum += (r_ == 1)
    fill = unk & (ncnt >= 3); wimg[fill] = (nsum[fill] * 2 > ncnt[fill]).astype(np.int8)
wimg[wimg < 0] = 0
# connected component from the spawn
sp = [a for a in anchors if a['kind'] == 'player_spawn'][0]
def _near(x, y):
    x = int(round(x)) + BLX; y = int(round(y)) + BLY
    for r_ in range(0, 40):
        ys0, ys1, xs0, xs1 = max(0, y - r_), min(H, y + r_ + 1), max(0, x - r_), min(W, x + r_ + 1)
        sub = wimg[ys0:ys1, xs0:xs1]
        if sub.any():
            yy, xx = np.nonzero(sub); i = np.argmin((yy + ys0 - y) ** 2 + (xx + xs0 - x) ** 2); return int(xx[i] + xs0), int(yy[i] + ys0)
    return None
st = _near(sp['sx'], sp['sy']); comp = np.zeros((H, W), bool)
from collections import deque
dq = deque([st]); comp[st[1], st[0]] = True
while dq:
    cx, cy = dq.popleft()
    for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nx_, ny_ = cx + ddx, cy + ddy
        if 0 <= nx_ < W and 0 <= ny_ < H and wimg[ny_, nx_] and not comp[ny_, nx_]: comp[ny_, nx_] = True; dq.append((nx_, ny_))
for _a in anchors:
    if _a['kind'] in ('pad', 'gate'):
        q = _near(_a['sx'], _a['sy']); log('walk reach %s %s: %s' % (_a['kind'], (_a['sx'], _a['sy']), bool(q and comp[q[1], q[0]])))
wm = np.zeros((H, W, 4), np.uint8); wm[..., 3] = 255; wm[comp, :3] = 255
Image.fromarray(wm).save(os.path.join(OUT, 'walkable.png')); log('walkable fraction %.3f' % comp.mean())
im.save(os.path.join(OUT, 'preview_full.png'))
for _name, _sm in (('lake', LAKE_S), ('pond', POND_S)):
    _m = (WD > .04) & (_sm < 1.25)
    _iu, _iv = np.nonzero(_m)
    _sx = OXS0 + (_iu - _iv); _sy = OYS0 + (_iu + _iv) / 2.0 - LEVEL
    anchors.append(dict(kind='water', name=_name, sx=round(float((_sx.min() + _sx.max()) / 2), 1), sy=round(float((_sy.min() + _sy.max()) / 2), 1),
                        rx=round(float((_sx.max() - _sx.min()) / 2), 1), ry=round(float((_sy.max() - _sy.min()) / 2), 1), u=float(_iu.mean()), v=float(_iv.mean())))
for _a in anchors:        # ground contact = screen position at the terrain height there
    if _a['kind'] != 'water': _a['sy'] = round(OYS0 + (_a['u'] + _a['v']) / 2.0 - float(terrain_h(_a['u'], _a['v'])), 1)
anchors_out = [dict(a, u=round(a['u'], 1), v=round(a['v'], 1)) for a in anchors]
json.dump(dict(size=[W, H], world=[LAY.PLAY[0], LAY.PLAY[1], LAY.PLAY[2] - LAY.PLAY[0], LAY.PLAY[3] - LAY.PLAY[1]], projection=dict(ox=OXS0, oy=OYS0, note='screen = (ox + u - v, oy + (u+v)/2 - h), in the 640x360 frame'), bleed=dict(left=BLX, right=BLX, top=BLY, bottom=BLY, ground_size=[W, H], ground_offset=[-BLX, -BLY], note='ground.png is 840x480; place it at (-100,-60) so the 640x360 frame lines up with the old origin. All anchors and sprite x/y/foot stay in 640x360-frame coordinates (sprite x/y may be negative).'), anchors=anchors_out, sprites=sprites), open(os.path.join(OUT, 'placements3d.json'), 'w'), indent=1)
log('done')
