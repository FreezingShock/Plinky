"""Seeds icon (Bloom currency): a plump peach-gold seed, no sprout, so it never reads as the RP gem.
Writes assets/icons/seeds.png (16), assets/icons/big/seeds.png (32) and assets/icons/sizes/seeds_8.png, seeds_24.png.
Run: python3 tools/art/gen_seed_icon.py   (needs Pillow). Uses pixel_kit geometry (32 unit space)."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
from pixel_kit import Sk

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'icons')
# 0 ink, 1 shade, 2 base, 3 light, 4 glint, 5 seam
PAL = ['#14161c', '#b8542f', '#f2a35e', '#ffd08a', '#fff4d6', '#d77b45']
RGB = [tuple(int(h[k:k + 2], 16) for k in (1, 3, 5)) + (255,) for h in PAL]


def seed(sk):
    body = sk.ellipse(16, 17.5, 9, 11.5) | sk.poly([(16, 4), (21, 9), (11, 9)])  # plump teardrop, point up
    body = sk.clean(body)
    sk.body(body, 2, hi=3, lo=1)
    seam = sk.line((16, 8), (16, 26), 1.5) & body   # centre seam, vertical, mirrors exactly
    sk.fill({p for p in seam if p not in {q for q in body if False}}, 5)
    if sk.S >= 16:
        sk.fill(sk.ellipse(12, 13, 1.6, 2.6) & body, 4)   # glint
    sk.outline()


def render(size):
    sk = Sk(size)
    seed(sk)
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    for (x, y), c in sk.px.items():
        if 0 <= x < size and 0 <= y < size:
            im.putpixel((x, y), RGB[c])
    return im


if __name__ == '__main__':
    os.makedirs(os.path.join(OUT, 'sizes'), exist_ok=True)
    render(16).save(os.path.join(OUT, 'seeds.png'))
    render(32).save(os.path.join(OUT, 'big', 'seeds.png'))
    render(8).save(os.path.join(OUT, 'sizes', 'seeds_8.png'))
    render(24).save(os.path.join(OUT, 'sizes', 'seeds_24.png'))
