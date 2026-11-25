"""Larkmoor (the big meadow past the onboarding gate): layout data in screen coordinates of the big
1520x920 world frame. Shared by gen_larkmoor.py (renders the scene) and larkmoor_map.py (layout mockup).
Everything here is plain data. Screen coords are (sx, sy) at ground level, projection as zone 1:
screen = (OX + u - v, OY + (u + v) / 2 - h)."""
import math
S = 2.0                        # frame scale: the world grows S in each direction (positions and island size); prop sizes stay
W, H = 1520, 920              # authored frame; _apply_scale() below grows it by S
PLAY = (130, 20, 1390, 830)    # camera and walker bounds: the island plus a margin of open water (x0, y0, x1, y1)
OX, OY = 760, 70
N = 820
CU = CV = 410.0
R = 372.0

# Where the walker arrives from the onboarding meadow, and the far gate to Zone 2.
SPAWN = (760, 676)
HOLLOW_GATE = (760, 716)      # arrival arch (decor + exit back to the onboarding meadow)
EMBER_GATE = (760, 268)       # the gate that leads on to Zone 2, set into the northern cliff

# Main route: S -> Thistledown Green -> fork W (Heronmere) / E (Foxglove Rise) -> Heather Hollow -> N fork -> Starbloom Terrace.
PATH_MAIN = [(760, 716), (760, 676), (750, 640), (744, 600), (756, 560), (772, 520), (770, 486), (762, 454), (752, 420), (756, 386), (770, 350), (766, 310), (760, 268)]
PATH_WEST = [(750, 640), (700, 640), (630, 628), (570, 640), (520, 618), (600, 600), (640, 580), (630, 558), (600, 540), (680, 516), (772, 520)]   # round the lake's south-east rim, clear of the water and the Reedgate row
PATH_EAST = [(744, 600), (830, 612), (900, 600), (960, 580), (1030, 566), (1094, 550), (1090, 536), (1060, 520), (990, 500), (900, 490), (770, 486)]   # the tip now ends at the windmill's south door (1090, 520), so the fold leads somewhere
# Only the main road runs north: to the Ember gate, top middle. The side trails stop short of the mountainside.
# West trail: off the east side of the west road, north of the lake and along its north shore, to the Westmere pads on the west bank.
PATH_WM = [(600, 540), (590, 470), (540, 452), (470, 440), (400, 444), (336, 486)]
# A narrow trail through the lighthouse grove (Nathan's yes, 2026-11-24): it leaves the west road at its bend (680, 516),
# runs through the grove's centre (640, 590) and ends at the lighthouse foot (596, 590), a landmark, so it is never a dead
# end. It stays off the Reedgate pads, which sit against the road's south side (a route south to the road broke their clearance).
PATH_GROVE = [(680, 516), (664, 548), (650, 582), (620, 590), (604, 590)]
PATHS = [PATH_MAIN, PATH_WEST, PATH_EAST, PATH_WM, PATH_GROVE]
# Path hierarchy, parallel to PATHS: a road (the main route), a lane (the forks to the districts) or a trail (the side
# track). gen_larkmoor.py spaces the lanterns by tier: roads closest, lanes sparser, trails only a pair at the ends.
PATH_TIER = ['road', 'lane', 'lane', 'trail', 'trail']
# Land lobes: the island's radius grows by amp * R around angle a (uv angle; -135 deg is screen up, 0 is screen down-right).
# They give the new north and bottom-right land its shape. Width w is in radians.
LOBES = [(-135.0, 0.20, 0.55), (0.0, 0.16, 0.50)]

# Water: one connected river. It leaves Heronmere's north-east shore, bends east through the middle and runs into the mere in
# the north-east, so the three bodies of water read as one system (no orphan puddles). The channel is about 13 texels wide, and
# the walker can jump it (world/texel_walker.gd: a jump may carry the walker over water, and landing in water pushes it to the bank).
# Control points for a smooth, meandering course; _catmull() densifies them below. The river crosses two paths: the main road
# (BRIDGE, the wide bridge) and the west trail (FOOT_CROSSING, a plank footbridge).
LAKE = dict(c=(470, 520), rx=118, ry=60)
MERE = dict(c=(1120, 392), rx=70, ry=36)
STREAM_CTRL = [(500, 512), (534, 506), (566, 500), (594, 488), (630, 476), (680, 466), (730, 460), (762, 456), (806, 462),
               (856, 458), (910, 446), (964, 436), (1016, 426), (1062, 410), (1100, 398)]
STREAM = []                   # filled from STREAM_CTRL once _catmull() exists (below)
BRIDGE = (762, 456)           # where the main path crosses the river
FOOT_CROSSING = (594, 487)    # where the west trail crosses the river

# Pad rows: a tier is a row of pads laid on a smooth curve (a Catmull-Rom spline through a few control points) that follows the
# ground beside a path. `curve_row(ctrl, n)` lists n pads from the first to the last, PAD_GAP apart along the curve (authored
# units; the whole world is then scaled by S, so 21 becomes 42 texels: a 28 wide plate and a 14 texel gap the walker can cross).
# The order is the order of the tier's pads in ZoneDef.pad_buttons, and the anchors come out in the order the districts are listed below.
PAD_GAP = 21.0


def _catmull(pts, k=24):
    p = [pts[0]] + list(pts) + [pts[-1]]
    out = []
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = p[i - 1], p[i], p[i + 1], p[i + 2]
        for j in range(k):
            t = j / k; t2 = t * t; t3 = t2 * t
            out.append(tuple(0.5 * ((2 * p1[c]) + (-p0[c] + p2[c]) * t + (2 * p0[c] - 5 * p1[c] + 4 * p2[c] - p3[c]) * t2
                                    + (-p0[c] + 3 * p1[c] - 3 * p2[c] + p3[c]) * t3) for c in (0, 1)))
    out.append(tuple(pts[-1]))
    return out


STREAM[:] = _catmull(STREAM_CTRL, 10)


def curve_row(ctrl, n, gap=PAD_GAP):
    """n points, `gap` apart (screen distance) along the spline through `ctrl`, the first at the start of the curve."""
    d = _catmull(ctrl)
    res = [d[0]]
    acc, need = 0.0, gap
    for a, b in zip(d, d[1:]):
        seg = math.hypot(b[0] - a[0], b[1] - a[1])
        while acc + seg >= need and len(res) < n and seg > 0:
            t = (need - acc) / seg
            a = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
            res.append(a)
            seg = math.hypot(b[0] - a[0], b[1] - a[1]); acc = 0.0
        acc += seg
        if len(res) >= n:
            break
    assert len(res) == n, 'curve too short for %d pads' % n
    return [(round(x), round(y)) for x, y in res]


# Districts: name, centre, pads (screen coords), landmark. Pads are six rows, listed in the order of their tiers. The
# common and uncommon rows (Sprout at Reedgate, Clover on the Heronmere south shore) open first, then Thistle, Heather,
# Foxglove and Starbloom. Pad 1 of each row is the end nearest the road, so its row_index 0 plate is the one the walker meets first.
# A district with a row takes its centre from the row (_lay_rows). Lanternwood and Cairnfold (the stones) have no pads, so
# their entries sit in the list without moving the pad order.
DISTRICTS = [
    dict(id='green', name='Thistledown Green', c=(760, 640), pads=curve_row([(816, 656), (856, 662), (896, 654), (936, 640)], 5),
         note='Arrival lawn. The Thistle row (Sunlight to Thistle Down), lanterns, a signpost.'),
    dict(id='reedgate', name='Reedgate', c=(670, 624), pads=curve_row([(716, 664), (676, 660), (636, 656), (598, 650)], 5),
         note='Where the west road leaves the main road for the lake, with the first reeds beside it. The Sprout row lines the road.'),
    dict(id='oak', name='Heather Hollow', c=(760, 470), pads=curve_row([(806, 540), (846, 548), (886, 552), (926, 548)], 5),
         note='The hub. A great old oak, the footbridge over the stream, a fork north. The Heather row.'),
    dict(id='thistle', name='Foxglove Rise', c=(1030, 560), pads=curve_row([(986, 640), (1026, 648), (1064, 646), (1100, 632)], 5),
         note='East rolling flower fields. Windmill on the rise. The Foxglove row.'),
    dict(id='heronmere', name='Heronmere', c=(540, 637), pads=curve_row([(556, 662), (515, 648), (474, 628), (440, 602)], 5),
         note='West lake with reed shores and a little jetty. The Clover row lines the road along the south shore, pad 1 nearest the arrival gate.'),
    dict(id='lanternwood', name='Lanternwood', c=(960, 330), pads=[],
         note='Pine wood strung with lanterns, a mere beyond the trees.'),
    dict(id='cairnfold', name='Cairnfold', c=(580, 330), pads=[],
         note='Rocky foothills, glowing crystals, a ring of standing stones. No pads.'),
    dict(id='emberwatch', name='Starbloom Terrace', c=(760, 310), pads=curve_row([(806, 350), (830, 338), (858, 334)], 3),
         note='Last plaza before the quarry. The Starbloom row, and the far gate set in the cliff.'),
    dict(id='westmere', name='Westmere', c=(332, 512), pads=curve_row([(296, 494), (326, 508), (352, 514)], 3),
         note='West bank of the lake, reached by the west trail. No gate. Three more Starbloom pads: the Starbloom row runs on here.'),
]
LANDMARKS = [
    dict(id='elder_oak', kind='elder_oak', at=(790, 444)),
    dict(id='windmill', kind='windmill', at=(1090, 520)),
    dict(id='standing_stones', kind='stones', at=(540, 306)),       # a ring of seven stones, grouped around its cairn
    dict(id='jetty', kind='jetty', at=(476, 566)),
    dict(id='signpost', kind='sign', at=(790, 628)),
    dict(id='gatehouse_tower', kind='tower', at=(728, 698)),        # flanks the arrival gate, as a gatehouse
    dict(id='lighthouse', kind='lighthouse', at=(596, 590)),
    dict(id='cairn_spire', kind='obelisk', at=(540, 306)),          # the cairn at the centre of the stone ring
    dict(id='great_lantern', kind='great_lantern', at=(978, 376)),
    dict(id='ember_watchtower', kind='tower', at=(805, 266)),       # the Emberwatch ruin: flat ground just east of the gate (was on the cliff at 800,250)
]
# Tall-prop groves: kind, centre, radius, count
GROVES = [
    ('oak', (640, 590), 60, 4), ('oak', (960, 690), 60, 4), ('oak', (1180, 480), 70, 5), ('oak', (400, 460), 40, 3),
    ('pine', (1040, 330), 70, 10), ('pine', (1120, 330), 60, 6), ('pine', (420, 380), 60, 6), ('pine', (960, 250), 60, 6),
    ('bush', (700, 560), 70, 6), ('bush', (900, 620), 70, 6), ('bush', (640, 420), 60, 5), ('bush', (880, 420), 60, 5),
    ('rock', (580, 300), 60, 5), ('rock', (480, 300), 50, 3), ('rock', (1200, 400), 60, 4), ('rock', (760, 360), 50, 3),
    ('crystals', (520, 340), 40, 2), ('crystals', (640, 296), 40, 2), ('crystals', (1100, 300), 40, 1),
    ('oak', (1150, 620), 45, 3), ('bush', (1110, 720), 40, 4),                  # new bottom-right land
    ('rock', (470, 250), 40, 2), ('pine', (440, 230), 40, 3),                   # new north-west land
    ('pine', (1190, 380), 40, 4), ('oak', (1010, 240), 50, 4), ('bush', (1150, 470), 40, 4),   # north-east candidates: the forest edge, and oaks and bushes at the watchtower grove's density
]


# The windmill farm (the cozy thread places its props there): the flower gardens keep out of this box. Authored units.
FARM_BOX = (960, 410, 1220, 630)


def _seg_dist(px, py, ax, ay, bx, by):
    vx, vy = bx - ax, by - ay; L2 = vx * vx + vy * vy or 1e-9
    t = max(0.0, min(1.0, ((px - ax) * vx + (py - ay) * vy) / L2))
    return math.hypot(px - (ax + vx * t), py - (ay + vy * t))


def dead_ends(tol=30.0 * S):
    """Every path must reach something: a gate, a pad, a landmark, or another path. Returns the (path index, end)
    pairs that reach nothing. gen_larkmoor.py refuses to build while this list is not empty."""
    anchors = [EMBER_GATE, HOLLOW_GATE] + [p for d in DISTRICTS for p in d['pads']] + [lm['at'] for lm in LANDMARKS]
    bad = []
    for i, pp in enumerate(PATHS):
        for end in (pp[0], pp[-1]):
            reached = any(math.hypot(end[0] - a[0], end[1] - a[1]) <= tol for a in anchors)
            for j, qq in enumerate(PATHS):
                if reached or j == i: continue
                reached = any(_seg_dist(end[0], end[1], qq[k][0], qq[k][1], qq[k + 1][0], qq[k + 1][1]) <= tol for k in range(len(qq) - 1))
            if not reached: bad.append((i, end))
    return bad


# ---- pads beside the path ----
# A pad plate is about 14 texels from its centre and a path rim is 6.6 more, so a pad needs about 21 texels of clear
# ground from every path (uv distance). PAD_NUDGE moves the pads that sat on or against a path onto the verge: each
# new spot is 24 to 34 texels off, in the same district. This table is the only place Larkmoor pads move.
PAD_NUDGE = {
    (534, 600): (540, 594), (622, 644): (622, 648), (796, 512): (806, 512), (1030, 580): (1032, 584),
    (1074, 558): (1074, 574), (546, 648): (544, 652), (502, 626): (500, 632), (792, 344): (800, 366),
}
PAD_CLEAR = 24.0   # texels (uv) from a path centre line to a plate centre: path half-width up to ~13 plus the plate's reach; rows sit at ROW_OFFSET (28)


def _to_uv(sx, sy):
    d = sx - OX; s = (sy - OY) * 2
    return (s + d) / 2.0, (s - d) / 2.0


def path_gap(p):
    """Uv distance from a screen point to the nearest path centre line."""
    pu, pv = _to_uv(*p)
    best = 1e9
    for pp in PATHS:
        uv = [_to_uv(*q) for q in pp]
        for k in range(len(uv) - 1):
            best = min(best, _seg_dist(pu, pv, uv[k][0], uv[k][1], uv[k + 1][0], uv[k + 1][1]))
    return best


def rows_off():
    """Pads that are not tight against a path (more than ROW_OFFSET + 6 from its centre line) or that overlap another plate.
    gen_larkmoor.py refuses to build while this list is not empty: every row hugs a path, parallel and easy to press."""
    bad = []
    allp = [p for d in DISTRICTS for p in d['pads']]
    for i, p in enumerate(allp):
        if path_gap(p) > ROW_OFFSET + 6:
            bad.append(('far from every path', p))
        for q in allp[i + 1:]:
            if abs(p[0] - q[0]) < 32 and abs(p[1] - q[1]) < 17:
                bad.append(('plates overlap', p, q))
    return bad


def pads_on_path():
    """Pads whose plate would touch a path. gen_larkmoor.py refuses to build while this list is not empty."""
    return [p for d in DISTRICTS for p in d['pads'] if path_gap(p) < PAD_CLEAR]


for _d in DISTRICTS:
    _d['pads'] = [PAD_NUDGE.get(tuple(p), tuple(p)) for p in _d['pads']]


# ---- the bigger frame ----
# Every position above is authored in the 1520x920 frame. _apply_scale() grows the whole world by S about the screen
# origin: that keeps the 2:1 projection exact (OX, OY, W, H, N, CU, CV, R and PLAY scale too). Sprites and voxel props
# keep their texel size, so grove counts scale by S squared to keep the same density. The scene loads props by chunk around
# the walker (world/larkmoor_scene.gd), which keeps the live node count under the 1350 ceiling.
def _apply_scale():
    global W, H, OX, OY, N, CU, CV, R, PLAY, SPAWN, HOLLOW_GATE, EMBER_GATE, BRIDGE, FOOT_CROSSING, PAD_CLEAR, GROVES
    def sc(p): return (p[0] * S, p[1] * S)
    W, H = round(W * S), round(H * S)
    OX, OY = OX * S, OY * S
    N = round(N * S)
    CU, CV, R = CU * S, CV * S, R * S
    PLAY = tuple(v * S for v in PLAY)
    SPAWN, HOLLOW_GATE, EMBER_GATE, BRIDGE = sc(SPAWN), sc(HOLLOW_GATE), sc(EMBER_GATE), sc(BRIDGE)
    for i, pp in enumerate(PATHS): PATHS[i] = [sc(q) for q in pp]
    LAKE['c'], MERE['c'] = sc(LAKE['c']), sc(MERE['c'])
    LAKE['rx'], LAKE['ry'] = LAKE['rx'] * S, LAKE['ry'] * S
    MERE['rx'], MERE['ry'] = MERE['rx'] * S, MERE['ry'] * S
    STREAM[:] = [sc(q) for q in STREAM]
    FOOT_CROSSING = sc(FOOT_CROSSING)
    for d in DISTRICTS:
        d['c'] = sc(d['c']); d['pads'] = [sc(q) for q in d['pads']]
    for lm in LANDMARKS: lm['at'] = sc(lm['at'])
    GROVES[:] = [(kind, sc(c), rad * S, round(n * S * S)) for kind, c, rad, n in GROVES]   # full density; world/larkmoor_scene.gd loads them by chunk

_apply_scale()


# ---- pad rows parallel to a path ----
# A row is n plates laid along a path, ROW_GAP apart (uv texels), on one side of it, ROW_OFFSET from the centre line: close
# enough to press as you walk by (the plate's edge a few texels off the path rim), never on it. The row follows the path's
# own bends, so it always runs parallel. ROWS (below) is filled in by tools/art/plan_rows.py, which searches every path for the
# stretch with the most open grass and keeps rows apart.
ROW_OFFSET = 28.0
ROW_GAP = 32.0
# row -> (candidate path indexes, forced side or 0, pad count, (x, y, radius) in authored units the row must stay near). Paths: 0 main road, 1 west road, 2 east loop, 3 Westmere trail.
ROW_PLAN = {
    'sprout': ([1], 0, 5, (680, 650, 70)), 'clover': ([1], 0, 5, (540, 625, 100)), 'foxglove': ([2], 0, 5, (940, 590, 110)),
    'thistle': ([0, 1, 2], 0, 5, (760, 640, 120)), 'heather': ([2, 0], 0, 5, (800, 500, 130)),
    'starbloom_n': ([0], 0, 3, (770, 330, 110)), 'starbloom_w': ([3], 0, 3, (332, 512, 120)),
}


def _from_uv(u, v):
    return (OX + u - v, OY + (u + v) / 2.0)


def path_length_uv(i):
    uv = [_to_uv(*q) for q in PATHS[i]]
    return sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(uv, uv[1:]))


def _at(uv, s):
    """(u, v, tx, ty) at arc length s along a uv polyline."""
    acc = 0.0
    for a, b in zip(uv, uv[1:]):
        seg = math.hypot(b[0] - a[0], b[1] - a[1])
        if seg > 0 and acc + seg >= s:
            t = (s - acc) / seg
            return a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, (b[0] - a[0]) / seg, (b[1] - a[1]) / seg
        acc += seg
    a, b = uv[-2], uv[-1]
    seg = math.hypot(b[0] - a[0], b[1] - a[1]) or 1.0
    return b[0], b[1], (b[0] - a[0]) / seg, (b[1] - a[1]) / seg


def row_pads(pidx, s0, side, n, off=None, gap=None):
    """n plate centres (screen coords) along path `pidx` from arc length s0, on `side` (+1 left of travel, -1 right) in uv.
    The plates are ROW_GAP apart along the OFFSET curve, so they stay evenly spaced round a bend."""
    off = ROW_OFFSET if off is None else off
    gap = ROW_GAP if gap is None else gap
    uv = [_to_uv(*q) for q in PATHS[pidx]]
    total = path_length_uv(pidx)
    dense = []
    s = s0
    while s <= total:
        u, v, tx, ty = _at(uv, s)
        dense.append((u + (-ty) * side * off, v + tx * side * off))
        s += 1.0
    out = [dense[0]]
    for q in dense[1:]:
        if math.hypot(q[0] - out[-1][0], q[1] - out[-1][1]) >= gap:   # straight-line gap, so a tight bend can't fold plates together
            out.append(q)
            if len(out) == n:
                break
    if len(out) < n:
        return []
    return [_from_uv(u, v) for u, v in out]


# row name -> (path index, start arc length, side, count), from tools/art/plan_rows.py
ROWS = {
    'sprout': (1, 54.0, 1, 5), 'clover': (1, 264.0, -1, 5), 'foxglove': (2, 174.0, 1, 5), 'thistle': (0, 402.0, 1, 5),
    'heather': (2, 852.0, -1, 5), 'starbloom_n': (0, 930.0, 1, 3), 'starbloom_w': (3, 569.0, 1, 3),
}
_ROW_OF = {'green': 'thistle', 'reedgate': 'sprout', 'oak': 'heather', 'thistle': 'foxglove', 'heronmere': 'clover',
           'emberwatch': 'starbloom_n', 'westmere': 'starbloom_w'}
_ROW_FROM = {'starbloom_w': 'wm'}   # pad 1 is the end nearest the road (the spawn), except the Westmere pads, nearest the trail's start


def _lay_rows():
    for d in DISTRICTS:
        key = _ROW_OF.get(d['id'])
        if key is None:
            continue
        pidx, s0, side, n = ROWS[key]
        pads = row_pads(pidx, s0, side, n)
        origin = PATHS[3][0] if _ROW_FROM.get(key) == 'wm' else SPAWN
        if math.hypot(pads[-1][0] - origin[0], pads[-1][1] - origin[1]) < math.hypot(pads[0][0] - origin[0], pads[0][1] - origin[1]):
            pads.reverse()
        d['pads'] = [(round(x), round(y)) for x, y in pads]
        d['c'] = (round(sum(p[0] for p in pads) / n), round(sum(p[1] for p in pads) / n))


_lay_rows()
