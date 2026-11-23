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
    s.fill(s.line((16, 22), (23, 30), 2), DEEPG)
    lobes = s.circle(10, 12, 6) | s.circle(22, 12, 6) | s.circle(16, 21, 6) | s.rect(10, 12, 22, 20)
    s.body(lobes, b, l, d)
    s.fill(s.line((16, 16), (16, 8), 2) | s.line((16, 16), (10, 20), 2) | s.line((16, 16), (22, 20), 2), d)  # veins


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
    s.fill(s.line((6, 30), (24, 4), 2), DEEPG)
    for (x, y, dx) in [(20, 8, 1), (16, 14, -1), (22, 14, 1), (12, 20, -1), (18, 22, 1), (8, 26, -1), (14, 28, 1)]:
        s.fill(s.rect(x if dx > 0 else x - 4, y, x + 4 if dx > 0 else x, y + 2), GREEN)       # pedicel
        bx = x + 5 * dx
        bell = s.ellipse(bx, y + 4, 3, 4) | s.rect(bx - 3, y + 6, bx + 3, y + 8)
        s.body(bell, b, l, d)
        s.fill(s.rect(bx - 2, y + 7, bx + 2, y + 8), d)
    s.fill(s.circle(24, 4, 2), l)


def foxglove_bell(s):
    d, b, l = ramp('foxglove_bell')
    s.fill(s.line((4, 30), (18, 2), 2), DEEPG)
    s.fill(s.poly([(6, 28), (2, 22), (8, 24)]) | s.poly([(8, 30), (16, 26), (10, 24)]), GREEN)
    for cx, cy, k in [(21, 2, 0.5), (22, 9, 0.7), (14, 17, 1.0)]:
        top = s.ellipse(cx, cy, 5 * k, 5 * k)
        flare = s.poly([(cx - 5 * k, cy), (cx + 5 * k, cy), (cx + 8 * k, cy + 9 * k), (cx - 8 * k, cy + 9 * k)])
        s.body(top | flare, b, l, d)
        s.fill(s.ellipse(cx, cy + 9 * k, 7 * k, 2 * k), d)      # dark open mouth
        if k >= 1:
            for sx, sy in [(-3, 4), (2, 6), (-1, 9)]:
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
