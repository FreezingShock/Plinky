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

# Main route: S -> Gatehouse Green -> fork W (Heronmere) / E (Thistle Rise) -> Old Oak Crossing -> N fork -> Emberwatch.
PATH_MAIN = [(760, 716), (760, 676), (750, 640), (744, 600), (756, 560), (772, 520), (770, 486), (762, 454), (752, 420), (756, 386), (770, 350), (766, 310), (760, 268)]
PATH_WEST = [(750, 640), (700, 640), (630, 628), (570, 640), (520, 618), (500, 588), (540, 560), (600, 540), (680, 516), (772, 520)]
PATH_EAST = [(744, 600), (830, 612), (900, 600), (960, 580), (1030, 566), (1094, 550), (1090, 536), (1060, 520), (990, 500), (900, 490), (770, 486)]   # the tip now ends at the windmill's south door (1090, 520), so the fold leads somewhere
# Only the main road runs north: to the Ember gate, top middle. The side trails stop short of the mountainside.
# West trail: off the east side of the west road, north of the lake and along its north shore, to the Westmere pads on the west bank.
PATH_WM = [(600, 540), (590, 470), (540, 452), (470, 440), (400, 444), (336, 486)]
PATHS = [PATH_MAIN, PATH_WEST, PATH_EAST, PATH_WM]
# Path hierarchy, parallel to PATHS: a road (the main route), a lane (the forks to the districts) or a trail (the side
# track). gen_larkmoor.py spaces the lanterns by tier: roads closest, lanes sparser, trails only a pair at the ends.
PATH_TIER = ['road', 'lane', 'lane', 'trail']
# Land lobes: the island's radius grows by amp * R around angle a (uv angle; -135 deg is screen up, 0 is screen down-right).
# They give the new north and bottom-right land its shape. Width w is in radians.
LOBES = [(-135.0, 0.20, 0.55), (0.0, 0.16, 0.50)]

# Water: a big lake in the west, a mere in the north-east, a stream that cuts the middle (bridge on the main route).
LAKE = dict(c=(470, 520), rx=118, ry=60)
MERE = dict(c=(1120, 392), rx=70, ry=36)
STREAM = [(430, 330), (520, 372), (610, 430), (700, 452), (800, 458), (900, 450), (990, 438), (1060, 420)]
BRIDGE = (762, 454)           # where the main path crosses the stream

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
# common and uncommon rows (Sprout at Heronmere, Clover on the south lake shore) open first, then Thistle, Heather,
# Foxglove and Starbloom. Pad 1 of each row is the end nearest the road, so its row_index 0 plate is the one the walker meets first.
# The Clover row is the fifth entry, so pad_buttons order still lines up, but it stands by the Heronmere lake path, not in
# Cairnfold's own centre (the area list in content/areas says Heronmere for it). Both rows sit on walkable ground. Lanternwood has none.
DISTRICTS = [
    dict(id='green', name='Gatehouse Green', c=(760, 640), pads=curve_row([(816, 656), (856, 662), (896, 654), (936, 640)], 5),
         note='Arrival lawn. The Thistle row (Sunlight to Thistle Down), lanterns, a signpost.'),
    dict(id='heronmere', name='Heronmere', c=(520, 580), pads=curve_row([(716, 664), (676, 660), (636, 656), (598, 650)], 5),
         note='West lake with reed shores and a little jetty. The Sprout row runs across the open grass between the main path and the lake, well in from the arrival gate; the Clover row lines the south shore.'),
    dict(id='oak', name='Old Oak Crossing', c=(760, 470), pads=curve_row([(806, 540), (846, 548), (886, 552), (926, 548)], 5),
         note='The hub. A great old oak, the footbridge over the stream, a fork north. The Heather row.'),
    dict(id='thistle', name='Thistle Rise', c=(1030, 560), pads=curve_row([(990, 608), (1030, 612), (1066, 604), (1100, 586)], 5),
         note='East rolling flower fields. Windmill on the rise. The Foxglove row.'),
    dict(id='cairnfold', name='Cairnfold', c=(580, 330), pads=curve_row([(556, 662), (515, 648), (474, 628), (440, 602)], 5),
         note='Rocky foothills, glowing crystals, a ring of standing stones. Its Clover row sits on the Heronmere south shore, pad 1 nearest the road.'),
    dict(id='lanternwood', name='Lanternwood', c=(960, 330), pads=[],
         note='Pine wood strung with lanterns, a mere beyond the trees.'),
    dict(id='emberwatch', name='Emberwatch', c=(760, 310), pads=curve_row([(806, 350), (830, 338), (858, 334)], 3),
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
    dict(id='ember_watchtower', kind='tower', at=(800, 250)),       # beside the Emberwatch gate, on its wall
]
# Tall-prop groves: kind, centre, radius, count
GROVES = [
    ('oak', (640, 590), 60, 4), ('oak', (960, 690), 60, 4), ('oak', (1180, 480), 70, 5), ('oak', (400, 460), 40, 3),
    ('pine', (1040, 330), 70, 14), ('pine', (1120, 330), 60, 8), ('pine', (420, 380), 60, 6), ('pine', (960, 250), 60, 6),
    ('bush', (700, 560), 70, 6), ('bush', (900, 620), 70, 6), ('bush', (640, 420), 60, 5), ('bush', (880, 420), 60, 5),
    ('rock', (580, 300), 60, 5), ('rock', (480, 300), 50, 3), ('rock', (1200, 400), 60, 4), ('rock', (760, 360), 50, 3),
    ('crystals', (520, 340), 40, 2), ('crystals', (640, 296), 40, 2), ('crystals', (1100, 300), 40, 1),
    ('oak', (1150, 620), 45, 3), ('bush', (1110, 720), 40, 4),                  # new bottom-right land
    ('rock', (470, 250), 40, 2), ('pine', (440, 230), 40, 3),                   # new north-west land
]


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
PAD_CLEAR = 24.8   # 8 texels more than the old 20.6 (authored), for the widened paths (map thread)


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
    global W, H, OX, OY, N, CU, CV, R, PLAY, SPAWN, HOLLOW_GATE, EMBER_GATE, BRIDGE, PAD_CLEAR, GROVES
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
    for d in DISTRICTS:
        d['c'] = sc(d['c']); d['pads'] = [sc(q) for q in d['pads']]
    for lm in LANDMARKS: lm['at'] = sc(lm['at'])
    GROVES[:] = [(kind, sc(c), rad * S, round(n * S * S)) for kind, c, rad, n in GROVES]   # full density; world/larkmoor_scene.gd loads them by chunk
    PAD_CLEAR = PAD_CLEAR * S

_apply_scale()
