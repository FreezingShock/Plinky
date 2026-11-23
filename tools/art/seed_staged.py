"""Seed staged sources (tools/art/staged/<name>.txt) from an icon's existing 16 px and/or 32 px PNG, for icons that were
drawn at one or two sizes. Missing sizes are reduced (majority colour per window, ink outline rebuilt) or, for 16->32,
enlarged with Scale2x (outline-aware, keeps diagonals clean). The result is a starting point: polish by editing the .txt.
Usage: python3 tools/art/seed_staged.py name[:src16[:src32]] ...   (paths default to assets/icons/<name>.png and big/<name>.png)
Never overwrites a size that is already hand-drawn in an existing .txt unless --force."""
import os, sys
from collections import Counter
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import staged_kit as k

ROOT = os.path.join(k.HERE, '..', '..', 'assets', 'icons')
LET = 'abcdefghijklmnopqrstuvwxyz'


def load(path):
    im = Image.open(path).convert('RGBA')
    return [[None if im.getpixel((x, y))[3] == 0 else im.getpixel((x, y)) for x in range(im.width)] for y in range(im.height)]


def is_ink(c):
    return c == k.RGB[0]


def reduce_to(g, n):
    """Majority-colour reduction to n x n; the 1 px ink outline is rebuilt around the result."""
    m = len(g)
    out = [[None] * n for _ in range(n)]
    for y in range(n):
        for x in range(n):
            y0, y1 = y * m // n, max(y * m // n + 1, -(-(y + 1) * m // n))
            x0, x1 = x * m // n, max(x * m // n + 1, -(-(x + 1) * m // n))
            cells = [g[j][i] for j in range(y0, y1) for i in range(x0, x1)]
            fill = [c for c in cells if c is not None and not is_ink(c)]
            total = len(cells)
            if len(fill) * 2 > total or (fill and len(fill) * 3 >= total):
                out[y][x] = sorted(Counter(fill).items(), key=lambda t: (-t[1], t[0]))[0][0]
    res = [r[:] for r in out]
    for y in range(n):
        for x in range(n):
            if out[y][x] is None:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < n and 0 <= ny < n and out[ny][nx] is not None:
                        res[y][x] = k.RGB[0]
                        break
    return res


def scale2x(g):
    n = len(g)
    out = [[None] * (2 * n) for _ in range(2 * n)]
    for y in range(n):
        for x in range(n):
            p = g[y][x]
            a = g[y - 1][x] if y else None
            b = g[y][x + 1] if x < n - 1 else None
            c = g[y][x - 1] if x else None
            d = g[y + 1][x] if y < n - 1 else None
            e = [p, p, p, p]
            if c == a and c != d and a != b: e[0] = a
            if a == b and a != c and b != d: e[1] = b
            if d == c and d != b and c != a: e[2] = c
            if b == d and b != a and d != c: e[3] = d
            for i, v in enumerate(e):
                out[2 * y + i // 2][2 * x + i % 2] = v
    return out


def encode(g, table):
    rows = []
    for r in g:
        s = ''
        for c in r:
            if c is None:
                s += '.'
            elif c in k.RGB:
                s += str(k.RGB.index(c))
            else:
                if c not in table:
                    table[c] = LET[len(table)]
                s += table[c]
        rows.append(s)
    return rows


def seed(name, p16=None, p32=None, force=False):
    p16 = p16 or os.path.join(ROOT, name + '.png')
    p32 = p32 or os.path.join(ROOT, 'big', name + '.png')
    g16 = load(p16) if os.path.exists(p16) else None
    g32 = load(p32) if os.path.exists(p32) else None
    if g16 is None and g32 is None:
        raise SystemExit('no art for ' + name)
    if g32 is None:
        g32 = scale2x(g16)
    if g16 is None:
        g16 = reduce_to(g32, 16)
    g24 = reduce_to(g32, 24)
    g = {8: reduce_to(g16, 8), 12: reduce_to(g24, 12), 16: g16, 24: g24, 32: g32}
    path = os.path.join(k.SRC, name + '.txt')
    keep = {}
    if os.path.exists(path) and not force:
        keep = k.parse(path)
    table = {}
    parts = ['# %s: sizes reduced or enlarged from the existing art by tools/art/seed_staged.py, then polish by hand.' % name]
    body = []
    for s in k.SIZES:
        grid = keep.get(s) or g[s]
        body.append('@%d' % s)
        body += encode(grid, table)
    parts += ['%%%s=#%02x%02x%02x' % (ch, c[0], c[1], c[2]) for c, ch in table.items()]
    open(path, 'w').write('\n'.join(parts + body) + '\n')


if __name__ == '__main__':
    force = '--force' in sys.argv
    for a in sys.argv[1:]:
        if a.startswith('--'):
            continue
        n, *rest = a.split(':')
        seed(n, rest[0] if rest else None, rest[1] if len(rest) > 1 else None, force)
        print('seeded', n)
