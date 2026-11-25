"""Compile the staged icon sources (tools/art/staged/*.txt) to PNGs.
Every icon has five hand-drawn sizes: 8, 12, 16, 24, 32. Output:
  assets/icons/s8/<n>.png  s12/  s24/        new sizes
  assets/icons/<n>.png (16) and assets/icons/big/<n>.png (32)   existing paths, so nothing else changes
Also writes a contact sheet to docs/img/icons_staged.png. Run: python3 tools/art/gen_icons_staged.py"""
import os, sys, glob
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import staged_kit as k
import icon_ramps as ir
from PIL import Image

ROOT = os.path.join(k.HERE, '..', '..')
OUT = os.path.join(ROOT, 'assets', 'icons')
ORDER = ['rp', 'cash', 'mult', 'reb', 'prestige', 'slag', 'heat', 'crit', 'crit_dmg', 'rate', 'luck', 'offline',
         'walk', 'mastery', 'presses', 'clock', 'rest', 'lore', 'fortune']


def dest(name, size):
    if name.startswith('r_'):          # relic icons live in assets/icons/relics/ (16 px) with s8 s12 s24 s32 beside it
        return os.path.join(OUT, 'relics', name + '.png') if size == 16 else os.path.join(OUT, 'relics', 's%d' % size, name + '.png')
    if size == 16:
        return os.path.join(OUT, name + '.png')
    if size == 32:
        return os.path.join(OUT, 'big', name + '.png')
    return os.path.join(OUT, 's%d' % size, name + '.png')


def main():
    names = sorted(os.path.splitext(os.path.basename(p))[0] for p in glob.glob(os.path.join(k.SRC, '*.txt')))
    sheets = []
    for n in names:
        grids = k.parse(os.path.join(k.SRC, n + '.txt'))
        assert sorted(grids) == list(k.SIZES), '%s has sizes %s' % (n, sorted(grids))
        fam = ir.FAMILY_OF.get(n, ir.DEFAULT_FAMILY)
        for s, g in grids.items():
            p = dest(n, s)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            shaded = ir.shade(g, s, fam)                  # role -> ramp step of its family (Gower rules 2 and 9)
            rgba = Image.new('RGBA', (s, s), (0, 0, 0, 0))
            for y, row in enumerate(shaded):
                for x, c in enumerate(row):
                    if c is not None:
                        rgba.putpixel((x, y), c)
            rgba.save(p)
        sheets.append((n, grids))
    sheets.sort(key=lambda t: ORDER.index(t[0]) if t[0] in ORDER else 99)
    os.makedirs(os.path.join(ROOT, 'docs', 'img'), exist_ok=True)
    cols = 4
    per = -(-len(sheets) // cols)
    parts = [k.sheet(sheets[i * per:(i + 1) * per], scale=3, bg=(40, 46, 56, 255)) for i in range(cols) if sheets[i * per:(i + 1) * per]]
    im = Image.new('RGBA', (sum(p.width for p in parts), max(p.height for p in parts)), (40, 46, 56, 255))
    x = 0
    for p in parts:
        im.paste(p, (x, 0)); x += p.width
    im.save(os.path.join(ROOT, 'docs', 'img', 'icons_staged.png'))
    for i, grp in enumerate(('stats', 'relics_menu')):
        pass
    print(len(names), 'icons x', len(k.SIZES), 'sizes')


if __name__ == '__main__':
    main()
