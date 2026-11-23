"""Core Shards icon (Nucleus currency): a faceted aqua crystal with a hot ember core, so it reads apart from the Seeds drop.
Writes assets/icons/shards.png (16), assets/icons/big/shards.png (32) and assets/icons/sizes/shards_8.png, shards_24.png.
Run: python3 tools/art/gen_shard_icon.py   (needs Pillow). Uses pixel_kit geometry (32 unit space)."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
from pixel_kit import Sk

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'icons')
# 0 ink, 1 shade, 2 base, 3 light, 4 glint, 5 core
PAL = ['#14161c', '#1e7f93', '#3fc9d6', '#8af2ea', '#f4ffff', '#ff8a3d']
RGB = [tuple(int(h[k:k + 2], 16) for k in (1, 3, 5)) + (255,) for h in PAL]


def shard(sk):
    body = sk.poly([(16, 2), (24, 10), (24, 22), (16, 30), (8, 22), (8, 10)])   # a tall six-sided crystal
    sk.body(body, 2, hi=3, lo=1)
    sk.fill(sk.poly([(16, 2), (24, 10), (16, 12), (8, 10)]) & body, 3)           # top facet
    sk.fill(sk.poly([(16, 12), (24, 10), (24, 22), (16, 30)]) & body, 1)         # shaded right facets
    sk.fill(sk.poly([(16, 12), (8, 10), (8, 22), (16, 30)]) & body, 2)
    sk.fill(sk.circle(16, 19, 3) & body, 5)                                       # the hot core
    if sk.S >= 16:
        sk.fill(sk.rect(12, 6, 14, 9) & body, 4)                                  # glint
    sk.outline()


def render(size):
    sk = Sk(size)
    shard(sk)
    im = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    for (x, y), c in sk.px.items():
        if 0 <= x < size and 0 <= y < size:
            im.putpixel((x, y), RGB[c])
    return im


if __name__ == '__main__':
    os.makedirs(os.path.join(OUT, 'sizes'), exist_ok=True)
    render(16).save(os.path.join(OUT, 'shards.png'))
    render(32).save(os.path.join(OUT, 'big', 'shards.png'))
    render(8).save(os.path.join(OUT, 'sizes', 'shards_8.png'))
    render(24).save(os.path.join(OUT, 'sizes', 'shards_24.png'))
