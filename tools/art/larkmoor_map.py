"""Layout mockup of Larkmoor (flat schematic in the iso screen frame). python3 larkmoor_map.py out.png"""
import sys, math
from PIL import Image, ImageDraw, ImageFont
sys.path.insert(0, __import__('os').path.dirname(__file__))
import larkmoor_layout as L
S = 1  # draw at 1x of the 1520x920 world frame
img = Image.new('RGB', (L.W, L.H), '#14161c'); d = ImageDraw.Draw(img)
try: F = ImageFont.truetype('/home/claude/Plinky/fonts/PixelifySans.ttf', 22); FS = ImageFont.truetype('/home/claude/Plinky/fonts/PixelifySans.ttf', 16)
except Exception: F = FS = ImageFont.load_default()
cx, cy = L.OX, L.OY + (L.CU + L.CV) / 2
d.ellipse([cx - L.R * 1.414, cy - L.R * .707, cx + L.R * 1.414, cy + L.R * .707], fill='#5fa36a', outline='#f6efd9', width=3)
# mountain rim
d.ellipse([cx - L.R * 1.414, cy - L.R * .707, cx + L.R * 1.414, cy + L.R * .707], outline='#2f6b55', width=70)
d.ellipse([cx - L.R * 1.414 + 40, cy - L.R * .707 + 20, cx + L.R * 1.414 - 40, cy + L.R * .707 - 20], fill='#5fa36a')
for wl in (L.LAKE, L.MERE):
    d.ellipse([wl['c'][0] - wl['rx'], wl['c'][1] - wl['ry'], wl['c'][0] + wl['rx'], wl['c'][1] + wl['ry']], fill='#1f3b35', outline='#b7d978', width=3)
d.line(L.STREAM, fill='#2f6b55', width=9)
for p in L.PATHS: d.line(p, fill='#f2e6a0', width=14, joint='curve')
d.rectangle([L.BRIDGE[0] - 14, L.BRIDGE[1] - 9, L.BRIDGE[0] + 14, L.BRIDGE[1] + 9], fill='#c2784e', outline='#14161c')
for k, (kind, c, r, n) in enumerate(L.GROVES):
    col = {'oak': '#2f6b55', 'pine': '#1f3b35', 'bush': '#b7d978', 'rock': '#c2784e', 'crystals': '#f6efd9'}[kind]
    d.ellipse([c[0] - r, c[1] - r * .5, c[0] + r, c[1] + r * .5], outline=col, width=2)
for ds in L.DISTRICTS:
    for p in ds['pads']: d.ellipse([p[0] - 14, p[1] - 7, p[0] + 14, p[1] + 7], fill='#f6efd9', outline='#14161c', width=2); d.ellipse([p[0] - 6, p[1] - 3, p[0] + 6, p[1] + 3], fill='#c2784e')
    d.text((ds['c'][0], ds['c'][1] - 44), ds['name'], fill='#14161c', font=F, anchor='mm'); d.text((ds['c'][0] + 1, ds['c'][1] - 45), ds['name'], fill='#f6efd9', font=F, anchor='mm')
for lm in L.LANDMARKS: d.polygon([(lm['at'][0], lm['at'][1] - 14), (lm['at'][0] + 9, lm['at'][1]), (lm['at'][0] - 9, lm['at'][1])], fill='#c2784e', outline='#14161c')
for g, lab in ((L.HOLLOW_GATE, 'from the onboarding meadow'), (L.EMBER_GATE, 'to Zone 2 (Ember Quarry)')):
    d.rectangle([g[0] - 20, g[1] - 16, g[0] + 20, g[1] + 6], fill='#f2e6a0', outline='#14161c', width=3); d.text((g[0], g[1] + 26), lab, fill='#f6efd9', font=FS, anchor='mm')
img.save(sys.argv[1] if len(sys.argv) > 1 else 'larkmoor_map.png')
