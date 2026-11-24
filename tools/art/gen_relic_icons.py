"""Relic icons, expansion set (PR: relic abilities). Every relic icon is drawn natively at 8, 12, 16, 24 and 32 px
with the geometry kit (tools/art/pixel_kit.py), so each size is its own drawing, never a scaled copy.
Writes assets/icons/relics/<id>.png (16 px) and assets/icons/relics/s<px>/<id>.png for 8, 12, 24 and 32.
Also writes a mock sheet (4x) for review when run with --sheet <path>.
Colours are literal hex here, not palette roles: relic art is object colour, rarity comes from the frame.
Run: python3 tools/art/gen_relic_icons.py [--sheet /path/to/sheet.png]   (needs Pillow)."""
import math
import os
import sys
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixel_kit import Sk

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'icons', 'relics')
INK = '#14161c'


class Kit(Sk):
    """Sk with literal colours: a fill value is a hex string, and 0 means ink (outline)."""

    def image(self):
        im = Image.new('RGBA', (self.S, self.S), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            if 0 <= x < self.S and 0 <= y < self.S:
                im.putpixel((x, y), rgba(INK if c == 0 else c))
        return im

    def drop(self, shape):
        for p in shape:
            self.px.pop(p, None)


def rgba(h):
    return tuple(int(h[k:k + 2], 16) for k in (1, 3, 5)) + (255,)


def star(sk, cx, cy, tips, inner):
    pts = []
    n = len(tips)
    for i, r in enumerate(tips):
        a = -math.pi / 2 + i * 2 * math.pi / n
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
        b = a + math.pi / n
        pts.append((cx + inner * math.cos(b), cy + inner * math.sin(b)))
    return sk.poly(pts)


def coin(sk, base, hi, lo):
    sk.body(sk.circle(16, 16, 12), base, hi, lo)
    sk.fill(sk.circle(16, 16, 8) - sk.circle(16, 16, 6.5), lo)
    sk.fill(sk.rect(15, 10, 17, 22), lo)
    sk.outline()


def pouch(sk, base, hi, lo):
    sk.body(sk.ellipse(16, 19, 10, 9), base, hi, lo)
    sk.fill(sk.poly([(11, 12), (21, 12), (18, 6), (14, 6)]), lo)
    sk.fill(sk.rect(14, 11, 18, 13), '#f2e6a0')
    sk.outline()


def ladybird(sk):
    sk.body(sk.circle(16, 18, 10), '#e0392f', '#ff9a8a', '#8a1510')
    sk.fill(sk.circle(16, 9, 4), INK)
    for cx, cy in ((12, 16), (20, 16), (16, 22)):
        sk.fill(sk.circle(cx, cy, 2), INK)
    sk.fill(sk.rect(15, 12, 17, 26), INK)
    sk.outline()


def chipped_bead(sk):
    sk.body(sk.circle(16, 16, 11), '#3fb8a8', '#b4f5e6', '#1f6b64')
    sk.fill(sk.circle(16, 16, 3), '#1f6b64')
    sk.drop(sk.poly([(20, 4), (30, 7), (24, 13)]))
    sk.outline()


def surge_drum(sk):
    sk.body(sk.rect(7, 12, 25, 24), '#c2403a', '#ff8a6a', '#7a1f1a')
    sk.body(sk.ellipse(16, 12, 9, 3.5), '#f6efd9', '#ffffff', '#b8a880')
    sk.fill(sk.rect(7, 16, 25, 17), '#f6efd9')
    sk.fill(sk.rect(7, 20, 25, 21), '#f6efd9')
    sk.outline()


def honey(sk):
    sk.body(sk.rect(9, 12, 23, 28), '#f0a31a', '#ffd86a', '#a8600c')
    sk.body(sk.rect(8, 8, 24, 12), '#8a5a33', '#c28a55', '#4a2e18')
    sk.fill(sk.rect(11, 17, 21, 23), '#f6efd9')
    sk.fill(sk.ellipse(22, 14, 2, 2), '#f0a31a')
    sk.outline()


def coal(sk):
    rock = sk.poly([(5, 22), (9, 11), (16, 7), (24, 10), (28, 19), (25, 27), (12, 28)])
    sk.body(rock, '#3a3a44', '#5c5c6a', '#1c1c24')
    sk.fill(sk.line((10, 14), (17, 19), 2) & rock, '#ff8a2a')
    sk.fill(sk.line((17, 19), (15, 26), 2) & rock, '#ff8a2a')
    sk.outline()


def lantern(sk, flame, flame_hi):
    sk.fill(sk.rect(15, 3, 17, 7), '#8a6a4a')
    sk.fill(sk.rect(13, 7, 19, 10), '#8a6a4a')
    sk.body(sk.rect(10, 10, 22, 27), '#5a4636', '#8a6a4a', '#2a1f18')
    sk.body(sk.rect(13, 13, 19, 25), flame, flame_hi, '#b33b12')
    sk.fill(sk.rect(15, 16, 17, 21), flame_hi)
    sk.fill(sk.rect(9, 26, 23, 29), '#8a6a4a')
    sk.outline()


def cog(sk):
    sk.body(sk.circle(16, 16, 10), '#d9a54a', '#fff0a8', '#8a5a1a')
    for r in ((13, 3, 19, 7), (13, 25, 19, 29), (3, 13, 7, 19), (25, 13, 29, 19)):
        sk.fill(sk.rect(*r), '#d9a54a')
    sk.fill(sk.circle(16, 16, 3.5), '#2a2118')
    sk.outline()


def ember(sk):
    sk.body(sk.circle(16, 18, 9), '#ff7a2a', '#ffc27a', '#b33b12')
    sk.fill(sk.circle(16, 18, 4), '#ffe27a')
    sk.fill(sk.rect(15, 5, 17, 8) | sk.rect(9, 8, 11, 10), '#ffc27a')
    sk.outline()


def magnet(sk):
    u = (sk.circle(16, 15, 11) - sk.circle(16, 15, 5)) - sk.rect(0, 15, 32, 32)
    sk.fill(u & sk.rect(0, 0, 16, 32), '#d33b3b')
    sk.fill(u & sk.rect(16, 0, 32, 32), '#3b6bd3')
    sk.fill(sk.rect(4, 13, 9, 17) | sk.rect(23, 13, 28, 17), '#c0c4d0')
    sk.outline()


def metronome(sk):
    sk.body(sk.poly([(11, 28), (21, 28), (18, 6), (14, 6)]), '#b5763a', '#e0a062', '#6e3f1a')
    sk.fill(sk.line((16, 26), (22, 10), 2), '#f2e6a0')
    sk.fill(sk.rect(19, 13, 25, 17), '#c0c4d0')
    sk.outline()


def echo_stone(sk):
    sk.body(sk.circle(16, 16, 12), '#8a93a6', '#c9d0dc', '#4a5263')
    sk.fill(sk.circle(16, 16, 8) - sk.circle(16, 16, 6.5), '#4a5263')
    sk.fill(sk.circle(16, 16, 2), '#c9d0dc')
    sk.outline()


def hourglass(sk):
    sk.fill(sk.rect(7, 3, 25, 6) | sk.rect(7, 26, 25, 29), '#8a5a33')
    sk.body(sk.poly([(8, 6), (24, 6), (17, 15), (15, 15)]), '#f0c040', '#fff0a8', '#a8600c')
    sk.body(sk.poly([(15, 17), (17, 17), (24, 26), (8, 26)]), '#f0c040', '#fff0a8', '#a8600c')
    sk.fill(sk.line((16, 15), (16, 17), 2), '#f0c040')
    sk.outline()


def starfall(sk):
    sk.body(star(sk, 16, 16, [13] * 5, 5.5), '#ffd84a', '#fff6b0', '#c58a12')
    sk.fill(sk.circle(16, 16, 2), '#f6efd9')
    sk.outline()


def obsidian(sk):
    sk.body(sk.poly([(16, 3), (24, 24), (16, 29), (8, 24)]), '#2b2538', '#6a5f86', '#120f1a')
    sk.fill(sk.line((16, 7), (14, 20), 2) & sk.poly([(16, 3), (24, 24), (16, 29), (8, 24)]), '#8a7fb0')
    sk.outline()


def ring(sk):
    sk.body(sk.circle(16, 16, 11) - sk.circle(16, 16, 6.5), '#c9d0dc', '#ffffff', '#7a8294')
    sk.outline()


def slab(sk):
    s = sk.poly([(9, 10), (16, 5), (23, 10), (23, 28), (9, 28)])
    sk.body(s, '#8fa2b8', '#d4e0ee', '#4a5a70')
    sk.fill(sk.rect(15, 11, 17, 23) | sk.rect(11, 15, 21, 17), '#4a5a70')
    sk.outline()


def eye(sk):
    sk.body(sk.ellipse(16, 16, 12, 7), '#f6efd9', '#ffffff', '#b8a880')
    sk.fill(sk.circle(16, 16, 5), '#2f8f8a')
    sk.fill(sk.circle(16, 16, 2), INK)
    sk.outline()


def crown(sk):
    sk.body(sk.poly([(5, 24), (4, 10), (11, 16), (16, 6), (21, 16), (28, 10), (27, 24)]), '#f0c040', '#fff0a8', '#a8600c')
    sk.fill(sk.rect(5, 22, 27, 26), '#a8600c')
    sk.fill(sk.circle(16, 18, 2), '#ff5a5a')
    sk.fill(sk.circle(10, 18, 1.5), '#5ab8ff')
    sk.fill(sk.circle(22, 18, 1.5), '#5ab8ff')
    sk.outline()


def clock(sk):
    sk.body(sk.circle(16, 16, 12), '#f6efd9', '#ffffff', '#b8a880')
    sk.fill(sk.circle(16, 16, 12) - sk.circle(16, 16, 10.5), '#4a5263')
    sk.fill(sk.line((16, 16), (16, 8), 2), INK)
    sk.fill(sk.line((16, 16), (22, 16), 2), INK)
    sk.outline()


def pearl(sk):
    sk.body(sk.circle(16, 16, 11), '#f4f1ff', '#ffffff', '#9c88c8')
    sk.fill(sk.circle(12, 12, 2), '#ffffff')
    sk.fill(sk.circle(20, 20, 2), '#c9b8ff')
    sk.outline()


def veil(sk):
    sk.fill(sk.poly([(4, 8), (28, 4), (28, 10), (4, 14)]), '#5ff2a8')
    sk.fill(sk.poly([(4, 14), (28, 10), (28, 17), (4, 21)]), '#4cc8ff')
    sk.fill(sk.poly([(4, 21), (28, 17), (28, 23), (4, 27)]), '#b58cff')
    sk.fill(sk.circle(8, 6, 1), '#ffffff')
    sk.fill(sk.circle(24, 26, 1), '#ffffff')
    sk.outline()


def log(sk):
    sk.body(sk.rect(4, 10, 26, 22), '#8a5a33', '#c28a55', '#4a2e18')
    sk.fill(sk.ellipse(26, 16, 4, 6), '#e0b07a')
    sk.fill(sk.circle(26, 16, 2), '#8a5a33')
    sk.fill(sk.line((8, 14), (20, 14), 1), '#4a2e18')
    sk.fill(sk.line((8, 18), (18, 18), 1), '#4a2e18')
    sk.outline()


ICONS = {
    'r_lucky_penny': lambda sk: coin(sk, '#d07a3c', '#ffc27a', '#7a3a14'),
    'r_pocket_change': lambda sk: pouch(sk, '#b5763a', '#e0a062', '#6e3f1a'),
    'r_seed_pouch': lambda sk: pouch(sk, '#6aa86a', '#b4e0a0', '#2f5a33'),
    'r_ladybird_charm': ladybird,
    'r_chipped_bead': chipped_bead,
    'r_surge_drum': surge_drum,
    'r_meadow_honey': honey,
    'r_quarry_coal': coal,
    'r_night_lantern': lambda sk: lantern(sk, '#ffd24a', '#fff6b0'),
    'r_brass_cog': cog,
    'r_warm_ember': ember,
    'r_lodestone': magnet,
    'r_metronome': metronome,
    'r_echo_stone': echo_stone,
    'r_golden_hour': hourglass,
    'r_starfall_lens': starfall,
    'r_obsidian_spur': obsidian,
    'r_echo_ring': ring,
    'r_tide_lantern': lambda sk: lantern(sk, '#5ad8ff', '#d4f6ff'),
    'r_oathstone': slab,
    'r_wardens_eye': eye,
    'r_solar_crown': crown,
    'r_hourglass_ages': clock,
    'r_singularity_pearl': pearl,
    'r_eternal_lantern': lambda sk: lantern(sk, '#ff5ad6', '#ffd0f0'),
    'r_aurora_veil': veil,
    'r_heartwood_crown': log,
}


def draw(name: str, px: int) -> Image.Image:
    sk = Kit(px)
    ICONS[name](sk)
    return sk.image()


def write_all() -> None:
    for name in ICONS:
        draw(name, 16).save(os.path.join(ROOT, name + '.png'))
        for px in (8, 12, 24, 32):
            d = os.path.join(ROOT, 's%d' % px)
            os.makedirs(d, exist_ok=True)
            draw(name, px).save(os.path.join(d, name + '.png'))


def sheet(path: str) -> None:
    names = list(ICONS)
    cell = 120
    cols = 9
    rows = (len(names) + cols - 1) // cols
    im = Image.new('RGBA', (cols * cell, rows * cell), rgba('#1f3b35'))
    dr = ImageDraw.Draw(im)
    for i, name in enumerate(names):
        x0, y0 = (i % cols) * cell, (i // cols) * cell
        big = draw(name, 32).resize((96, 96), Image.NEAREST)
        im.alpha_composite(big, (x0 + 12, y0 + 6))
        small = draw(name, 16).resize((48, 48), Image.NEAREST)
        im.alpha_composite(small, (x0 + 60, y0 + 62))
        tiny = draw(name, 8).resize((32, 32), Image.NEAREST)
        im.alpha_composite(tiny, (x0 + 14, y0 + 80))
        dr.text((x0 + 4, y0 + 114), name.replace('r_', ''), fill=rgba('#f6efd9'))
    im.save(path)


if __name__ == '__main__':
    if '--sheet' in sys.argv:
        sheet(sys.argv[sys.argv.index('--sheet') + 1])
    else:
        write_all()
        print('wrote %d relic icons at 8, 12, 16, 24, 32 px' % len(ICONS))
