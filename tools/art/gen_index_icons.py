"""Icons for the Stats and Attributes index (meadow palette, 16x16, 1 texel ink outline).
Run: python3 tools/art/gen_index_icons.py   (needs Pillow). Writes assets/icons/*.png and two 4-frame sheets."""
import os
from PIL import Image, ImageDraw

PAL = ['#14161c', '#1f3b35', '#2f6b55', '#5fa36a', '#b7d978', '#f2e6a0', '#c2784e', '#f6efd9']
H = lambda i: tuple(int(PAL[i][k:k + 2], 16) for k in (1, 3, 5)) + (255,)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'icons')


def canvas():
    return Image.new('RGBA', (16, 16), (0, 0, 0, 0))


def outline(im):
    src = im.load()
    out = im.copy()
    o = out.load()
    for y in range(16):
        for x in range(16):
            if src[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < 16 and 0 <= ny < 16 and src[nx, ny][3]:
                    o[x, y] = H(0)
                    break
    return out


def px(d, pts, i):
    for x, y in pts:
        d.point((x + 1, y + 1), fill=H(i))


def rect(d, x0, y0, x1, y1, i):
    d.rectangle([x0 + 1, y0 + 1, x1 + 1, y1 + 1], fill=H(i))


def poly(d, pts, i):
    d.polygon([(x + 1, y + 1) for x, y in pts], fill=H(i))


def stats_menu(f=0):
    im = canvas(); d = ImageDraw.Draw(im)
    heights = [4, 7, 10]
    bump = [0, 0, 0]
    if f > 0:
        bump[(f - 1) % 3] = 1
    for n, x0 in enumerate((1, 5, 9)):
        h = heights[n] + bump[n]
        rect(d, x0, 12 - h, x0 + 3, 12, 3)
        rect(d, x0, 12 - h, x0 + 3, 12 - h, 4)       # lit top
        rect(d, x0 + 3, 13 - h, x0 + 3, 12, 2)       # shaded side
    rect(d, 0, 13, 13, 13, 6)                         # ground line
    if f == 3:
        px(d, [(11, 0), (10, 1), (12, 1), (11, 2)], 7)
    return outline(im)


def attrs_menu(f=0):
    im = canvas(); d = ImageDraw.Draw(im)
    poly(d, [(7, 0), (13, 3), (13, 9), (7, 13), (1, 9), (1, 3)], 2)       # hex badge
    poly(d, [(7, 1), (12, 3), (12, 9), (7, 12), (2, 9), (2, 3)], 3)
    rect(d, 2, 3, 2, 9, 4)
    bob = (0, -1, 0, 1)[f]
    poly(d, [(7, 3 + bob), (10, 7 + bob), (4, 7 + bob)], 5)               # up arrow = permanent growth
    rect(d, 6, 7 + bob, 7, 10 + bob, 5)
    if f == 2:
        px(d, [(11, 1), (12, 2), (10, 2), (11, 3)], 7)
    return outline(im)


def crit_dmg():
    im = canvas(); d = ImageDraw.Draw(im)
    poly(d, [(7, 0), (9, 4), (13, 3), (10, 6), (13, 9), (9, 8), (7, 13), (5, 8), (1, 9), (4, 6), (1, 3), (5, 4)], 6)
    poly(d, [(7, 1), (8, 5), (11, 4), (9, 6), (11, 8), (8, 7), (7, 11), (6, 7), (3, 8), (5, 6), (3, 4), (6, 5)], 5)
    rect(d, 6, 5, 7, 7, 7)
    return outline(im)


def mastery():
    im = canvas(); d = ImageDraw.Draw(im)
    poly(d, [(2, 0), (6, 0), (7, 6), (4, 6)], 2)           # ribbons
    poly(d, [(11, 0), (7, 0), (6, 6), (9, 6)], 3)
    im2 = ImageDraw.Draw(im)
    im2.ellipse([2, 6, 13, 16 - 2], fill=H(6))              # medal rim
    im2.ellipse([3, 7, 12, 14], fill=H(5))
    px(d, [(6, 7), (5, 8), (6, 8), (7, 8), (8, 8), (4, 9), (5, 9), (6, 9), (7, 9), (8, 9), (9, 9), (5, 10), (6, 10), (7, 10), (8, 10), (5, 11), (8, 11)], 7)
    return outline(im)


def presses():
    im = canvas(); d = ImageDraw.Draw(im)
    poly(d, [(7, 7), (13, 10), (7, 13), (1, 10)], 2)       # pad slab: side then top
    poly(d, [(7, 6), (13, 9), (7, 12), (1, 9)], 4)
    poly(d, [(7, 8), (10, 9), (7, 10), (4, 9)], 3)
    rect(d, 6, 0, 7, 3, 5)                                  # press arrow
    poly(d, [(3, 3), (10, 3), (7, 7), (6, 7)], 5)
    return outline(im)


def clock():
    im = canvas(); d = ImageDraw.Draw(im)
    d.ellipse([1, 1, 14, 14], fill=H(3))
    d.ellipse([2, 2, 13, 13], fill=H(7))
    px(d, [(6, 1), (7, 1), (6, 12), (7, 12), (1, 6), (1, 7), (12, 6), (12, 7)], 3)
    rect(d, 6, 3, 6, 7, 2)
    rect(d, 6, 7, 9, 7, 2)
    px(d, [(6, 7)], 6)
    return outline(im)


def save(name, im):
    im.save(os.path.join(OUT, name + '.png'))


def sheet(name, fn):
    s = Image.new('RGBA', (64, 16), (0, 0, 0, 0))
    for f in range(4):
        s.paste(fn(f), (f * 16, 0))
    s.save(os.path.join(OUT, name + '_sheet.png'))


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    save('stats_menu', stats_menu(0)); save('attrs_menu', attrs_menu(0))
    sheet('stats_menu', stats_menu); sheet('attrs_menu', attrs_menu)
    save('crit_dmg', crit_dmg()); save('mastery', mastery())
    save('presses', presses()); save('clock', clock())
    print('ok')
