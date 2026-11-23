"""Staged (multi-resolution) icon kit. Every size of an icon is its own hand-drawn pixel grid, never a scaled copy.
Source files: tools/art/staged/<name>.txt. Format:
    @<size> [mirror]        starts a grid for that size (8, 12, 16, 24, 32)
    <rows>                  one string per row; 0-7 palette index (meadow roles), '.' clear
With `mirror` the rows are the LEFT half (size/2 wide) and are reflected, so symmetry is exact.
Lines starting with '#' are comments. Palette roles: 0 ink, 1 shadow, 2 deep, 3 base, 4 light, 5 accent, 6 earth, 7 paper."""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'staged')
PAL = ['#14161c', '#1f3b35', '#2f6b55', '#5fa36a', '#b7d978', '#f2e6a0', '#c2784e', '#f6efd9']
RGB = [tuple(int(h[k:k + 2], 16) for k in (1, 3, 5)) + (255,) for h in PAL]
SIZES = (8, 12, 16, 24, 32)


def parse(path):
    """-> {size: 2D list of palette index or None}"""
    out, cur, mirror, rows = {}, None, False, []
    extra = {}      # letter -> index (8+) for icons that need colours beyond the 8 zone roles (e.g. Embers)

    def flush():
        if cur is None:
            return
        n = cur
        grid = []
        for r in rows:
            cells = [] if r == '-' else [None if ch == '.' else (int(ch) if ch.isdigit() else extra[ch]) for ch in r]
            if mirror:
                assert len(cells) <= n // 2, '%s @%d: half row width %d > %d (%r)' % (path, n, len(cells), n // 2, r)
                cells = [None] * (n // 2 - len(cells)) + cells      # short rows are right-aligned to the centre line
                cells = cells + cells[::-1]
            if not mirror:
                cells = cells + [None] * (n - len(cells)) if r == '-' else cells
            assert len(cells) == n, '%s @%d: row width %d (%r)' % (path, n, len(cells), r)
            grid.append(cells)
        assert len(grid) <= n, '%s @%d: %d rows, want at most %d' % (path, n, len(grid), n)
        grid += [[None] * n for _ in range(n - len(grid))]      # missing rows at the bottom are clear
        out[n] = grid

    for line in open(path, encoding='utf-8'):
        line = line.rstrip('\n').strip()
        if not line or line.startswith('#'):
            continue
        if line.startswith('%'):
            ch, hexv = line[1:].split('=')
            extra[ch] = tuple(int(hexv[k:k + 2], 16) for k in (1, 3, 5)) + (255,)    # cell value is the RGBA itself
            continue
        if line.startswith('@'):
            flush()
            parts = line[1:].split()
            cur, mirror, rows = int(parts[0]), 'mirror' in parts[1:], []
        else:
            rows.append(line)
    flush()
    return out


def image(grid):
    n = len(grid)
    im = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    for y, row in enumerate(grid):
        for x, c in enumerate(row):
            if c is not None:
                im.putpixel((x, y), RGB[c] if isinstance(c, int) else c)
    return im


def sheet(names_grids, scale=6, pad=6, bg=(31, 59, 53, 255)):
    """Contact sheet: one row per icon, all sizes side by side at the same integer scale."""
    cols = [8, 12, 16, 24, 32]
    cw = [s * scale + pad for s in cols]
    w = sum(cw) + pad
    h = (32 * scale + pad) * len(names_grids) + pad
    sh = Image.new('RGBA', (w, h), bg)
    y = pad
    for name, grids in names_grids:
        x = pad
        for s, cwid in zip(cols, cw):
            if s in grids:
                im = image(grids[s]).resize((s * scale, s * scale), Image.NEAREST)
                sh.paste(im, (x, y + (32 * scale - s * scale) // 2), im)
            x += cwid
        y += 32 * scale + pad
    return sh
