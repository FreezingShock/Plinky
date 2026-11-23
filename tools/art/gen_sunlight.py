"""Sunlight icon: the passive resource of the meadow ladder (the stat the first pads cost).
Same kit and outline as the flower materials (gen_materials.py), in a warm gold ramp.
Run: python3 tools/art/gen_sunlight.py   Writes assets/icons/sunlight.png (16 px), assets/icons/big/sunlight.png (32 px)
and assets/icons/materials/sunlight_<size>.png. Also copies the six flower materials to the stat icon names the HUD loads."""
import os, shutil, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixel_kit as K

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'icons')
RAMP = ('#b86a00', '#ffd23c', '#fff4a8')   # deep, base, light
PAPER = 7


def sunlight(s):
    base = len(K.RGB)
    for h in RAMP:
        K.RGB.append(tuple(int(h[k:k + 2], 16) for k in (1, 3, 5)) + (255,))
    d, b, l = base, base + 1, base + 2
    rays = set()
    for x0, y0, x1, y1 in [(15, 1, 17, 6), (15, 26, 17, 31), (1, 15, 6, 17), (26, 15, 31, 17)]:
        rays |= s.rect(x0, y0, x1, y1)
    for a, c in [((6, 6), (9, 9)), ((26, 6), (23, 9)), ((6, 26), (9, 23)), ((26, 26), (23, 23))]:
        rays |= s.line(a, c, 2)
    s.fill(rays, b)
    disc = s.circle(16, 16, 8)
    s.body(disc, b, l, d)
    s.fill(s.ellipse(13, 13, 2.5, 2.5), PAPER)   # glint


def main():
    os.makedirs(os.path.join(ROOT, 'big'), exist_ok=True)
    os.makedirs(os.path.join(ROOT, 'materials'), exist_ok=True)
    for size, path in ((16, os.path.join(ROOT, 'sunlight.png')), (32, os.path.join(ROOT, 'big', 'sunlight.png'))):
        s = K.Sk(size)
        sunlight(s)
        s.outline()
        s.image().save(path)
    for size in (8, 12, 16, 24, 32):
        s = K.Sk(size)
        sunlight(s)
        s.outline()
        s.image().save(os.path.join(ROOT, 'materials', 'sunlight_%d.png' % size))
    # stat id -> material icon name. The HUD and tooltips load assets/icons/<stat id>.png (16) and big/<stat id>.png (32).
    for stat, mat in [('dewdrop', 'dewdrop'), ('clover', 'clover_leaf'), ('thistle', 'thistle_down'), ('heather', 'heather_sprig'),
                      ('foxglove', 'foxglove_bell'), ('starbloom', 'starbloom_petal')]:
        shutil.copy(os.path.join(ROOT, 'materials', mat + '_16.png'), os.path.join(ROOT, stat + '.png'))
        shutil.copy(os.path.join(ROOT, 'materials', mat + '_32.png'), os.path.join(ROOT, 'big', stat + '.png'))
    print('wrote sunlight and stat icon copies')


if __name__ == '__main__':
    main()
