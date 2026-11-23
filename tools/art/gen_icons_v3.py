"""Plinky icons v3: clean geometry, exact symmetry, 45 degree and 2:1 diagonals only.
Writes assets/icons/<name>.png (16 px) and assets/icons/big/<name>.png (32 px), plus the two 4 frame menu sheets.
Run: python3 tools/art/gen_icons_v3.py   (needs Pillow).  Geometry lives in a 32 unit space (see pixel_kit.py)."""
import os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixel_kit import Sk

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'icons')


def star(sk, cx, cy, tips, inner):
    """Symmetric star polygon: `tips` points at radius list, alternating with `inner` radius."""
    import math
    pts = []
    n = len(tips)
    for i, r in enumerate(tips):
        a = -math.pi / 2 + i * 2 * math.pi / n
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
        b = a + math.pi / n
        pts.append((cx + inner * math.cos(b), cy + inner * math.sin(b)))
    return sk.poly(pts)


def cash(sk):
    coin = sk.circle(16, 16, 13)
    sk.body(coin, 5, 7, 6)
    sk.fill(sk.circle(16, 16, 10) - sk.circle(16, 16, 9) if sk.S == 32 else set(), 6)
    mark = sk.rect(14, 8, 18, 24) | sk.rect(10, 8, 22, 10) | sk.rect(10, 22, 22, 24)
    sk.fill(mark, 6)
    sk.outline()


def mult(sk):
    x = sk.line((8, 8), (24, 24), 5) | sk.line((24, 8), (8, 24), 5)
    sk.body(x, 4, 7, 2) if sk.S >= 32 else sk.fill(x, 4)
    sk.outline()


def reb(sk):
    ring = (sk.circle(16, 18, 10) - sk.circle(16, 18, 6)) - sk.rect(16, 0, 32, 18)
    head = sk.poly([(14, 4), (14, 16), (26, 10)])
    sk.body(ring, 3, 4, 2)
    sk.body(head, 5, 7, 6)
    if sk.S >= 32:                       # sprout in the middle: what a rebirth grows
        stem = sk.rect(15, 18, 17, 26)
        leaves = sk.poly([(17, 20), (23, 14), (23, 20)]) | sk.poly([(15, 22), (9, 16), (9, 22)])
        sk.fill(stem | leaves, 4)
    sk.outline()


def slag(sk):
    rock = sk.poly([(4, 22), (6, 14), (12, 8), (20, 8), (26, 14), (28, 22), (28, 24), (24, 28), (8, 28), (4, 24)])
    sk.body(rock, 6, 5, 1)
    crack = (sk.line((16, 8), (16, 14), 2) | sk.line((16, 14), (12, 18), 2) | sk.line((12, 18), (12, 26), 2)
             | sk.line((16, 14), (20, 18), 2) | sk.line((20, 18), (20, 22), 2) | sk.line((20, 22), (24, 26), 2))
    sk.fill(crack & rock, 5)
    if sk.S >= 32:
        sk.fill(sk.rect(15, 10, 17, 14) | sk.rect(11, 20, 13, 24) | sk.rect(19, 18, 21, 20), 7)
    sk.outline()


def prestige(sk):
    crown = sk.poly([(4, 24), (4, 8), (10, 14), (16, 6), (22, 14), (28, 8), (28, 24)])
    sk.body(crown, 5, 7, 6)
    band = sk.rect(4, 22, 28, 26)
    sk.body(band, 6, 5, 1)
    for gx in (10, 16, 22):
        sk.fill(sk.rect(gx - 1, 17, gx + 1, 19), 3)
    sk.outline()


def crit(sk):
    ring = sk.circle(16, 16, 11) - sk.circle(16, 16, 7)
    ticks = sk.rect(14, 2, 18, 9) | sk.rect(14, 23, 18, 30) | sk.rect(2, 14, 9, 18) | sk.rect(23, 14, 30, 18)
    sk.body(ring | ticks, 4, 7, 2)
    sk.fill(sk.circle(16, 16, 3), 5)
    sk.outline()


def crit_dmg(sk):
    s = star(sk, 16, 16, [14] * 8, 6) if False else None
    spikes = sk.poly([(16, 2), (20, 12), (30, 16), (20, 20), (16, 30), (12, 20), (2, 16), (12, 12)])
    diag = sk.poly([(16, 16), (26, 6), (20, 16), (26, 26), (16, 20), (6, 26), (12, 16), (6, 6)])
    sk.body(spikes | diag, 6, 5, 6)
    sk.fill(sk.circle(16, 16, 5), 5)
    sk.fill(sk.circle(16, 16, 3), 7)
    sk.outline()


def rate(sk):
    pad = sk.poly([(16, 18), (30, 24), (16, 30), (2, 24)])
    sk.body(pad, 4, 7, 2)
    arrow = sk.rect(13, 2, 19, 12) | sk.poly([(6, 12), (26, 12), (16, 24)])
    sk.body(arrow, 5, 7, 6)
    sk.outline()


def luck(sk):
    leaves = sk.circle(10, 10, 5) | sk.circle(22, 10, 5) | sk.circle(10, 22, 5) | sk.circle(22, 22, 5)
    if sk.S >= 32:
        leaves = leaves - (sk.rect(15, 0, 17, 32) | sk.rect(0, 15, 32, 17))      # the cross parts the four lobes
        sk.body(leaves | sk.circle(16, 16, 3), 3, 4, 2)
    else:                                                                       # at 16 px the lobes merge; a dark vein cross parts them
        leaves = sk.circle(10, 10, 6) | sk.circle(22, 10, 6) | sk.circle(10, 22, 6) | sk.circle(22, 22, 6)
        sk.body(leaves, 3, 4, 2)
        sk.fill(leaves & (sk.rect(15, 4, 17, 28) | sk.rect(4, 15, 28, 17)), 2)
    sk.fill(sk.line((17, 19), (27, 29), 3) & sk.rect(0, 0, 30, 30), 2)
    sk.outline()


def offline(sk):
    moon = sk.circle(14, 16, 12) - sk.circle(21, 12, 10)
    sk.body(moon, 5, 7, 6)
    sk.fill(sk.rect(22, 20, 24, 26) | sk.rect(20, 22, 26, 24), 7)
    sk.fill(sk.rect(26, 8, 28, 12) | sk.rect(24, 10, 30, 12) if False else sk.rect(26, 6, 28, 12) | sk.rect(24, 8, 30, 10), 7)
    sk.outline()


def rest(sk):
    """Deep Sleep: a pillow under a big Z."""
    pillow = sk.rect(4, 20, 28, 28)
    sk.body(pillow, 7, 7, 4)
    sk.fill(sk.rect(4, 20, 6, 28) | sk.rect(26, 20, 28, 28), 4)
    z = sk.rect(8, 4, 24, 8) | sk.line((24, 8), (8, 20), 5) | sk.rect(8, 16, 24, 20)
    sk.body(z & sk.rect(0, 0, 32, 20), 5, 7, 6)
    sk.outline()


def lore(sk):
    """Pad Lore: an open book, mirrored page to page."""
    left = sk.poly([(3, 8), (14, 10), (14, 27), (3, 25)])
    sk.body(sk.mirror(left), 7, 7, 4)
    sk.fill(sk.rect(15, 9, 17, 27), 6)
    for y in (13, 17, 21):
        sk.fill(sk.mirror(sk.rect(6, y, 12, y + 1)), 3)
    sk.fill(sk.mirror(sk.rect(3, 25, 14, 27)), 6)
    sk.outline()


def fortune(sk):
    """Lucky Streak: a horseshoe, open at the top, three nail holes down each arm."""
    shoe = sk.circle(16, 17, 12) - sk.circle(16, 17, 6) - sk.rect(10, 0, 22, 14)
    shoe = shoe | sk.rect(4, 5, 10, 17) & sk.circle(16, 17, 12) | sk.rect(22, 5, 28, 17) & sk.circle(16, 17, 12)
    shoe = shoe - sk.rect(10, 0, 22, 14)
    sk.body(shoe, 3, 4, 2)
    if sk.S >= 32:
        for y in (8, 14):
            sk.fill(sk.rect(6, y, 8, y + 2) | sk.rect(24, y, 26, y + 2), 1)
    sk.fill(sk.rect(4, 5, 10, 8) | sk.rect(22, 5, 28, 8), 7)
    sk.outline()


def walk(sk):
    boot = sk.poly([(8, 4), (18, 4), (18, 16), (28, 20), (28, 28), (6, 28), (6, 10)])
    sk.body(boot, 6, 5, 1)
    sk.fill(sk.rect(6, 24, 28, 28), 2)
    sk.fill(sk.rect(8, 6, 18, 8), 7)
    sk.outline()


def heat(sk):
    outer = sk.poly([(16, 2), (20, 10), (26, 16), (26, 24), (20, 30), (12, 30), (6, 24), (6, 16), (12, 10)])
    outer = outer | sk.poly([(22, 6), (26, 14), (24, 18), (20, 14)]) | sk.poly([(8, 12), (12, 16), (8, 20)])   # flicker tongues
    mid = sk.poly([(16, 10), (20, 14), (22, 22), (20, 26), (12, 26), (10, 22), (12, 14)])
    core = sk.poly([(16, 18), (19, 22), (19, 26), (13, 26), (13, 22)])
    sk.body(outer, 6, 5, 2)
    sk.fill(mid, 5)
    sk.fill(core, 7)
    sk.outline()


def mastery(sk):
    r1 = sk.poly([(6, 2), (14, 2), (18, 14), (12, 14)])
    r2 = sk.poly([(26, 2), (18, 2), (14, 14), (20, 14)])
    sk.body(r1, 2, 3, 1)
    sk.body(r2, 3, 4, 2)
    medal = sk.circle(16, 20, 10)
    sk.body(medal, 5, 7, 6)
    sk.fill(star(sk, 16, 20, [6] * 5, 3), 6)
    sk.outline()


def presses(sk):
    pad = sk.poly([(16, 14), (30, 21), (16, 28), (2, 21)])
    sk.body(pad, 4, 7, 2)
    sk.fill(sk.ellipse(16, 21, 6, 3), 3)
    sk.body(sk.rect(12, 4, 20, 14) | sk.circle(16, 14, 4), 5, 7, 6)
    sk.outline()


def clock(sk):
    face = sk.circle(16, 16, 13)
    sk.body(face, 7, 7, 4)
    sk.fill(sk.circle(16, 16, 13) - sk.circle(16, 16, 11), 3)
    sk.fill(sk.rect(15, 6, 17, 10) | sk.rect(15, 22, 17, 26) | sk.rect(6, 15, 10, 17) | sk.rect(22, 15, 26, 17), 3)
    sk.fill(sk.rect(15, 8, 17, 17) | sk.rect(15, 15, 23, 17), 2)
    sk.fill(sk.rect(14, 14, 18, 18), 6)
    sk.outline()


def stats_menu(sk, f=0):
    bump = [0, 0, 0]
    if f > 0:
        bump[(f - 1) % 3] = 2
    for n, x0 in enumerate((4, 12, 20)):
        h = [8, 14, 20][n] + bump[n]
        sk.body(sk.rect(x0, 26 - h, x0 + 8, 26), 3, 4, 2)
    sk.body(sk.rect(2, 26, 30, 28), 6, 5, 1)
    sk.outline()


def attrs_menu(sk, f=0):
    hexa = sk.poly([(16, 2), (28, 8), (28, 22), (16, 30), (4, 22), (4, 8)])
    sk.body(hexa, 3, 4, 2)
    bob = (0, -2, 0, 2)[f]
    arrow = sk.rect(13, 14 + bob, 19, 24 + bob) | sk.poly([(8, 16 + bob), (24, 16 + bob), (16, 6 + bob)])
    sk.body(arrow, 5, 7, 6)
    sk.outline()


ICONS = {'cash': cash, 'mult': mult, 'reb': reb, 'slag': slag, 'prestige': prestige, 'crit': crit, 'crit_dmg': crit_dmg,
         'rate': rate, 'luck': luck, 'offline': offline, 'walk': walk, 'heat': heat, 'mastery': mastery,
         'presses': presses, 'clock': clock, 'rest': rest, 'lore': lore, 'fortune': fortune, 'stats_menu': stats_menu, 'attrs_menu': attrs_menu}


def render(fn, size, **kw):
    sk = Sk(size)
    fn(sk, **kw)
    return sk.image()


if __name__ == '__main__':
    os.makedirs(os.path.join(OUT, 'big'), exist_ok=True)
    for name, fn in ICONS.items():
        render(fn, 16).save(os.path.join(OUT, name + '.png'))
        render(fn, 32).save(os.path.join(OUT, 'big', name + '.png'))
    for name, fn in (('stats_menu', stats_menu), ('attrs_menu', attrs_menu)):
        for size, folder in ((16, ''), (32, 'big')):
            sheet = Image.new('RGBA', (size * 4, size), (0, 0, 0, 0))
            for f in range(4):
                sheet.paste(render(fn, size, f=f), (f * size, 0))
            sheet.save(os.path.join(OUT, folder, name + '_sheet.png'))
    print(len(ICONS), 'icons')
