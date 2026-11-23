"""Meadow material icons: Dewdrop, Clover Leaf, Thistle Down, Heather Sprig, Foxglove Bell, Starbloom Petal.
Each wears its rarity colour (Common white .. Mythic pink) so a glance at the icon tells the tier.
Run: python3 tools/art/gen_materials.py   (needs Pillow). Writes assets/icons/<id>.png (16 px) and assets/icons/big/<id>.png (32 px)."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixel_kit as K

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'icons')
RAMPS = {  # id -> (deep, base, light) in the rarity colour
    'dewdrop': ('#7d93b0', '#dbe8f2', '#ffffff'),
    'clover_leaf': ('#1f7a35', '#55e060', '#c4ffb0'),
    'thistle_down': ('#24249a', '#5577ff', '#b4c8ff'),
    'heather_sprig': ('#5a0a66', '#b040c0', '#efa8f6'),
    'foxglove_bell': ('#a85a00', '#ffaa00', '#ffe68a'),
    'starbloom_petal': ('#8a2a8a', '#ff66e8', '#ffd0fa'),
}
INK, SHADOW, DEEPG, GREEN, LIME, CREAM, EARTH, PAPER = range(8)


def ramp(name):
    d, b, l = RAMPS[name]
    base = len(K.RGB)
    for h in (d, b, l):
        K.RGB.append(tuple(int(h[k:k + 2], 16) for k in (1, 3, 5)) + (255,))
    return base, base + 1, base + 2


def dewdrop(s):
    d, b, l = ramp('dewdrop')
    leaf = s.ellipse(16, 26, 11, 4)
    s.body(leaf, GREEN, LIME, DEEPG)
    s.fill(s.rect(15, 24, 17, 28) & leaf, DEEPG)  # midrib
    drop = s.circle(16, 18, 8) | s.poly([(16, 2), (9, 14), (23, 14)])
    s.body(drop, b, l, d)
    s.fill(s.ellipse(12, 17, 2, 4), l)   # glint
    s.fill(s.rect(11, 22, 13, 24), PAPER)


def clover_leaf(s):
    d, b, l = ramp('clover_leaf')
    s.fill(s.rect(15, 12, 17, 26) | s.line((16, 25), (22, 30), 2), DEEPG)          # stem shows through the lower gap
    for cx, cy, dx, dy in [(10, 8, -1, -1), (22, 8, 1, -1), (10, 20, -1, 1), (22, 20, 1, 1)]:
        leaf = s.circle(cx, cy, 5)
        s.body(leaf, b, l, d)
        s.fill(s.line((cx - dx * 3, cy - dy * 3), (cx + dx * 2, cy + dy * 2), 2) & leaf, d)   # vein from the centre outward

def thistle_down(s):
    d, b, l = ramp('thistle_down')
    s.fill(s.rect(15, 24, 17, 32), DEEPG)
    s.fill(s.poly([(8, 24), (10, 28), (16, 26), (22, 28), (24, 24)]), GREEN)
    cup = s.ellipse(16, 22, 8, 5)
    s.body(cup, GREEN, LIME, DEEPG)
    for x in (10, 14, 18, 22):  # scale ticks
        s.fill(s.rect(x - 1, 21, x + 1, 23), DEEPG)
    spikes = [[(8, 20), (6, 8), (13, 18)], [(12, 18), (13, 4), (17, 18)], [(15, 18), (20, 4), (21, 18)], [(19, 18), (26, 8), (24, 20)]]
    for t in spikes:
        s.body(s.poly(t), b, l, d)
    s.fill(s.circle(5, 5, 2) | s.circle(27, 6, 2) | s.circle(22, 2, 1), PAPER)  # drifting down


def heather_sprig(s):
    d, b, l = ramp('heather_sprig')
    s.fill(s.rect(15, 6, 17, 30), DEEPG)                                                   # upright stem
    s.fill(s.poly([(15, 30), (6, 27), (14, 27)]) | s.poly([(17, 30), (26, 27), (18, 27)]), GREEN)   # base leaves
    s.body(s.circle(16, 4, 3), b, l, d)                                                    # top bud
    for y, side in [(8, -1), (13, 1), (18, -1), (23, 1)]:
        bx = 16 + 7 * side
        s.fill(s.rect(min(16, bx), y, max(16, bx) + 1, y + 2), GREEN)                      # pedicel
        bell = s.ellipse(bx, y + 4, 2.5, 3) | s.rect(bx - 3, y + 5, bx + 3, y + 8)
        s.body(bell, b, l, d)
        s.fill(s.rect(bx - 2, y + 7, bx + 2, y + 8), d)                                    # mouth


def foxglove_bell(s):
    d, b, l = ramp('foxglove_bell')
    s.fill(s.rect(15, 4, 17, 30), DEEPG)
    s.fill(s.poly([(15, 30), (6, 26), (14, 26)]) | s.poly([(17, 30), (26, 27), (18, 26)]), GREEN)
    s.body(s.ellipse(16, 4, 3, 3), b, l, d)                                                # top bud
    for cx, cy, k in [(9, 16, 0.85), (23, 8, 0.75)]:
        s.fill(s.rect(min(cx, 16), cy - 1, max(cx, 16), cy + 1), DEEPG)                    # pedicel
        top = s.ellipse(cx, cy + 2 * k, 4 * k, 5 * k)
        flare = s.poly([(cx - 4 * k, cy + 3 * k), (cx + 4 * k, cy + 3 * k), (cx + 8 * k, cy + 12 * k), (cx - 8 * k, cy + 12 * k)])
        s.body(top | flare, b, l, d)
        s.fill(s.ellipse(cx, cy + 11.5 * k, 9 * k, 3.6 * k), l)                            # lit flared lip
        s.fill(s.ellipse(cx, cy + 12 * k, 6.5 * k, 2.4 * k), d)                            # dark open mouth
        for sx, sy in [(-2, 5), (2, 7)]:
            s.fill(s.rect(cx + sx * k - 1, cy + sy * k - 1, cx + sx * k + 1, cy + sy * k + 1), d)


def starbloom_petal(s):
    d, b, l = ramp('starbloom_petal')
    star = s.poly([(16, 2), (20, 12), (30, 16), (20, 20), (16, 30), (12, 20), (2, 16), (12, 12)])
    s.body(star, b, l, d)
    s.fill(s.circle(16, 16, 3), l)
    s.fill(s.rect(15, 15, 17, 17), PAPER)
    s.fill(s.rect(26, 4, 28, 10) | s.rect(24, 6, 30, 8), PAPER)  # sparkle


ICONS = [('dewdrop', dewdrop), ('clover_leaf', clover_leaf), ('thistle_down', thistle_down),
         ('heather_sprig', heather_sprig), ('foxglove_bell', foxglove_bell), ('starbloom_petal', starbloom_petal)]


def main():
    os.makedirs(os.path.join(OUT, 'big'), exist_ok=True)
    for name, fn in ICONS:
        for size, folder in ((16, OUT), (32, os.path.join(OUT, 'big'))):
            s = K.Sk(size)
            fn(s)
            s.outline()
            s.image().save(os.path.join(folder, name + '.png'))
    extra = os.path.join(OUT, 'materials')
    os.makedirs(extra, exist_ok=True)
    for name, fn in ICONS:
        for size in (8, 12, 16, 24, 32):
            s = K.Sk(size)
            fn(s)
            s.outline()
            s.image().save(os.path.join(extra, '%s_%d.png' % (name, size)))
    print('wrote', len(ICONS), 'icons x 2 sizes')


if __name__ == '__main__':
    main()
