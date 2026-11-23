"""Ledger icons: one per achievement category, each in its category colour, at 8, 12, 16, 24 and 32 px, plus the
32 px gallery tile (menu_ledger) in meadow palette indices. Geometry only, so every size comes from the same drawing.
Run: python3 tools/art/gen_ledger.py  (needs Pillow). Writes assets/icons/ledger/<category>_<size>.png,
assets/icons/ledger/locked_<size>.png and assets/icons/big/menu_ledger.png."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixel_kit as K

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'icons')
OUT = os.path.join(ROOT, 'ledger')
RAMPS = {  # category -> (deep, base, light). Bases match LedgerPanel.CATEGORY_COLORS.
    'presses': ('#9a7a14', '#f2c94c', '#fff0b0'),
    'meadow': ('#2f8a42', '#7be08a', '#d2ffd6'),
    'streaks': ('#a8403a', '#ff7f6e', '#ffd2c8'),
    'relics': ('#6a2a9a', '#c77dff', '#ecd2ff'),
    'rebirth': ('#a02a66', '#ff6fae', '#ffd0e6'),
    'growth': ('#2a5a9a', '#55aaff', '#c4e2ff'),
    'quarry': ('#9a3a14', '#e8643c', '#ffc0a0'),
    'journey': ('#2a7a8a', '#6fd6e8', '#d0f6ff'),
    'locked': ('#2a2f3a', '#4a5262', '#7a8496'),
}
INK, SHADOW, DEEPG, GREEN, LIME, CREAM, EARTH, PAPER = range(8)


def ramp(name):
    d, b, l = RAMPS[name]
    base = len(K.RGB)
    for h in (d, b, l):
        K.RGB.append(tuple(int(h[k:k + 2], 16) for k in (1, 3, 5)) + (255,))
    return base, base + 1, base + 2


def presses(s):  # a pad with a pressed cap and spark lines
    d, b, l = ramp('presses')
    s.body(s.ellipse(16, 22, 13, 7), d, b, SHADOW)
    s.body(s.ellipse(16, 18, 10, 6), b, l, d)
    s.fill(s.ellipse(13, 16, 4, 2), l)
    s.fill(s.rect(15, 4, 17, 8) | s.rect(7, 8, 9, 12) | s.rect(23, 8, 25, 12), l)


def meadow(s):  # a sprout with two leaves
    d, b, l = ramp('meadow')
    s.fill(s.rect(15, 14, 17, 28), d)
    s.fill(s.ellipse(16, 28, 9, 2), EARTH)
    s.body(s.poly([(15, 18), (4, 8), (14, 8), (16, 14)]), b, l, d)
    s.body(s.poly([(17, 14), (18, 4), (28, 6), (26, 16), (17, 18)]), b, l, d)
    s.fill(s.line((17, 16), (25, 8), 2) & s.poly([(17, 14), (18, 4), (28, 6), (26, 16), (17, 18)]), d)


def streaks(s):  # three linked pads in a row
    d, b, l = ramp('streaks')
    s.fill(s.rect(8, 15, 24, 17), d)
    for cx in (6, 16, 26):
        s.body(s.circle(cx, 16, 5), b, l, d)
        s.fill(s.rect(cx - 1, 15, cx + 1, 17), PAPER)
    s.fill(s.rect(4, 4, 6, 8) | s.rect(14, 4, 16, 8) | s.rect(24, 4, 26, 8), l)


def relics(s):  # a cut gem
    d, b, l = ramp('relics')
    gem = s.poly([(8, 4), (24, 4), (30, 12), (16, 30), (2, 12)])
    s.body(gem, b, l, d)
    s.fill(s.poly([(2, 12), (30, 12), (16, 30)]) & s.rect(0, 12, 32, 32), b)
    s.fill(s.rect(2, 12, 30, 14), l)
    s.fill(s.line((11, 12), (16, 4), 2) | s.line((21, 12), (16, 4), 2) | s.line((11, 12), (16, 26), 2) | s.line((21, 12), (16, 26), 2), d)
    s.fill(s.rect(6, 6, 9, 8), PAPER)


def rebirth(s):  # a ring of growth with an arrow head, a sprout inside
    d, b, l = ramp('rebirth')
    ring = s.circle(16, 16, 13) - s.circle(16, 16, 8)
    ring -= s.rect(16, 0, 32, 10)
    s.body(ring, b, l, d)
    s.body(s.poly([(18, 0), (30, 6), (18, 12)]), l, PAPER, b)
    s.fill(s.rect(15, 14, 17, 24), d)
    s.fill(s.ellipse(12, 15, 3, 2), l)
    s.fill(s.ellipse(20, 17, 3, 2), l)


def growth(s):  # climbing bars with an arrow
    d, b, l = ramp('growth')
    for i, h in enumerate((8, 14, 20, 26)):
        x = 2 + i * 7
        s.body(s.rect(x, 30 - h, x + 6, 30), b, l, d)
    s.body(s.poly([(18, 2), (30, 2), (30, 14), (26, 10), (20, 16), (16, 12), (22, 6)]), l, PAPER, b)


def quarry(s):  # a flame over a slag heap
    d, b, l = ramp('quarry')
    s.body(s.poly([(2, 30), (8, 22), (14, 26), (20, 20), (30, 30)]), SHADOW, DEEPG, INK)
    flame = s.poly([(16, 2), (24, 12), (26, 20), (22, 26), (10, 26), (6, 20), (8, 12), (12, 14)])
    s.body(flame, b, l, d)
    s.fill(s.poly([(16, 12), (21, 20), (19, 25), (13, 25), (11, 20)]), l)
    s.fill(s.poly([(16, 18), (18, 22), (16, 25), (14, 22)]), PAPER)


def journey(s):  # a signpost with two arrows
    d, b, l = ramp('journey')
    s.fill(s.rect(15, 4, 17, 30), EARTH)
    s.fill(s.rect(10, 28, 22, 30), DEEPG)
    s.body(s.poly([(17, 6), (27, 6), (31, 10), (27, 14), (17, 14)]), b, l, d)
    s.body(s.poly([(15, 16), (5, 16), (1, 20), (5, 24), (15, 24)]), b, l, d)


def locked(s):  # a padlock
    d, b, l = ramp('locked')
    s.fill(s.circle(16, 12, 8) - s.circle(16, 12, 4) - s.rect(8, 12, 24, 20), d)
    s.body(s.rect(6, 14, 26, 28), b, l, d)
    s.fill(s.circle(16, 20, 2) | s.rect(15, 20, 17, 25), SHADOW)


def menu_tile(s):  # an open book with a ribbon and a gold seal: the Ledger
    s.body(s.rect(4, 6, 28, 28), PAPER, PAPER, CREAM)
    s.fill(s.rect(4, 6, 16, 8) | s.rect(16, 6, 28, 8), GREEN)
    s.fill(s.rect(15, 6, 17, 28), DEEPG)
    for y in (11, 15, 19, 23):
        s.fill(s.rect(7, y, 13, y + 1), DEEPG)
        s.fill(s.rect(19, y, 25 - (y % 8 == 3) * 4, y + 1), DEEPG)
    s.body(s.circle(24, 24, 5), EARTH, CREAM, EARTH)
    s.fill(s.rect(23, 20, 25, 28) | s.rect(20, 23, 28, 25), CREAM)
    s.fill(s.rect(8, 2, 11, 12), LIME)


ICONS = [('presses', presses), ('meadow', meadow), ('streaks', streaks), ('relics', relics),
         ('rebirth', rebirth), ('growth', growth), ('quarry', quarry), ('journey', journey), ('locked', locked)]


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(os.path.join(ROOT, 'big'), exist_ok=True)
    for name, fn in ICONS:
        for size in (8, 12, 16, 24, 32):
            s = K.Sk(size)
            fn(s)
            s.outline()
            s.image().save(os.path.join(OUT, '%s_%d.png' % (name, size)))
    s = K.Sk(32)
    menu_tile(s)
    s.outline()
    s.image().save(os.path.join(ROOT, 'big', 'menu_ledger.png'))
    print('wrote', len(ICONS), 'category icons x 5 sizes and menu_ledger')


if __name__ == '__main__':
    main()
