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
_DEAD = LAY.dead_ends()
assert not _DEAD, 'paths lead nowhere (path index, end): %r' % (_DEAD,)   # every path must reach a gate, pad, landmark or path
_ON_PATH = LAY.pads_on_path()
assert not _ON_PATH, 'pads sit on or against a path (move them in larkmoor_layout.PAD_NUDGE): %r' % (_ON_PATH,)
_OFF = LAY.rows_off()
assert not _OFF, 'pad rows must hug a path and not overlap (tools/art/plan_rows.py): %r' % (_OFF,)
import depth_pass, grass_tex
GRASS = os.environ.get('GRASS', 'g')    # grass texture style (tools/art/grass_tex.py): g = clump blades on patch shading (M2); 'old' = previous noise patches
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
# Prop palette (Gower-style restyle, v3 mockup B): the sprites' albedo and the relit props' ramps. Ink stays put, and the
# ground keeps PAL, so the backdrop, the flower and sway checks and the UI palette are unchanged.
PROP_PAL = ['#14161c', '#1c3a2e', '#2f6a42', '#4f8f4a', '#9cc85c', '#e6ec9a', '#8a5a38', '#f2ecd2']
PROP_COLS = np.array([[int(h[k:k + 2], 16) for k in (1, 3, 5)] for h in PROP_PAL], np.uint8)
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
# path hierarchy: each tier has its own half-width (texels) and its own material. dtier[t] is the distance to the nearest
# path of that tier; dedge is the distance to the nearest path EDGE (negative on a path), used for decor clearance.
HALF = dict(road=12.0, lane=7.5, trail=4.0)
dtier = {t: np.minimum.reduce([pl_dist(gu, gv, pp) for pp, tr in zip(PATHS_UV, LAY.PATH_TIER) if tr == t]) for t in HALF}
dedge = np.minimum.reduce([dtier[t] - HALF[t] for t in HALF])
# the lighthouse grove trail (the last path, a trail) runs through a canopy, so it gets its own open corridor: no tree crown,
# flower or tuft may come within GROVE_CLEAR of its line (or of the plaza at the lighthouse foot). dgrove is that distance,
# and the plaza is a small widened disc of earth at the foot (FOOT_R), so the walker can stop there.
assert LAY.PATH_TIER[-1] == 'trail'
GROVE_UV = PATHS_UV[len(LAY.PATHS) - 1]
LH_UV = s2uv(*[lm['at'] for lm in LAY.LANDMARKS if lm['id'] == 'lighthouse'][0])
FOOT_R = 7.0
GROVE_CLEAR = 12.0
dgrove = np.minimum(pl_dist(gu, gv, GROVE_UV), np.hypot(gu - LH_UV[0], gv - LH_UV[1]) - FOOT_R + HALF['trail'])
dgate = np.minimum(np.hypot(gu - GATE[0], gv - GATE[1]), np.hypot(gu - GATE2[0], gv - GATE2[1]))
log('terrain fields')
thb = math.atan2(-1, -1)
a = np.abs((th - thb + np.pi) % (2 * np.pi) - np.pi)
env_ang = .36 + .64 * (1 - smooth(1.15, 2.7, a))
# the south and west rim rises as well (it sat at the 0.36 factor): the island reads as a valley ringed by mountains, not a cut-out
a_sw = np.abs((th - math.radians(85.0) + np.pi) % (2 * np.pi) - np.pi)
env_ang = np.maximum(env_ang, .8 * (1 - smooth(.9, 1.7, a_sw)))
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
RIVER_DEPTH = 3.0                              # the river bed sits this far below its surface: deep enough to read as water, not a dither strip
sw = 7.0 + 1.0 * np.sin(gu * .13 + gv * .09)   # half-width: about 14 texels across, still an easy jump
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
# the channel is carved all the way to the lake: inside the lake the bowl is already deeper, so nothing changes there, and the rim
# gets a notch where the river leaves it (the old lake-rim exclusion left a dry gap between the lake and the river)
wch = (1 - smooth(sw - 2.0, sw + 4.5, dstr))
H0 = H0 * (1 - wch) + np.minimum(H0, HLF - RIVER_DEPTH) * wch       # bed always sits below the water ribbon
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
M_DARKF = 34   # dark pocket cut into a bush: the shadowed inside of the leaf shell, darkest ramp step (same code as gen_meadow3d.py)

# ---------------- prop models (local coords: x right, y toward camera, z up) ----------------
def make_oak(rng):
    lx, ly = rng.uniform(-1.5, 1.5), rng.uniform(-1.5, 1.5)
    # round 3: eight lobes instead of six, so the crown has more clumps and a rounder, bumpier outline (v3 canopy shape)
    balls = [(0, 0, 27, 9.5)] + [(rng.uniform(-10, 10), rng.uniform(-10, 10), rng.uniform(21, 33), rng.uniform(6.0, 8.5)) for _ in range(8)]
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
    seed = rng.randint(0, 99)
    # seen from above, a bush is a low mound: squashed leaf lobes make the body, smaller crowns ride its top so the upper
    # surface reads as clumped leaves, and a flat skirt sits on the ground so the foot is wider than the crown
    lobes = [(rng.uniform(-4, 4), rng.uniform(-4, 4), rng.uniform(3.0, 4.2), rng.uniform(4.4, 5.8)) for _ in range(4)]
    crowns = [(rng.uniform(-3.5, 3.5), rng.uniform(-3.5, 3.5), rng.uniform(6.2, 7.2), rng.uniform(2.6, 3.4)) for _ in range(3)]
    berries = [(rng.uniform(-6, 6), rng.uniform(-6, 6), rng.uniform(3, 8)) for _ in range(7)] if rng.random() < .6 else []
    # dark pockets: small holes cut into the upper leaf shell, so the shadowed inside of the bush shows through as
    # dark clusters. Own rng, so the placement sequence of every other prop is unchanged.
    frng = random.Random(seed * 131 + 7)
    pockets = []
    for _ in range(frng.randint(4, 6)):
        b = lobes[frng.randrange(len(lobes))]
        a_ = frng.uniform(0, 6.28); e_ = frng.uniform(.2, .9)        # elevation: the upper, visible part of the lobe
        rr = b[3] * frng.uniform(.7, .95); ce = math.cos(e_)
        pockets.append(((b[0] + math.cos(a_) * ce * rr, b[1] + math.sin(a_) * ce * rr, b[2] + math.sin(e_) * rr), frng.uniform(1.8, 2.8)))
    def f(x, y, z):
        d = np.full(x.shape, 99.0, np.float32)
        for b in lobes: d = np.minimum(d, sdf_ell(x, y, z, b[:3], (b[3], b[3], b[3] * .8)))
        for b in crowns: d = np.minimum(d, sdf_ell(x, y, z, b[:3], (b[3], b[3], b[3] * .75)))
        d = np.minimum(d, sdf_ell(x, y, z, (0, 0, .2), (6.6, 5.9, 2.2)))
        d = d + 1.4 * (vn3(x * .45, y * .45, z * .45, seed) - .5); m = np.full(x.shape, M_FOL, np.int16)
        for pc, pr in pockets:
            cut = -sdf_sphere(x, y, z, pc, pr)
            m = np.where(cut > d, M_DARKF, m); d = np.maximum(d, cut)
        # contact: a thin, soft-edged dark slab under the bush, a little wider than its skirt, so the foot reads as shade on the ground
        dc = sdf_ell(x, y, z, (0, 0, 0), (7.4, 6.6, .6)) + .9 * (vn2(x * .7, y * .7, seed + 9) - .5)
        sel = dc < d; m = np.where(sel, M_DARKF, m); d = np.minimum(d, dc)
        for b in berries:
            db = sdf_sphere(x, y, z, b, 1.0) ; sel = db < d; m = np.where(sel, M_BERRY, m); d = np.minimum(d, db)
        return d, m
    return f, (11, 11), 13, 6.5
def make_rock(rng, big=True):
    seed = rng.randint(0, 99); rx, ry, rz = (rng.uniform(6.5, 9), rng.uniform(5.5, 8), rng.uniform(4.5, 7)) if big else (rng.uniform(3, 4.5), rng.uniform(2.5, 4), rng.uniform(2, 3))
    # a stone seen from above has a broad top face. A tilted plane shaves the crown flat, so the top reads as one lit
    # face with a bevelled rim where it meets the sides. One or two low side facets keep the stone faceted. Own rng, so
    # the placement sequence of every other prop is unchanged.
    frng = random.Random(seed * 7919 + 17)
    ta, tb = frng.uniform(.03, .14), frng.uniform(0, 6.283)           # how far the top leans, and which way
    top_n = (math.sin(ta) * math.cos(tb), math.sin(ta) * math.sin(tb), math.cos(ta))
    top_off = rz * frng.uniform(.62, .74)                              # cut height above the centre: a broad face, not a point
    facets = []
    for _ in range(frng.randint(1, 3)):
        a_ = frng.uniform(0, 6.283); e_ = frng.uniform(0.0, 0.3)       # elevation: 0 = upright side face
        facets.append((math.cos(a_) * math.cos(e_), math.sin(a_) * math.cos(e_), math.sin(e_), min(rx, ry, rz) * frng.uniform(.92, 1.1)))
    def f(x, y, z):
        d = sdf_ell(x, y, z, (0, 0, rz * .55), (rx, ry, rz))
        d = d + (1.6 if big else .8) * (vn3(x * .26, y * .26, z * .26, seed) - .5) * 2 + .6 * (vn3(x * .7, y * .7, z * .7, seed + 5) - .5)
        zc = z - rz * .55
        d = np.maximum(d, top_n[0] * x + top_n[1] * y + top_n[2] * zc - top_off)
        for (nx_, ny_, nz_, off) in facets:
            d = np.maximum(d, nx_ * x + ny_ * y + nz_ * zc - off)
        # contact: a thin, soft-edged dark slab at the foot, a little wider than the stone, so the base reads as shade on the ground
        dc = sdf_ell(x, y, z, (0, 0, 0), (rx + 1.4, ry + 1.2, .6)) + .9 * (vn2(x * .7, y * .7, seed + 9) - .5)
        m = np.where(dc < d, M_DARKF, M_ROCK).astype(np.int16)
        return np.minimum(d, dc), m
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
    """A garden lantern in the 19 by 29 window (LANTERN_WIN): a stone foot, a timber post, a lamp box whose window is the
    lit part (paper, lifted in the shade so it reads at night), four dark corner posts, a pitched cap and a finial.
    The lit window sits at about 17 texels above the foot, where the glow sprite and the lamp's light are placed."""
    def f(x, y, z):
        # the foot is kept within 1.9 texels of the centre: its front corner must stay inside the window's 2 below the foot
        d = sdf_box(x, y, z, (0, 0, 0.9), (1.9, 1.9, 0.9), .25); m = np.full(x.shape, M_ROCK, np.int16)
        dp = sdf_capsule(x, y, z, (0, 0, 1.6), (0, 0, 13.4), .55); sel = dp < d; m = np.where(sel, M_BARK, m); d = np.minimum(d, dp)
        dl = sdf_box(x, y, z, (0, 0, 16.2), (1.7, 1.7, 2.8), .2); sel = dl < d; m = np.where(sel, M_PAPER + 20, m); d = np.minimum(d, dl)
        for px, py in ((-2.1, -2.1), (2.1, -2.1), (-2.1, 2.1), (2.1, 2.1)):
            dc = sdf_capsule(x, y, z, (px, py, 13.4), (px, py, 19.0), .4); sel = dc < d; m = np.where(sel, M_INK, m); d = np.minimum(d, dc)
        roof = np.maximum(np.abs(x) + np.abs(y) - (4.6 - (z - 19.2) * 1.2), np.maximum(19.0 - z, z - 23.2))   # a hipped cap that overhangs the lamp
        sel = roof < d; m = np.where(sel, M_BARKT, m); d = np.minimum(d, roof)
        fin = sdf_capsule(x, y, z, (0, 0, 23.0), (0, 0, 24.3), .45); sel = fin < d; m = np.where(sel, M_INK, m); d = np.minimum(d, fin)
        return d, m
    return f, (7, 7), 26, 2.5
def make_windmill(rng):
    def f(x, y, z):
        r = 9.5 - z * .12
        d = np.sqrt(x ** 2 + y ** 2) - r; d = np.maximum(d, -z); d = np.maximum(d, z - 34); m = np.full(x.shape, M_PAPER, np.int16)
        door = sdf_box(x, y + 8.5, z, (0, 0, 4.2), (2.4, 1.6, 4.2), .3); sel = door < d + 1.2; m = np.where(sel, M_BARK, m); d = np.where(sel, np.maximum(d, -door + .4) * 0 + np.minimum(d, door + 1.2) * 0 + d, d)
        band = (np.abs(z - 16) < 1.2); m = np.where(band & (d < 1.5), M_BARKT, m)
        roof = np.maximum(np.sqrt(x ** 2 + y ** 2) - (7.2 - (z - 32) * .85), np.abs(z - 36.0) - 4.4)
        sel = roof < d; m = np.where(sel, M_BARKT2, m); d = np.minimum(d, roof)
        return d, m
    return f, (12, 12), 42, 11   # the tower only: the sails are their own sprite (make_windmill_sails)
def make_windmill_sails(rng):
    """The sails, arms and hub of the windmill as their own sprite. Its grid origin is the hub, so the sprite's foot is the
    hub and the scene turns the sprite around that point. The shape is the same as the mill's own sails."""
    def f(x, y, z):
        x, y, z = x, y + 10.4, z + 35.0                     # back to the mill's frame, where the hub is at (0, 10.4, 35)
        d = np.full(x.shape, 1e3, np.float32); m = np.full(x.shape, M_WOOD, np.int16)
        for k in range(4):
            ang = .62 + k * 1.5708; ex, ez = math.cos(ang) * 27, math.sin(ang) * 27
            arm = sdf_capsule(x, y, z, (0, 10.4, 35), (ex, 10.4, 35 + ez), .75); sel = arm < d; m = np.where(sel, M_WOOD, m); d = np.minimum(d, arm)
            sail = sdf_capsule(x, y, z, (ex * .35 - math.sin(ang) * 2.6, 10.6, 35 + ez * .35 + math.cos(ang) * 2.6), (ex * .95 - math.sin(ang) * 2.6, 10.6, 35 + ez * .95 + math.cos(ang) * 2.6), 2.4, 3.0)
            sel = sail < d; m = np.where(sel, M_PAPER + 20, m); d = np.minimum(d, sail)
        hub = sdf_sphere(x, y, z, (0, 10.4, 35), 1.8); sel = hub < d; m = np.where(sel, M_BARK, m); d = np.minimum(d, hub)
        return d, m
    return f, (29, 6), 30, 3   # the grid spans -30..30 in z around the hub (see put's bottom)
def make_gateway(rng, style='timber'):
    """The two Larkmoor gateways. 'timber': the arrival arch from the meadow, timber posts with a flower-garlanded lintel.
    'stone': the Ember gate, rough stone posts and lintel with ember bloom in the seams, leading on to the quarry."""
    stone = style == 'stone'
    post_m, cap_m, lint_m = (M_ROCK, M_ROCK, M_ROCK) if stone else (M_BARKT, M_PAPER, M_BARK)
    def f(x, y, z):
        d = np.full(x.shape, 1e3); m = np.full(x.shape, post_m, np.int16)
        for px in (-9.5, 9.5):
            dp = sdf_box(x, y, z, (px, 0, 9.5), (2.7, 2.4, 9.5), .7) + (vn3(x * .5, y * .5, z * .5, 4) - .5) * 1.0; sel = dp < d; m = np.where(sel, post_m, m); d = np.minimum(d, dp)
            dc = sdf_box(x, y, z, (px, 0, 19.6), (3.4, 3.1, .9), .4); sel = dc < d; m = np.where(sel, cap_m, m); d = np.minimum(d, dc)
            dl = sdf_box(x, y, z, (px, 0, 22.3), (1.2, 1.2, 1.6), .4); sel = dl < d; m = np.where(sel, M_PAPER + 20, m); d = np.minimum(d, dl)
        db = sdf_box(x, y, z, (0, 0, 17.8), (11.5, 1.8, 1.5), .5); sel = db < d; m = np.where(sel, lint_m, m); d = np.minimum(d, db)
        if stone:
            for ex in np.linspace(-9.0, 9.0, 5):                  # ember bloom sitting in the lintel seams
                de = sdf_sphere(x, y, z, (ex, 0, 19.4), 1.1); sel = de < d; m = np.where(sel, M_BERRY, m); d = np.minimum(d, de)
        else:
            for ex in np.linspace(-9.0, 9.0, 7):                  # flower garland along the lintel
                dfl = sdf_sphere(x, y, z, (ex, 0, 19.6), 1.0); sel = dfl < d; m = np.where(sel, M_PETA if int(ex) % 2 else M_PETB, m); d = np.minimum(d, dfl)
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
# ---------------- ruins: overgrown stone that replaces Larkmoor's tall towers ----------------
# Nathan asked for the tall lighthouse-like towers to go. Each ruin keeps its tower's place and footprint, but its top is broken
# and its stone is cut down, moss caps it (the rock rule above), and fallen stone lies around the foot. Three shapes, picked
# per option (RUIN_PLAN below): 'tower' a broken round stump, 'arch' two piers and a broken arc, 'wall' a broken curtain wall
# with a stub column. Materials are the zone palette: rock for the stone, light dressed stone for the cornice and the column,
# leaf green for ivy on the upper walls.
def _ruin_stone(x, y, z, seed):
    """Ruin stone: pale dressed stone, mottled with grey rock, so the walls read against the grass."""
    return np.where(vn3(x * .45, y * .45, z * .45, seed + 21) > .45, M_BARKT, M_ROCK).astype(np.int16)
def _ruin_union(parts):
    def f(x, y, z):
        d, m = parts[0](x, y, z)
        for pf in parts[1:]:
            dp, mp = pf(x, y, z); sel = dp < d; m = np.where(sel, mp, m); d = np.minimum(d, dp)
        return d, m
    return f
def _ruin_stump(seed, cx, cy, r0, h):
    """A round tower cut off at a slant, with a broken-out notch and a small door on its front (toward the camera)."""
    def f(x, y, z):
        X, Y = x - cx, y - cy
        rr = r0 - z * .03
        d = np.sqrt(X ** 2 + Y ** 2) - rr + (vn3(x * .35, y * .35, z * .35, seed) - .5) * 1.5
        d = np.maximum(d, -z)                                                     # stands on the ground
        d = np.maximum(d, (z - h) + (X * .42 - Y * .3) + (vn3(x * .6, y * .6, 0.5, seed + 1) - .5) * 3.0)   # the broken top
        d = np.maximum(d, -sdf_box(X - rr * .55, Y - rr * .35, z, (0, 0, h), (4.0, 4.0, 5.0), .8))         # a notch knocked out of the crown
        d = np.maximum(d, -sdf_box(X, Y - rr, z, (0, 0, 4.0), (2.0, 2.2, 4.0), .3))                       # the door
        m = _ruin_stone(x, y, z, seed)
        m = np.where((np.abs(z - h * .6) < 1.0) & (d < .9), M_BARKT, m)                                  # dressed cornice band
        m = np.where((z > h * .7) & (vn3(x * .5, y * .5, z * .5, seed + 9) > .82) & (d < .4), M_FOL, m)    # a little ivy high on the wall
        return d, m
    return f
def _ruin_piers(seed, span, zc):
    """Two stone piers that stand up to the springing line zc, at x = -span and +span."""
    def f(x, y, z):
        d = np.full(x.shape, 1e3, np.float32); m = np.full(x.shape, M_BARKT, np.int16)
        for px in (-span, span):
            dp = sdf_box(x, y, z, (px, 0, zc / 2), (2.9, 2.9, zc / 2), .6) + (vn3(x * .4, y * .4, z * .4, seed) - .5) * 1.0
            sel = dp < d; m = np.where(sel, _ruin_stone(x, y, z, seed), m); d = np.minimum(d, dp)
        return d, m
    return f
def _ruin_arc(seed, span, zc, rise):
    """The arch between the piers: a thick ring segment above zc, broken away on the right so the top is missing."""
    def f(x, y, z):
        arc = np.maximum(np.abs(np.sqrt(x ** 2 + (z - zc) ** 2) - span) - 2.2, np.abs(y) - 2.6)
        arc = np.maximum(arc, zc - z)                                             # only above the springing line
        broke = (x > span * .2) & (z > zc + rise * (.55 + (vn3(x * .5, y * .5, z * .5, seed) - .5) * .5))
        arc = np.where(broke, 1e3, arc)
        m = np.where((np.abs(np.sqrt(x ** 2 + (z - zc) ** 2) - span) < 1.2) & (arc < .8), M_BARKT, _ruin_stone(x, y, z, seed)).astype(np.int16)
        return arc, m
    return f
def _ruin_pillar(seed, cx, cy, rr, h):
    """A stub of a dressed column, broken off at a slant."""
    def f(x, y, z):
        d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) - rr + (vn3(x * .5, y * .5, z * .5, seed) - .5) * .8
        d = np.maximum(d, -z)
        d = np.maximum(d, (z - h) + (x - cx) * .5 + (vn3(x * .7, y * .7, 0.4, seed + 2) - .5) * 2.5)
        return d, np.full(x.shape, M_BARKT, np.int16)
    return f
def _ruin_fallen(seed, cx, cy, length, rr, ang):
    """A broken column lying on the ground, along the angle ang (radians)."""
    ax, ay = cx - math.cos(ang) * length / 2, cy - math.sin(ang) * length / 2
    bx, by = cx + math.cos(ang) * length / 2, cy + math.sin(ang) * length / 2
    def f(x, y, z):
        d = sdf_capsule(x, y, z, (ax, ay, rr * .9), (bx, by, rr * .9), rr) + (vn3(x * .6, y * .6, z * .6, seed) - .5) * .7
        return d, np.full(x.shape, M_BARKT, np.int16)
    return f
def _ruin_wall(seed, cx, cy, R, a0, a1, h):
    """A curtain wall on an arc of radius R, from angle a0 to a1, with a jagged broken top and open ends."""
    def f(x, y, z):
        X, Y = x - cx, y - cy
        ang = np.arctan2(Y, X)
        d = np.abs(np.sqrt(X ** 2 + Y ** 2) - R) - 1.9 + (vn3(x * .4, y * .4, z * .4, seed) - .5) * 1.0
        d = np.maximum(d, -z)
        d = np.maximum(d, z - h - (vn3(X * .5, Y * .5, 0.7, seed + 4) - .5) * 6.0)
        d = np.where((ang >= a0) & (ang <= a1), d, 1e3)
        m = np.where((z > h * .7) & (vn3(x * .5, y * .5, z * .5, seed + 9) > .82), M_FOL, _ruin_stone(x, y, z, seed)).astype(np.int16)
        return d, m
    return f
def _ruin_blob(rng_seed, cx, cy, rr):
    """A fallen stone, half sunk into the ground."""
    def f(x, y, z):
        d = sdf_ell(x, y, z, (cx, cy, rr * .45), (rr, rr * .85, rr * .6)) + (vn3(x * .5, y * .5, z * .5, rng_seed) - .5) * 1.2
        return d, np.full(x.shape, M_ROCK, np.int16)
    return f
def _ruin_rubble(rng, n, spread, rmax):
    """n fallen stones scattered round the foot, denser close in."""
    out = []
    for _ in range(n):
        a = rng.uniform(0, 6.283); rd = spread * math.sqrt(rng.random())
        out.append(_ruin_blob(rng.randint(0, 99), math.cos(a) * rd, math.sin(a) * rd, rng.uniform(1.6, rmax)))
    return out
RUIN_STYLES = ('tower', 'arch', 'wall')
# The ruin picked per landmark id: (style, height, turn in radians). Gatehouse and Emberwatch get the broken arch, and the
# lighthouse grove gets the broken curtain wall (Nathan picked B and C, mixed, on flat ground).
RUIN_PLAN = {'gatehouse_tower': ('arch', 26.0, -.785), 'lighthouse': ('wall', 20.0, 0.0), 'ember_watchtower': ('arch', 24.0, 0.0)}
def make_ruin(rng, style='tower', h=24.0):
    """One ruin sprite. Everything stands inside 12 texels of its foot, which is the walk block (BLOCK_R 'ruin'), so the walker's
    front stop never lands inside the stone."""
    seed = rng.randint(0, 99)
    if style == 'tower':
        parts = [_ruin_stump(seed, 0.0, 0.0, 8.5, h), _ruin_fallen(seed + 1, 9.0, -5.0, 10.0, 2.4, -.5)] + _ruin_rubble(rng, 5, 8.5, 2.6)
    elif style == 'arch':
        span = 7.5
        parts = [_ruin_piers(seed, span, h), _ruin_arc(seed + 2, span, h * .62, h * .38), _ruin_fallen(seed + 3, 2.0, -10.0, 13.0, 2.2, .2)] + _ruin_rubble(rng, 4, 8.5, 2.6)
    elif style == 'wall':
        parts = [_ruin_wall(seed, 0.0, 0.0, 10.0, -2.6, 1.9, h), _ruin_pillar(seed + 5, -6.5, 6.0, 2.8, h * 1.5),
                 _ruin_fallen(seed + 6, 4.0, 8.5, 8.0, 2.2, .9)] + _ruin_rubble(rng, 6, 8.5, 2.6)
    else:
        raise ValueError('unknown ruin style %r' % (style,))
    return _ruin_union(parts), (15, 15), h + 8, 10
def make_menhir(rng, fixed=False):
    """A standing stone. fixed=True gives the ring's stones one height and no tilt, so the ring reads as built, not scattered."""
    h = 11.0 if fixed else rng.uniform(9, 14); tilt = 0.0 if fixed else rng.uniform(-.12, .12)
    def f(x, y, z):
        d = sdf_box(x + tilt * z, y, z, (0, 0, h / 2), (2.1, 1.7, h / 2), .9); d = d + (vn3(x * .5, y * .5, z * .5, 3) - .5) * 1.2
        return d, np.full(x.shape, M_ROCK, np.int16)
    return f, (5, 5), h + 3, 2.6
def make_jetty(rng):
    def f(x, y, z):
        d = sdf_box(x, y, z, (0, 0, .5), (15, 4.0, .45), .15); m = np.full(x.shape, M_WOOD, np.int16)
        for px in (-12, -4, 4, 12):
            for py in (-3.6, 3.6):
                dp = sdf_capsule(x, y, z, (px, py, -1), (px, py, 3), .55); sel = dp < d; m = np.where(sel, M_BARK, m); d = np.minimum(d, dp)
        m = np.where(((np.floor(x / 1.6) % 2) == 0) & (d < .4), M_BARKT2, m)
        return d, m
    return f, (17, 5), 4, 2
M_BOARD, M_BOARDT, M_RAIL = 60, 61, 62         # wooden decks: brown boards, pale board lines, dark rails and posts
BRIDGE_HX, BRIDGE_HY, BRIDGE_DZ = 17.5, 14.0, 4.0    # main bridge: half-length along the road, half-width across it (the 24 texel road, half 12, plus clearance), deck height
def make_bridge(rng):
    """The main bridge: a planked deck as wide as the main road (28 texels, the 24 texel road plus clearance), over the river on two stone abutments on the
    banks, with a rail and posts down both sides. Local x runs along the road, across the river."""
    HX, HY, DZ = BRIDGE_HX, BRIDGE_HY, BRIDGE_DZ
    def f(x, y, z):
        d = sdf_box(x, y, z, (0, 0, DZ - 1.2), (HX, HY, 1.2), .25)              # the deck slab, 2.4 thick
        m = np.full(x.shape, M_BOARD, np.int16)                                 # warm brown boards, darker than the sand path
        plank = (np.floor(y / 2.6) % 2) == 0
        m = np.where(plank & (z > DZ - 1.0), M_BOARDT, m)                       # pale board lines so the deck reads as planks
        m = np.where((np.floor(x / 4.0) % 2 == 0) & (z > DZ - 1.0) & (np.abs(y) > HY - 1.4), M_BARK, m)   # cross-joints at the edges
        d = np.minimum(d, sdf_box(x, y, z, (0, 0, DZ - 2.9), (HX - .6, HY - .6, .5), .2))   # a shadow board under the deck edges
        for sy_ in (-HY + .9, HY - .9):
            rail = sdf_box(x, y, z, (0, sy_, DZ + 3.0), (HX - 1.0, .8, .8), .3)
            sel = rail < d; m = np.where(sel, M_RAIL, m); d = np.minimum(d, rail)
            for px in (-HX + 1.2, -HX + 5.6, -HX + 10.0, -HX + 14.4, HX - 14.4, HX - 10.0, HX - 5.6, HX - 1.2):
                dp = sdf_capsule(x, y, z, (px, sy_, DZ - .6), (px, sy_, DZ + 4.2), .75)
                sel = dp < d; m = np.where(sel, M_RAIL, m); d = np.minimum(d, dp)
        # stone abutments on the banks, reaching down to the bank ground under the deck
        for ax in (-(HX - 3.2), HX - 3.2):
            da = sdf_box(x, y, z, (ax, 0, -4.4), (2.9, HY - .4, 3.6), .6)
            sel = da < d; m = np.where(sel, M_ROCK, m); d = np.minimum(d, da)
        return d, m
    return f, (HX + 2, HY + 1), DZ + 6, 4
def make_footbridge(rng):
    """The footbridge on the west trail: a narrow plank crossing with a low rail, on posts either side of the river."""
    HX, HY, DZ = 13.0, 5.5, 2.6
    def f(x, y, z):
        d = sdf_box(x, y, z, (0, 0, DZ - .9), (HX, HY, .9), .2); m = np.full(x.shape, M_BOARD, np.int16)
        m = np.where(((np.floor(x / 2.4) % 2) == 0) & (z > DZ - .7), M_BOARDT, m)
        for sy_ in (-HY + .6, HY - .6):
            rail = sdf_box(x, y, z, (0, sy_, DZ + 2.0), (HX - .8, .5, .5), .15)
            sel = rail < d; m = np.where(sel, M_RAIL, m); d = np.minimum(d, rail)
            for px in (-HX + 1.0, HX - 1.0, 0.0):
                dp = sdf_capsule(x, y, z, (px, sy_, DZ - .4), (px, sy_, DZ + 2.8), .5)
                sel = dp < d; m = np.where(sel, M_RAIL, m); d = np.minimum(d, dp)
        for ax in (-(HX - 1.8), HX - 1.8):
            da = sdf_box(x, y, z, (ax, 0, -3.6), (1.6, HY - .3, 3.4), .5)
            sel = da < d; m = np.where(sel, M_ROCK, m); d = np.minimum(d, da)
        return d, m
    return f, (HX + 2, HY + 1), DZ + 4, 3
log('props defined')

# ---------------- placement (Poisson-style spacing, no stacking, off-grid) ----------------
prng = random.Random(7)
WATERNEAR = None
def ok_spot(u, v, r, slope_max=.55, shore=True, path=True, hmax=9.0, gap=1.5, path_clear=4.5):
    if not (0 < u < N - 1 and 0 < v < N - 1): return False
    if np.hypot(u - CU, v - CV) > Re(math.atan2(v - CV, u - CU)) * .9 - r * .5: return False
    h = float(terrain_h(u, v))
    if h > hmax or float(slope_at(u, v)) > slope_max: return False
    for a_ in range(0, 360, 60):
        uu, vv = u + math.cos(math.radians(a_)) * r * .8, v + math.sin(math.radians(a_)) * r * .8
        if float(samp(WD, uu, vv)) > -.5: return False
        if shore and float(samp(DW, uu, vv)) < 3.5: return False
    if float(samp(WD, u, v)) > -.5: return False
    if path and float(samp(dedge, u, v)) < r + path_clear: return False
    if path and float(samp(dgrove, u, v)) < r + GROVE_CLEAR: return False   # the grove trail's corridor stays open through the canopy
    if min(np.hypot(u - GATE[0], v - GATE[1]), np.hypot(u - GATE2[0], v - GATE2[1])) < r + 26: return False
    for (pu, pv, pr) in placed:
        if math.hypot(u - pu, v - pv) < r + pr + gap: return False
    return True
def put(kind, u, v, scale=1.0, rot=None, sid='new', z_extra=0.0, count=True, seed=None, **kw):
    rng = random.Random(prng.randint(0, 1 << 30) if seed is None else seed)   # seed: no draw from the shared stream
    rot = rng.uniform(0, 6.283) if rot is None else rot
    big = kw.get('big', True)
    if sid == 'new': inst_id[0] += 1; sid = inst_id[0]
    mk = dict(oak=make_oak, pine=make_pine, bush=make_bush, rock=lambda r: make_rock(r, big), crystals=make_crystals, stump=make_stump,
              mush=make_mush, flower=make_flower, tuft=make_tuft, reed=make_reed, sign=make_sign, lantern=make_lantern, windmill=make_windmill, windmill_sails=make_windmill_sails, tower=lambda r: make_tower(r), lighthouse=lambda r: make_tower(r, True, 56.0), obelisk=make_obelisk, ruin=lambda r: make_ruin(r, kw.get('style', 'tower'), kw.get('h', 24.0)), gateway=lambda r: make_gateway(r, kw.get('style', 'timber')), menhir=lambda r: make_menhir(r, kw.get('fixed', False)), jetty=make_jetty, bridge=make_bridge, footbridge=make_footbridge)[kind](rng)
    f, half, top, rad = mk
    z0 = float(terrain_h(u, v)) + z_extra
    voxelize(f, half, top, u, v, z0, scale, rot, sid, bottom=kw.get('bottom', -1.0))
    if isinstance(sid, int) and sid >= 10 and (kind in ('oak', 'pine', 'bush', 'crystals', 'windmill', 'windmill_sails', 'tower', 'lighthouse', 'obelisk', 'ruin', 'gateway', 'menhir', 'lantern', 'sign', 'bridge', 'footbridge') or (kind == 'rock' and big)):
        TALL.append(dict(id=sid, kind=kind, u=u, v=v, z=z0, scale=scale))
    if count: placed.append((u, v, rad * scale))
    return z0
def try_region(kind, cu_, cv_, rad, n, scale_rng=(.9, 1.15), tries=60, **kw):
    got = 0
    r_fp = dict(oak=10, pine=7, bush=6, rock=7, stump=6.5, mush=6, crystals=9, sign=6, lantern=3, windmill=12, tower=11, lighthouse=11, obelisk=6, gateway=10, menhir=3, jetty=3, bridge=3, footbridge=3)[kind]
    for _ in range(n):
        for t in range(tries):
            a_, rd = prng.uniform(0, 6.283), math.sqrt(prng.random()) * rad
            u, v = cu_ + math.cos(a_) * rd, cv_ + math.sin(a_) * rd
            sc = prng.uniform(*scale_rng)
            if ok_spot(u, v, r_fp * sc, **{k: w for k, w in kw.items() if k in ('slope_max', 'shore', 'path', 'hmax', 'gap', 'path_clear')}):
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
    if a_['kind'] in ('pad', 'gate', 'arch', 'player_spawn'): placed.append((a_['u'], a_['v'], 14 if a_['kind'] == 'pad' else 18 if a_['kind'] != 'player_spawn' else 8))
# a tier is a line of pads: keep the gaps between them clear, and the ground just south of each plate (a tall tree standing
# there would hide the pad behind its crown)
for d_ in LAY.DISTRICTS:
    for (x0, y0), (x1, y1) in zip(d_['pads'], d_['pads'][1:]):
        placed.append((*s2uv((x0 + x1) / 2, (y0 + y1) / 2), 12))
    for (sx, sy) in d_['pads']:
        for ox_, oy_ in ((0, 20), (-20, 12), (20, 12)):
            placed.append((*s2uv(sx + ox_, sy + oy_), 9))
# the two gateways (onboarding arch in the south, Emberwatch gate in the north), framing the walk-through
for _g, _st in ((GATE, 'stone'), (GATE2, 'timber')): put('gateway', _g[0], _g[1], 1.0, rot=-.785, count=False, style=_st)
# landmarks first so groves flow around them
for lm in LAY.LANDMARKS:
    u, v = s2uv(*lm['at'])
    if lm['kind'] == 'elder_oak': put('oak', u, v, 1.9, rot=.7, sid='new')
    elif lm['kind'] in ('tower', 'lighthouse') and lm['id'] in RUIN_PLAN:      # the tall towers are ruins now
        _st_, _h_, _rot_ = RUIN_PLAN[lm['id']]; put('ruin', u, v, 1.0, rot=_rot_, style=_st_, h=_h_)
    elif lm['kind'] == 'obelisk': put(lm['kind'], u, v, 1.0, rot=0.0)
    elif lm['kind'] == 'great_lantern': put('lantern', u, v, 2.6, rot=0.0)
    elif lm['kind'] == 'windmill':
        put('windmill', u, v, 1.0, rot=-.785)                    # the tower
        # the sails, as their own sprite, pivoting on the hub: the mill's point (0, 10.4, 35) in its own frame, rotated by -.785
        _c, _s = math.cos(-.785), math.sin(-.785)
        _hu, _hv = u - _s * 10.4, v + _c * 10.4
        # placed directly, not through put(): put() draws from the placement random stream and takes the next instance
        # id, and either would move every prop after the windmill. The sails get their own id, far above the rest.
        _sf, _sh, _st, _sr = make_windmill_sails(None)
        _sz = float(terrain_h(u, v)) + 35.0                       # the hub sits 35 texels above the tower's foot
        voxelize(_sf, _sh, _st, _hu, _hv, _sz, 1.0, -.785, 900001, bottom=-30.0)
        TALL.append(dict(id=900001, kind='windmill_sails', u=_hu, v=_hv, z=_sz, scale=1.0))
        placed.append((_hu, _hv, _sr))
    elif lm['kind'] == 'stones':
        for k in range(7):
            a_ = k / 7 * 6.283 + .3; put('menhir', u + math.cos(a_) * 15, v + math.sin(a_) * 15, 1.0, rot=a_, count=False, fixed=True)
    elif lm['kind'] == 'jetty':
        ju, jv = LAKE['c']
        for k in range(120):
            ju += .7; jv += .7
            if float(samp(WD, ju, jv)) < -.5 and LAKE_S[int(min(max(ju, 0), N - 1)), int(min(max(jv, 0), N - 1))] > 1.0: break
        put('jetty', ju - 7, jv - 7, 1.0, rot=.785, z_extra=-.3)
        JETTY_AT = (ju, jv); JETTY_C = (ju - 7, jv - 7)
    elif lm['kind'] == 'sign': put('sign', u, v, 1.0)
# bridge where the main road crosses the stream
def _path_dir_uv(pp_uv, p):
    """Direction (radians, uv frame) of the path segment nearest to uv point p."""
    best, ang = 1e18, 0.0
    for (ax, ay), (bx, by) in zip(pp_uv, pp_uv[1:]):
        vx, vy = bx - ax, by - ay; L2 = vx * vx + vy * vy or 1e-9
        t = max(0.0, min(1.0, ((p[0] - ax) * vx + (p[1] - ay) * vy) / L2))
        d = math.hypot(p[0] - ax - vx * t, p[1] - ay - vy * t)
        if d < best: best, ang = d, math.atan2(vy, vx)
    return ang
# the main bridge: its long axis runs along the main road, across the river (13 texels wide)
bu, bv = s2uv(*LAY.BRIDGE); BRIDGE_ANG = _path_dir_uv(PATHS_UV[0], (bu, bv))
put('bridge', bu, bv, 1.0, rot=BRIDGE_ANG, z_extra=3.4, count=False, bottom=-12.0)   # the bed sits about 3 below the water, so the deck stands about 4.5 above it
# the footbridge: the west trail's plank crossing of the river, along the trail
fu_, fv_ = s2uv(*LAY.FOOT_CROSSING); FOOT_ANG = _path_dir_uv(PATHS_UV[3], (fu_, fv_))
put('footbridge', fu_, fv_, 1.0, rot=FOOT_ANG, z_extra=3.2, count=False, bottom=-10.0)
# groves: oaks, pines, bushes, rocks, crystals, never stacked
# trees keep a real gap between crowns (the old gap of 1.5 texels packed them into walls). Pines are narrow, so they sit closer.
TREE_GAP = dict(oak=6.0, pine=8.0)
# round 3 of the v3 remodel: oaks and pines grow toward the v3 size (about two walkers tall, ~60 texels). Scales the grove draw range.
TREE_SIZE = dict(oak=float(os.environ.get('OAK_SIZE', '1.45')), pine=float(os.environ.get('PINE_SIZE', '1.25')))
GROVE_MUL = float(os.environ.get('GROVE_MUL', '2.2'))      # density of the tree and bush groves (1.0 = the counts before the denser pass)
ROAD_ROCKS = int(os.environ.get('ROAD_ROCKS', '40'))       # stones just off the road and lane edges, baked into the ground (no node cost)
BANK_ROCKS = int(os.environ.get('BANK_ROCKS', '0'))         # stones on the water banks: 0 until the water thread's layout is picked
for kind, c_, rad, n in LAY.GROVES:
    kw = dict(scale_rng=(.75, 1.4)) if kind == 'pine' else dict(scale_rng=(.9, 1.2))
    if kind in TREE_SIZE: kw['scale_rng'] = tuple(s_ * TREE_SIZE[kind] for s_ in kw['scale_rng'])
    if kind in TREE_GAP: kw['gap'] = TREE_GAP[kind]
    if kind == 'crystals': kw = dict(tries=120, slope_max=.7, hmax=14)
    n_ = n if kind in ('crystals', 'rock') else round(n * GROVE_MUL)
    try_region(kind, *SC(c_), rad * .72, n_ if not FAST else max(1, n_ // 3), **kw)
# rocks keep well back from the path (path_clear), so no chunky rock border frames it
for _ in range(14): try_region('rock', prng.uniform(80, 740), prng.uniform(80, 740), 90, 1, scale_rng=(.8, 1.25), big=prng.random() < .6, path_clear=11.0)
# lanterns: one size, one rhythm per path tier. A road gets a lamp about every LANTERN_STEP['road'] texels of its length
# (screen units), a lane every LANTERN_STEP['lane'], a trail none ('trail' 400 leaves two, one at each end of its
# span). Each path's lamps are spread evenly along it with the same LANTERN_END margin at both ends, so the gaps match
# and no lamp sits on a junction or a gate. A lamp stands LANTERN_OFF texels off the centre line, and the side
# alternates along a path so the row reads as a rhythm. If that spot is blocked (trees, pads, slope), the lamp slides
# along its path, up to a third of its step, to the first free spot. No two lamps are closer than LANTERN_MIN, and the
# great lantern counts, so two paths meeting do not double up. Only the facing varies (four quarter turns, in a fixed
# order). Each lamp is one light for the night pools, and gen_life_anchors reads the lantern sprites for its glow.
LANTERN_STEP = {'road': 110.0, 'lane': 200.0, 'trail': 400.0}
LANTERN_END, LANTERN_OFF, LANTERN_MIN = 70.0, 19.0, 80.0   # 19: clear of the wider path (half-width up to about 13)
LANTERN_SLIDE = 8.0                                         # texels per slide step along the path
LANTERN_STREAM_DRAWS = 25     # lamps the old rhythm placed on main after the districts moved: the props after the lanterns keep their random stream
def _along(pp, t):
    """Point and unit normal at arc length t along a polyline (clamped to its ends)."""
    segs = list(zip(pp, pp[1:])); acc = 0.0
    for k, ((x0, y0), (x1, y1)) in enumerate(segs):
        L_ = math.hypot(x1 - x0, y1 - y0)
        if t <= acc + L_ or k == len(segs) - 1:
            f_ = min(1.0, max(0.0, (t - acc) / L_)); dx, dy = x1 - x0, y1 - y0
            return x0 + dx * f_, y0 + dy * f_, -dy / L_, dx / L_
        acc += L_
def _lantern_slots():
    """(path index, arc length, preferred side) for every lamp, evenly spread along each path that has a lamp tier."""
    for pi, (pp, tier) in enumerate(zip(LAY.PATHS, LAY.PATH_TIER)):
        step = LANTERN_STEP[tier]
        if step <= 0: continue
        total = sum(math.hypot(x1 - x0, y1 - y0) for (x0, y0), (x1, y1) in zip(pp, pp[1:]))
        span = total - 2 * LANTERN_END
        n = max(1, round(span / step) + 1)
        for i in range(n):
            t = LANTERN_END + (span * i / (n - 1) if n > 1 else span / 2)
            yield pi, t, (1.0 if i % 2 == 0 else -1.0)
lantern_count = 0
lamp_xy = [tuple(lm['at']) for lm in LAY.LANDMARKS if lm['kind'] == 'great_lantern']   # screen positions of lamps already placed
for pi, t0, side0 in _lantern_slots():
    step = LANTERN_STEP[LAY.PATH_TIER[pi]]
    shifts = [0.0] + [s_ * LANTERN_SLIDE for k_ in range(1, int(step / 3 / LANTERN_SLIDE) + 1) for s_ in (k_, -k_)]
    done = False
    for sh in shifts:
        px, py, nx, ny = _along(LAY.PATHS[pi], t0 + sh)
        for sgn in (side0, -side0):
            mx, my = px + nx * LANTERN_OFF * sgn, py + ny * LANTERN_OFF * sgn
            if any(math.hypot(mx - qx, my - qy) < LANTERN_MIN for qx, qy in lamp_xy): continue
            u, v = s2uv(mx, my)
            if ok_spot(u, v, 3, path=False, gap=0, slope_max=.7):   # the offset keeps a lamp clear of its own path's edge (dedge)
                put('lantern', u, v, 1.0, rot=(lantern_count % 4) * math.pi / 2, seed=lantern_count)
                lamp_xy.append((mx, my)); lantern_count += 1; done = True
                break
        if done: break
    if not done: log('lamp left out: no free spot on path %d near %.0f' % (pi, t0))
# the props after the lanterns draw from the same stream they did under the old rhythm, and take the same ids, so only
# the lanterns change. The old rhythm used LANTERN_STREAM_DRAWS draws and ids; pad what this one did not use.
assert lantern_count <= LANTERN_STREAM_DRAWS, 'more lamps than the stream was kept for'
for _ in range(LANTERN_STREAM_DRAWS): prng.randint(0, 1 << 30)
inst_id[0] += LANTERN_STREAM_DRAWS - lantern_count
log('lanterns placed', lantern_count)
log('trees/rocks placed', len(placed))

# ground cover: tufts and flower drifts in clusters, flowers lean toward the path edges
def cluster(kind, cu_, cv_, spread, n, **kw):
    for _ in range(n):
        u, v = cu_ + prng.gauss(0, spread), cv_ + prng.gauss(0, spread)
        if ok_spot(u, v, 1.2, slope_max=.7, path=False, gap=-1.0) and float(samp(dpath, u, v)) > (13.5 if kind == 'flower' else 5.5) and float(samp(dgrove, u, v)) > GROVE_CLEAR and float(terrain_h(u, v)) < 10:
            put(kind, u, v, prng.uniform(.85, 1.2) * (1.45 if kind == 'flower' else 1.0), count=False, sid=1)
for _ in range(150 if not FAST else 8): cluster('tuft', prng.uniform(60, 760), prng.uniform(60, 760), 7, prng.randint(3, 7))
for _ in range(100 if not FAST else 6): cluster('flower', prng.uniform(60, 760), prng.uniform(60, 760), 6, prng.randint(5, 10))
for _ in range(50 if not FAST else 0): cluster('flower', *SC((1030 + prng.uniform(-110, 110), 560 + prng.uniform(-50, 50))), 8, prng.randint(8, 14))   # Foxglove Rise fields
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
for (u, v) in shore_spots(240 if not FAST else 8, 1.3, 3.2):
    if prng.random() < .8: put('reed', u, v, prng.uniform(.9, 1.2), count=False, sid=1)
for (u, v) in shore_spots(110 if not FAST else 6, .8, 4.0):
    f_, half, top, rad = make_rock(random.Random(prng.randint(0, 1 << 30)), False); voxelize(f_, half, top, u, v, float(terrain_h(u, v)) - .4, prng.uniform(.5, .9), prng.uniform(0, 6.28), 1)
for B, nl, rmin in ((LAKE, 130, 2.2), (POND, 40, 2.0)):
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
# extra stones: ROAD_ROCKS just off the road and lane edges, BANK_ROCKS a few texels from the water (waits for the water
# thread's layout). Baked with sid 1, so they add to the ground and its shadows, not to the node count. Own random stream,
# so every placement above keeps its place.
if ROAD_ROCKS or BANK_ROCKS:
    _rr = random.Random(777)
    _stones = []
    def _stone_spot(bank):
        for _ in range(6000):
            u, v = _rr.uniform(20, N - 20), _rr.uniform(20, N - 20)
            if not INSIDE[int(u), int(v)] or float(terrain_h(u, v)) > 9.0 or float(slope_at(u, v)) > .6: continue
            if float(samp(WD, u, v)) > -.3: continue                              # land only
            if bank:
                if not (.8 < float(samp(DW, u, v)) < 3.2): continue                # the bank: a few texels from open water
            else:
                if not (1.5 < float(samp(dedge, u, v)) < 6.0): continue            # just off a road or lane edge
                if float(samp(DW, u, v)) < 4.0: continue                           # not a second bank
            if float(samp(dgrove, u, v)) < GROVE_CLEAR: continue
            if any(math.hypot(u - pu, v - pv) < pr + 3.0 for (pu, pv, pr) in placed): continue
            if any(math.hypot(u - su, v - sv) < 5.0 for (su, sv) in _stones): continue
            return u, v
        return None
    _kinds = [False] * ROAD_ROCKS + [True] * BANK_ROCKS
    for _bank in _kinds:
        _p = _stone_spot(bank=_bank)
        if _p is None: continue
        _u, _v = _p
        _f, _half, _top, _rad = make_rock(random.Random(_rr.randint(0, 1 << 30)), _rr.random() < .45)
        voxelize(_f, _half, _top, _u, _v, float(terrain_h(_u, _v)) - .4, _rr.uniform(.7, 1.05), _rr.uniform(0, 6.28), 1)
        _stones.append((_u, _v))
    log('extra stones placed %d of %d (road %d, bank %d)' % (len(_stones), len(_kinds), ROAD_ROCKS, BANK_ROCKS))
# flower drifts beside every path: patches in the open ground, never a ring along the edge. A candidate sits 9 to 30
# texels from the path EDGE (dedge, so a road and a trail get the same clearance), and a slow noise field decides where the
# drifts are (about half the ground), so the flowers gather in patches with bare grass between them. Placed last, after
# the lilies, so nothing earlier moves.
VERGE_BAND = (9.0, 30.0)
for pp in PATHS_UV:
    for (ax, ay), (bx, by) in zip(pp, pp[1:]):
        seg = math.hypot(bx - ax, by - ay)
        if seg < 1: continue
        tx, ty = (bx - ax) / seg, (by - ay) / seg; nx_, ny_ = -ty, tx
        n = max(1, int(seg / 1.6))
        for k in range(n):
            f = (k + prng.random()) / n
            for side in (1.0, -1.0):
                if prng.random() > .5: continue
                off = prng.uniform(VERGE_BAND[0], VERGE_BAND[1] + 12.0)   # centre-line offset: the widest path's half-width (12) is added to the band; dedge filters the rest
                u, v = ax + (bx - ax) * f + nx_ * side * off, ay + (by - ay) * f + ny_ * side * off
                if vn2(u / 9.0, v / 9.0, 53) < .5: continue   # drifts, not a ring
                if VERGE_BAND[0] <= float(samp(dedge, u, v)) <= VERGE_BAND[1] and float(samp(dgrove, u, v)) > GROVE_CLEAR and ok_spot(u, v, .9, slope_max=.9, path=False, gap=-1.0, hmax=14.0):
                    put('flower', u, v, prng.uniform(1.05, 1.3), count=False, sid=1)
log('path drifts placed')

# Extra ruins, scattered over the flat ground of Larkmoor in small organic groups: two or three ruins close together, the groups
# well apart, never in a row. Nathan: several versions, spread around, not bundled. They come last, with their own random stream
# and seeds, so every prop placed above keeps its place. Flat spots only (slope and clearance checked here).
EXTRA_RUINS = [('arch', 20.0), ('wall', 18.0), ('tower', 22.0), ('wall', 22.0), ('arch', 24.0), ('tower', 18.0), ('wall', 19.0), ('arch', 21.0)]
EXTRA_GROUPS = [2, 2, 2, 1, 1]          # ruins per group, placed in order: 8 ruins in 5 groups
_xr = random.Random(4242)
_xr_spots = []
_xr_k = 0
for _gn in EXTRA_GROUPS:
    _gc = None
    for _t in range(900):                      # a group centre, far from the other groups and the landmarks
        _a, _rd = _xr.uniform(0, 6.283), math.sqrt(_xr.random()) * 0.7 * R
        _cu, _cv = CU + math.cos(_a) * _rd, CV + math.sin(_a) * _rd
        if any(math.hypot(_cu - pu, _cv - pv) < 190 for (pu, pv) in _xr_spots): continue
        if not ok_spot(_cu, _cv, 12.0, slope_max=0.8, hmax=200.0, path_clear=8.0): continue
        _gc = (_cu, _cv); break
    if _gc is None: continue
    _members = []
    for _j in range(_gn):
        for _t in range(400):                  # each ruin of the group 26 to 44 texels from the centre, away from its neighbours
            _b, _dd = _xr.uniform(0, 6.283), _xr.uniform(26.0, 44.0)
            _u, _v = _gc[0] + math.cos(_b) * _dd, _gc[1] + math.sin(_b) * _dd
            if any(math.hypot(_u - pu, _v - pv) < 30 for (pu, pv) in _members): continue
            if not ok_spot(_u, _v, 12.0, slope_max=0.8, hmax=200.0, path_clear=8.0): continue
            _style, _xh = EXTRA_RUINS[_xr_k % len(EXTRA_RUINS)]; _xr_k += 1
            put('ruin', _u, _v, 1.0, style=_style, h=_xh, seed=_xr.randint(0, 1 << 30))
            _members.append((_u, _v)); break
    _xr_spots.extend(_members)
log('extra ruins placed %d in %d groups' % (len(_xr_spots), len(EXTRA_GROUPS)))

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
T_GRASS, T_ROCK, T_SAND, T_WET, T_PATH, T_FROST, T_EARTH, T_WATER, T_FOAM, T_TRAIL = 100, 101, 102, 103, 104, 105, 106, 107, 108, 109
mat = np.full(len(FU), T_GRASS, np.int16)
rockness = smooth(.42, .85, slope + np.clip(h - 10, 0, 50) / 50 + (n1 - .5) * .25)
mat[rockness > .5] = T_ROCK
mat[(h > 54) & (slope < 2.6) & (n2 > .3) & (rockness > .3)] = T_FROST
dwt = samp(DW, FU, FV) + (n2 - .5) * 2.2
beach = (dwt < 5.5) & (slope < 1.1) & (h < 6)
mat[beach] = T_SAND; mat[(dwt < 2.0) & beach] = T_WET
# path hierarchy: a road (wide), a lane (medium) and a trail (narrow). Roads and lanes are trodden (T_PATH); a trail is
# worn, darker ground (T_TRAIL). Each tier's edge is ragged, not a ruler line: its half-width wobbles with noise, and rock
# only cuts it where the slope is steep. Shade falls off at each tier's own edge (dn is in units of the old half-width).
edge_noise = 1 + .22 * (vn2(FU / 7, FV / 7, 41) - .5)
dtr = {t: samp(dtier[t], FU, FV) for t in HALF}
on_path = {t: (dtr[t] < HALF[t] * edge_noise) & (rockness < .85) for t in HALF}
mat[on_path['road'] | on_path['lane']] = T_PATH
mat[on_path['trail'] & ~(on_path['road'] | on_path['lane'])] = T_TRAIL
# the plaza at the lighthouse foot: a small widened disc of the same worn earth, where the grove trail ends
mat[(np.hypot(FU - LH_UV[0], FV - LH_UV[1]) < FOOT_R) & (rockness < .85) & ~(on_path['road'] | on_path['lane'])] = T_TRAIL
dn = np.minimum.reduce([dtr[t] / HALF[t] for t in HALF]) * 10.5
L = LDIR
diff = np.clip(nrm @ L, 0, 1)
if GRASS == 'old': lt = .13 + .87 * diff + (tone - .5) * .26 * (mat == T_GRASS) + (n2 - .5) * .06
else: lt = .13 + .87 * diff + (tone - .5) * .10 * (mat == T_GRASS) + (n2 - .5) * .06 * (mat != T_GRASS)    # grass detail comes from grass_tex.py
strata = (np.floor(h / 3.1 + vn2(FU / 18, FV / 18, 5) * 2.5) % 2)
lt -= .07 * strata * (mat == T_ROCK)
lap = samp(LAP, FU, FV); lt -= np.clip(lap * .5, 0, .32); lt += np.clip(-lap * .25, 0, .12)
# worn path, one material: a soft tone shift that follows the noise, with no dark rim on the grass and no pebble speckle
# (those read as a hard edging band). The trodden ground and the turf meet through the ragged edge above.
on_trod = np.isin(mat, [T_PATH, T_TRAIL])
lt += .06 * (vn2(FU / 2.4, FV / 2.4, 31) - .5) * on_trod
lt -= .10 * smooth(5.25, 10.5, dn) * on_trod * (n2 > .45)
# value structure (V3, picked by Nathan): three value bands per grass patch, a lighter trodden path, and a darker floor
# under canopies. The bands follow smooth patch noise, not texel noise. The canopy floor uses the shadow height field:
# ground that stands under props (trees, bushes, rocks) gets a soft dark falloff of about 4 texels around them.
vb = .6 * vn2(FU / 26, FV / 26, 61) + .4 * vn2(FU / 11, FV / 11, 62)
lt += np.where(vb < .36, -.13, np.where(vb > .64, .13, 0.)) * (mat == T_GRASS)
lt += .10 * (mat == T_PATH)
from PIL import ImageFilter as _IF
_tall = ((HS - H0) > 2.5).astype(np.uint8) * 255
_under = np.asarray(Image.fromarray(_tall).filter(_IF.MaxFilter(9)).filter(_IF.GaussianBlur(2.5))).astype(np.float32) / 255.0
lt -= .16 * np.clip(samp(_under, FU, FV), 0, 1) * (mat == T_GRASS)
# main road = flagstones: lit sand stones in staggered rows, with worn earth mortar between them. Lanes stay plain packed
# sand and trails stay dark earth, so the three tiers read apart at 1x without a new material. The mortar is a light
# drop only, so the palette and the ramp stay the same as the path's.
road_m = on_path['road'] & ~on_path['lane'] & (mat == T_PATH)
row_ = np.floor(FV / 4.0)
cu_ = (FU + 2.5 * (row_ % 2)) % 5.0
cv_ = FV % 4.0
joint_v = (cu_ < 1.0) & (vn2(FU / 3.0, FV / 3.0, 47) > .45)  # vertical joints: about half of them, so the road is not a grid
joint_h = cv_ < 1.0                                          # horizontal joints: every row
mortar = (joint_v | joint_h) & road_m
lt -= .30 * mortar                                           # a soft drop to the earth step, not a hard grid
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
RAMP = {T_GRASS: [1, 2, 3, 3, 4], T_ROCK: [1, 2, 6, 6, 5], T_SAND: [6, 6, 5, 7], T_WET: [1, 6, 6, 5], T_PATH: [6, 6, 5, 5], T_TRAIL: [6, 6, 6, 1], T_FROST: [6, 5, 7, 7], T_EARTH: [1, 6, 6, 5],
        M_FOL: [1, 2, 3, 4], M_BARK: [1, 6, 6, 5], M_PINE: [1, 2, 2, 3], M_ROCK: [1, 6, 6, 7], M_MOSS: [2, 3, 4, 4], M_CRYS: [2, 3, 4, 7], M_WOOD: [1, 6, 5, 7],
        M_PETA: [3, 5, 5, 7], M_PETB: [2, 6, 6, 5], M_STEM: [1, 2, 3, 3], M_LILY: [1, 2, 3, 4], M_REED: [1, 2, 3, 3], M_CAT: [1, 6, 6, 5], M_BERRY: [1, 6, 6, 5],
        M_CAP: [1, 6, 6, 5], M_CSTEM: [6, 5, 7, 7], M_PAPER: [5, 7, 7, 7], M_GRASS: [2, 3, 3, 4], M_BARKT: [6, 5, 7, 7], M_BARKT2: [1, 6, 5, 7], M_INK: [0, 0, 1, 1], M_PAPER + 20: [5, 7, 7, 7], M_DARKF: [0, 0, 1, 1]}
RAMP.update({M_BOARD: [1, 6, 6, 5], M_BOARDT: [6, 5, 5, 7], M_RAIL: [0, 1, 1, 6]})   # wooden bridges
# canopy shading (round 2 of the v3 remodel): leaves and pine boughs step through their shades with crisp edges
CANOPY_MATS = (M_FOL, M_PINE)
CANOPY_DBAND = (.44, .14)     # the dither spreads over the middle 14% of each step, so the Bayer edge stays but the steps read
mat_ = allp['mat']; nz_ = allp['nz']; lraw = allp['wl'].copy()
light = np.where(isprop | (np.arange(len(u_)) >= len(T['u'])) & False, 0, 0).astype(float)
# lighting for props (terrain/plinth carried theirs in 'wl')
pi_ = isprop
dif = np.clip(allp['nx'] * L[0] + allp['ny'] * L[1] + allp['nz'] * L[2], 0, 1)
lp = .04 + 1.05 * dif
tex = vn3(u_ * .8, v_ * .8, z_ * .8, 3) - .5
lp += np.where(np.isin(mat_, [M_FOL, M_PINE, M_MOSS]), tex * .55 + (vn3(u_ * 2.2, v_ * 2.2, z_ * 2.2, 9) - .5) * .4, 0)
# pine tiers: upward-facing tier tops lift a band, downward ledges drop one (the ramp is only four bands)
lp += np.where(mat_ == M_PINE, .7 * np.clip((nz_ - .1) / .4, 0, 1) - .45 * np.clip((-nz_ - .05) / .35, 0, 1), 0)
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
    def dith(ramp, l, mask, dband=(.30, .40)):
        # dband: where the Bayer dither spreads between two ramp steps (start, width of the band inside each step)
        r = np.array(ramp); n = len(r) - 1; l = np.clip(l, 0, .9999); vv = l * n; lo = np.floor(vv).astype(int); f = np.clip((vv - lo - dband[0]) / dband[1], 0, 1)
        hi = (f > bay) & (lo < n); return r[np.where(hi, lo + 1, lo)]
    img_l = grass_tex.apply(GRASS, img_l, img_mat == T_GRASS, XX, YY, dict(vn2=vn2, fbm2=fbm2))
    out = np.full((H, W), -1, np.int64)
    for m_, ramp in RAMP.items():
        sel_ = img_mat == m_
        # canopy and pine: a narrow dither band, so each shade step has a clear edge and the Bayer texture stays on the edges
        if sel_.any(): out[sel_] = dith(ramp, img_l, sel_, CANOPY_DBAND if m_ in CANOPY_MATS else (.30, .40))[sel_]
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
depth_pass.fill_unbaked_ground(os.path.join(OUT, 'ground_n.png'))   # the map's edges outside the render mask
depth_pass.write_height(os.path.join(OUT, 'ground_h.png'), AUX_GND['z'], id_gnd >= 0)
os.makedirs(os.path.join(OUT, 'sprites'), exist_ok=True); sprites = []
# ordinary lanterns share one window around their foot: x from -9 to +9, y from -26 to +2 (measured on every lamp at every
# facing). The trimmed box used to vary from 10 to 26 texels tall, so no two lamps matched.
LANTERN_WIN = (9, 26, 19, 29)   # left of the foot, above the foot, width, height
# the sails are rendered alone, so the parts behind the tower are in their sprite too (the full render keeps only what is visible)
_sail_on = allp['id'] == 900001
if _sail_on.any():
    rgb_sails, id_sails = render_scene(_sail_on); AUX_SAILS = LAST_AUX
else:
    rgb_sails, id_sails, AUX_SAILS = rgb_full, id_full, AUX_FULL
def _largest_part(m):
    """Keep only the largest 4-connected part of a boolean sprite mask."""
    seen = np.zeros(m.shape, bool); best = []
    for y_, x_ in zip(*np.nonzero(m)):
        if seen[y_, x_]: continue
        comp = []; stack = [(y_, x_)]; seen[y_, x_] = True
        while stack:
            y, x = stack.pop(); comp.append((y, x))
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= ny < m.shape[0] and 0 <= nx < m.shape[1] and m[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True; stack.append((ny, nx))
        if len(comp) > len(best): best = comp
    out = np.zeros(m.shape, bool)
    for y, x in best: out[y, x] = True
    return out
for t in TALL:
    IDM, RGBM, AUXM = (id_sails, rgb_sails, AUX_SAILS) if t['id'] == 900001 else (id_full, rgb_full, AUX_FULL)
    ys_, xs_ = np.nonzero(IDM == t['id'])
    if len(xs_) < 12: continue
    fx, fy = OXS0 + (t['u'] - t['v']), OYS0 + (t['u'] + t['v']) / 2 - t['z']
    if t['kind'] == 'lantern' and t['scale'] == 1.0:   # the great lantern landmark (scale 2.6) keeps its own crop
        x0, y0 =int(math.floor(fx)) - LANTERN_WIN[0], int(math.floor(fy)) - LANTERN_WIN[1]
        x1, y1 = x0 + LANTERN_WIN[2] - 1, y0 + LANTERN_WIN[3] - 1
        assert (IDM[y0:y1 + 1, x0:x1 + 1] == t['id']).sum() == len(xs_), 'lantern %d leaves its window' % t['id']
    else:
        x0, x1, y0, y1 = xs_.min(), xs_.max(), ys_.min(), ys_.max()
    spr = np.zeros((y1 - y0 + 1, x1 - x0 + 1, 4), np.uint8)
    m_ = IDM[y0:y1 + 1, x0:x1 + 1] == t['id']
    if t['kind'] == 'windmill': m_ = _largest_part(m_)   # the mill is one solid tower; loose pixels up top are sail edge, not tower
    # sprite albedo takes the prop palette (PROP_PAL); the ground and backdrop keep PAL/COLS
    spr[m_, :3] = PROP_COLS[np.clip(AUXM['out'][y0:y1 + 1, x0:x1 + 1][m_], 0, None)]; spr[m_, 3] = 255
    fn = 'sprites/%s_%03d.png' % (t['kind'], t['id']); Image.fromarray(spr).save(os.path.join(OUT, fn))
    depth_pass.write_relight_data(os.path.join(OUT, fn[:-4] + '_n.png'), AUXM, y0, y1, x0, x1, m_)
    # a bridge sorts 40 texels north of its centre, so the walker on the deck always draws over it (the picture stays put: offset = box - foot)
    _fy_sort = fy - 40.0 if t['kind'] in ('bridge', 'footbridge') else fy
    sprites.append(dict(file=fn, nrm=fn[:-4] + '_n.png', kind=t['kind'], x=int(x0) - BLX, y=int(y0) - BLY, w=int(x1 - x0 + 1), h=int(y1 - y0 + 1), foot=[round(float(fx), 1), round(float(_fy_sort), 1)], sort_y=round(float(fy), 1)))

# ---------------- walkable mask (terrain-only pass; tall props / rocks / bushes block by footprint) ----------------
nT = len(T['u']); BLOCK_R = dict(bridge=0.0, footbridge=0.0, oak=4.0, pine=3.5, crystals=9.0, crystal=9.0, rock=8.0, bush=5.5, stump=3.0, windmill=10.0, tower=9.5, lighthouse=9.5, ruin=12.5, obelisk=5.5, gateway=0.0, menhir=3.2, lantern=1.6, sign=2.0)
wk = (wd <= .04) & (DW[np.clip(FU.astype(int), 0, N - 1), np.clip(FV.astype(int), 0, N - 1)] >= 1.4) & (slope < .75) & (h < 14) & (mat != T_FROST) & (mat != T_ROCK)
for t in TALL:
    r_ = BLOCK_R.get(t['kind'], 4.0)
    wk &= np.hypot(FU - t['u'], FV - t['v']) > r_
def _deck_strip(cu_, cv_, ang, half_len, half_w, flare):
    # walkable along a deck: a strip on its axis, flared at both ends so the walker finds the entry easily
    dn_ = (FU - cu_) * math.cos(ang) + (FV - cv_) * math.sin(ang); dc_ = -(FU - cu_) * math.sin(ang) + (FV - cv_) * math.cos(ang)
    ends = np.clip((np.abs(dn_) - (half_len - 5)) / 5, 0, 1)
    return (np.abs(dn_) < half_len + 2) & (np.abs(dc_) < half_w + flare * ends)
wk |= _deck_strip(bu, bv, BRIDGE_ANG, BRIDGE_HX, BRIDGE_HY, 3.0)      # the bridge over the river: the road's width
wk |= _deck_strip(fu_, fv_, FOOT_ANG, 13.0, 5.5, 2.0)       # the footbridge on the west trail
if 'JETTY_C' in globals(): wk |= _deck_strip(JETTY_C[0], JETTY_C[1], .785, 15.0, 4.6, 3.0)   # the lake jetty, walkable out onto the water
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
# Ember Quarry entrance props (entrance/entrance.json, made by gen_ember_entrance.py) are solid. The walker may not stand in a
# prop's drawn box: a walker there is hidden by the prop, which sorts in front of him. Canvas pixels are the sprite frame.
_ember_doc = json.load(open(os.path.join(OUT, 'entrance', 'entrance.json')))
for _es in _ember_doc.get('sprites', []):
    if _es.get('kind') != 'ember_prop': continue
    _x0, _y0 = int(_es['x']), int(_es['y'])
    wimg[max(0, _y0):min(H, _y0 + int(_es['h'])), max(0, _x0):min(W, _x0 + int(_es['w']))] = 0
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
# Water is what the render draws as water (material T_WATER), except where a bridge deck stands on it. Water is never walkable on
# the ground; its pixels go in the green channel, so the walker may be in the air over them (a jump) and landing there sends it
# to the bank (world/walk_mask.gd). Red and blue mark walkable ground.
deck_pts = _deck_strip(bu, bv, BRIDGE_ANG, BRIDGE_HX, BRIDGE_HY, 3.0) | _deck_strip(fu_, fv_, FOOT_ANG, 13.0, 5.5, 2.0)
deck_img = np.zeros((H, W), bool); deck_img[_py[tm], _px[tm]] = deck_pts[_win[tm]]
wat_img = (LAST_AUX['mat'] == T_WATER) & ~deck_img
walk_img = comp & ~wat_img
wm = np.zeros((H, W, 4), np.uint8); wm[..., 3] = 255
wm[walk_img, 0] = 255; wm[walk_img, 2] = 255; wm[wat_img, 1] = 255
# water connectivity, for the log: the lake, the river and the mere should be one body
_seen = np.zeros((H, W), bool); _nwat = []
for _y0, _x0 in zip(*np.nonzero(wat_img)):
    if _seen[_y0, _x0]: continue
    _seen[_y0, _x0] = True; _st = [(_y0, _x0)]; _n = 0
    while _st:
        _cy, _cx = _st.pop(); _n += 1
        for _ny, _nx in ((_cy + 1, _cx), (_cy - 1, _cx), (_cy, _cx + 1), (_cy, _cx - 1)):
            if 0 <= _ny < H and 0 <= _nx < W and wat_img[_ny, _nx] and not _seen[_ny, _nx]: _seen[_ny, _nx] = True; _st.append((_ny, _nx))
    _nwat.append(_n)
log('water bodies (texels, largest first): %s' % sorted(_nwat, reverse=True)[:6])
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
