"""Big 32x32 menu icons for the gallery menu (ui/gallery_menu.gd), plus the 16x16 hamburger.
Meadow palette indices only. Run: python3 tools/art/gen_menu_icons.py  -> assets/icons/big/menu_*.png
"""
from PIL import Image, ImageDraw
import os

P = ["14161c", "1f3b35", "2f6b55", "5fa36a", "b7d978", "f2e6a0", "c2784e", "f6efd9"]
C = [tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,) for h in P]
INK, SHADOW, DEEP, BASE, LIGHT, ACCENT, EARTH, PAPER = C
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "icons", "big")


def canvas(n=32):
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def outline(im):
    """1 texel ink outline around every opaque pixel."""
    out = im.copy()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            if im.getpixel((x, y))[3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and im.getpixel((nx, ny))[3]:
                        out.putpixel((x, y), INK)
                        break
    return out


def save(im, name):
    os.makedirs(OUT, exist_ok=True)
    outline(im).save(os.path.join(OUT, name))


def log():
    im, d = canvas()
    d.rectangle([7, 4, 24, 27], fill=PAPER)            # page
    d.rectangle([7, 4, 9, 27], fill=BASE)               # spine
    for y in (9, 13, 17, 21):
        d.rectangle([12, y, 21 - (y % 8 == 1) * 4, y + 1], fill=DEEP)
    d.rectangle([20, 22, 24, 27], fill=ACCENT)          # ribbon
    save(im, "menu_log.png")


def history():
    im, d = canvas()
    d.rectangle([4, 5, 27, 26], fill=PAPER)             # chart card
    d.rectangle([4, 5, 27, 7], fill=BASE)
    for i, h in enumerate([4, 6, 5, 9, 12, 15]):         # climbing bars
        x = 7 + i * 3
        d.rectangle([x, 24 - h, x + 1, 24], fill=DEEP if i < 5 else LIGHT)
    d.rectangle([24, 9, 24, 24], fill=ACCENT)           # rebirth mark
    save(im, "menu_history.png")


def settings():
    import math
    im, d = canvas()
    cx = cy = 15.5
    for y in range(32):
        for x in range(32):
            dx, dy = x - cx, y - cy
            r = math.hypot(dx, dy)
            a = math.atan2(dy, dx)
            tooth = r <= 14 and abs(math.sin(a * 4)) > 0.5
            if r <= 10.5 or (r <= 14 and tooth):
                if r < 5:
                    continue
                im.putpixel((x, y), LIGHT if r > 8 else BASE)
    save(im, "menu_settings.png")


def stats():
    im, d = canvas()
    for i, (h, col) in enumerate([(9, DEEP), (16, BASE), (23, LIGHT), (14, BASE)]):
        x = 4 + i * 6
        d.rectangle([x, 27 - h, x + 4, 27], fill=col)
        d.rectangle([x, 27 - h, x + 4, 27 - h], fill=PAPER)
    d.rectangle([3, 28, 28, 28], fill=PAPER)
    save(im, "menu_stats.png")


def attributes():
    im, d = canvas()
    pts = [(16, 3), (27, 7), (27, 17), (16, 29), (5, 17), (5, 7)]   # shield
    d.polygon(pts, fill=BASE)
    d.polygon([(16, 6), (24, 9), (24, 16), (16, 25), (8, 16), (8, 9)], fill=DEEP)
    d.rectangle([14, 9, 17, 20], fill=ACCENT)
    d.rectangle([11, 12, 20, 14], fill=ACCENT)
    save(im, "menu_attributes.png")


def upgrades():
    im, d = canvas()
    d.polygon([(16, 3), (28, 16), (21, 16), (21, 28), (11, 28), (11, 16), (4, 16)], fill=LIGHT)
    d.polygon([(16, 7), (23, 15), (19, 15), (19, 26), (13, 26), (13, 15), (9, 15)], fill=BASE)
    d.rectangle([14, 10, 17, 12], fill=ACCENT)
    save(im, "menu_upgrades.png")


def relics():
    im, d = canvas()
    d.polygon([(16, 3), (27, 12), (22, 28), (10, 28), (5, 12)], fill=BASE)     # gem
    d.polygon([(16, 3), (27, 12), (5, 12)], fill=LIGHT)                         # crown
    d.polygon([(16, 12), (27, 12), (22, 28), (16, 28)], fill=DEEP)              # shaded half
    d.polygon([(16, 3), (20, 12), (16, 12)], fill=ACCENT)                       # facet
    d.line([(5, 12), (27, 12)], fill=PAPER)
    d.rectangle([8, 14, 9, 18], fill=PAPER)                                     # glint
    save(im, "menu_relics.png")


def travel():
    im, d = canvas()
    d.rectangle([4, 6, 27, 25], fill=PAPER)                    # map
    for x in (11, 19):
        d.line([(x, 6), (x, 25)], fill=BASE)
    d.polygon([(4, 18), (10, 12), (14, 16), (20, 9), (27, 17), (27, 25), (4, 25)], fill=DEEP)
    d.rectangle([20, 12, 23, 15], fill=ACCENT)                  # pin
    d.rectangle([21, 16, 22, 19], fill=ACCENT)
    save(im, "menu_travel.png")


def hamburger():
    im, d = canvas(16)
    for y in (4, 7, 10):
        d.rectangle([3, y, 12, y + 1], fill=PAPER)
    d.rectangle([3, 5, 12, 5], fill=LIGHT)
    d.rectangle([3, 8, 12, 8], fill=LIGHT)
    d.rectangle([3, 11, 12, 11], fill=LIGHT)
    outline(im).save(os.path.join(OUT, "menu_hamburger.png"))


for f in (history, log, settings, stats, attributes, upgrades, relics, travel, hamburger):
    f()
print("ok")
