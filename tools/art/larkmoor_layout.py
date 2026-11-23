"""Larkmoor (the big meadow past the onboarding gate): layout data in screen coordinates of the big
1520x920 world frame. Shared by gen_larkmoor.py (renders the scene) and larkmoor_map.py (layout mockup).
Everything here is plain data. Screen coords are (sx, sy) at ground level, projection as zone 1:
screen = (OX + u - v, OY + (u + v) / 2 - h)."""
W, H = 1520, 920
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
PATH_EAST = [(744, 600), (830, 612), (900, 600), (960, 580), (1030, 566), (1100, 548), (1060, 520), (990, 500), (900, 490), (770, 486)]
PATH_NW = [(752, 420), (700, 384), (640, 362), (590, 340), (550, 318)]
PATH_NE = [(770, 350), (820, 346), (880, 336), (940, 326), (1000, 316), (1040, 300)]
PATHS = [PATH_MAIN, PATH_WEST, PATH_EAST, PATH_NW, PATH_NE]

# Water: a big lake in the west, a mere in the north-east, a stream that cuts the middle (bridge on the main route).
LAKE = dict(c=(470, 520), rx=118, ry=60)
MERE = dict(c=(1120, 392), rx=70, ry=36)
STREAM = [(430, 330), (520, 372), (610, 430), (700, 452), (800, 458), (900, 450), (990, 438), (1060, 420)]
BRIDGE = (762, 454)           # where the main path crosses the stream

# Districts: name, centre, pads (screen coords), landmark. Pad order = order in ZoneDef.pad_buttons.
DISTRICTS = [
    dict(id='green', name='Gatehouse Green', c=(760, 640), pads=[(716, 664), (810, 648)],
         note='Arrival lawn. Two starter pads either side of the road, lanterns, a signpost.'),
    dict(id='heronmere', name='Heronmere', c=(520, 580), pads=[(560, 640), (448, 600)],
         note='West lake with reed shores. Pads on the shoreline, a little jetty.'),
    dict(id='thistle', name='Thistle Rise', c=(1030, 560), pads=[(1020, 590), (940, 536)],
         note='East rolling flower fields. Windmill on the rise.'),
    dict(id='oak', name='Old Oak Crossing', c=(760, 470), pads=[(716, 470)],
         note='The hub. A great old oak, the footbridge over the stream, a fork north.'),
    dict(id='cairnfold', name='Cairnfold', c=(580, 330), pads=[(612, 372)],
         note='Rocky foothills, glowing crystals, a ring of standing stones.'),
    dict(id='lanternwood', name='Lanternwood', c=(960, 330), pads=[(930, 350)],
         note='Pine wood strung with lanterns, a mere beyond the trees.'),
    dict(id='emberwatch', name='Emberwatch', c=(760, 310), pads=[(716, 316)],
         note='Last plaza before the quarry. The far gate sits in the cliff.'),
]
LANDMARKS = [
    dict(id='elder_oak', kind='elder_oak', at=(790, 444)),
    dict(id='windmill', kind='windmill', at=(1090, 520)),
    dict(id='standing_stones', kind='stones', at=(540, 306)),
    dict(id='jetty', kind='jetty', at=(476, 566)),
    dict(id='signpost', kind='sign', at=(790, 628)),
]
# Tall-prop groves: kind, centre, radius, count
GROVES = [
    ('oak', (640, 590), 60, 4), ('oak', (880, 640), 60, 4), ('oak', (1180, 480), 70, 5), ('oak', (400, 460), 40, 3),
    ('pine', (980, 340), 80, 14), ('pine', (1120, 330), 60, 8), ('pine', (420, 380), 60, 6), ('pine', (900, 280), 60, 6),
    ('bush', (700, 560), 70, 6), ('bush', (860, 580), 70, 6), ('bush', (640, 420), 60, 5), ('bush', (880, 420), 60, 5),
    ('rock', (580, 300), 60, 5), ('rock', (480, 300), 50, 3), ('rock', (1200, 400), 60, 4), ('rock', (760, 360), 50, 3),
    ('crystals', (520, 340), 40, 2), ('crystals', (640, 296), 40, 2), ('crystals', (1100, 300), 40, 1),
]
