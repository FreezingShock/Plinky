"""Compile the staged icon sources (tools/art/staged/*.txt) to PNGs.
Every icon has five hand-drawn sizes: 8, 12, 16, 24, 32. Output:
  assets/icons/s8/<n>.png  s12/  s24/        new sizes
  assets/icons/<n>.png (16) and assets/icons/big/<n>.png (32)   existing paths, so nothing else changes
Also writes a contact sheet to docs/img/icons_staged.png. Run: python3 tools/art/gen_icons_staged.py"""
import os, sys, glob
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import staged_kit as k

ROOT = os.path.join(k.HERE, '..', '..')
OUT = os.path.join(ROOT, 'assets', 'icons')
ORDER = ['rp', 'cash', 'mult', 'reb', 'prestige', 'slag', 'heat', 'crit', 'crit_dmg', 'rate', 'luck', 'offline',
         'walk', 'mastery', 'presses', 'clock', 'rest', 'lore', 'fortune']


def dest(name, size):
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
        for s, g in grids.items():
            p = dest(n, s)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            k.image(g).save(p)
        sheets.append((n, grids))
    sheets.sort(key=lambda t: ORDER.index(t[0]) if t[0] in ORDER else 99)
    os.makedirs(os.path.join(ROOT, 'docs', 'img'), exist_ok=True)
    half = (len(sheets) + 1) // 2
    a = k.sheet(sheets[:half], scale=4, bg=(40, 46, 56, 255))
    b = k.sheet(sheets[half:], scale=4, bg=(40, 46, 56, 255))
    from PIL import Image
    im = Image.new('RGBA', (a.width + b.width, max(a.height, b.height)), (40, 46, 56, 255))
    im.paste(a, (0, 0)); im.paste(b, (a.width, 0))
    im.save(os.path.join(ROOT, 'docs', 'img', 'icons_staged.png'))
    print(len(names), 'icons x', len(k.SIZES), 'sizes')


if __name__ == '__main__':
    main()
