#!/usr/bin/env python3
"""Build fonts/PixelifySans-popup.ttf: Pixelify Sans with a Q that reads apart from 0 at popup size.

Only the Q glyph changes. Its bowl is the 0's bowl; the tail is detached from the bowl by the
bottom-right notch and runs down and right, so the outline's 2 px popup stroke cannot fuse it in.
Advance width and every other glyph are untouched. The family is renamed so the derived file is
never mistaken for the stock font. Pixelify Sans is OFL 1.1 with no Reserved Font Name, so a
modified copy may be distributed under the same licence (fonts/OFL-pixelify-sans.txt).

Dev tool only (needs fonttools: pip install fonttools). Re-run it after changing the outline below.
Usage: python3 tools/build_popup_font.py
"""
from pathlib import Path

from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "fonts" / "PixelifySans.ttf"
OUT = ROOT / "fonts" / "PixelifySans-popup.ttf"
FAMILY = "Pixelify Sans Popup"

# Outer contour (clockwise, font units). Same bowl as the 0 with its bottom-right notch kept,
# then a two-step tail below and right of the bowl.
Q_OUTER = [
    (151, -12), (151, 78), (60, 78), (60, 540), (151, 540), (151, 631),
    (433, 631), (433, 540), (525, 540), (525, 78), (433, 78), (433, -12),
    (433, -103), (433, -192), (525, -192), (525, -103), (343, -103), (343, -12),
]
# Counter, wound the other way so it is a hole under the nonzero fill rule.
Q_COUNTER = [(161, 88), (423, 88), (423, 530), (161, 530)]


def build() -> None:
    font = TTFont(str(SRC))
    glyph_name = font.getBestCmap()[ord("Q")]
    pen = TTGlyphPen(None)
    for contour in (Q_OUTER, Q_COUNTER):
        pen.moveTo(contour[0])
        for point in contour[1:]:
            pen.lineTo(point)
        pen.closePath()
    font["glyf"][glyph_name] = pen.glyph()
    font["glyf"][glyph_name].recalcBounds(font["glyf"])

    for record in font["name"].names:
        if record.nameID in (1, 4, 16):
            record.string = FAMILY if record.nameID != 4 else FAMILY + " Regular"
        elif record.nameID == 6:
            record.string = "PixelifySans-Popup-Regular"
    font.save(str(OUT))
    print("wrote", OUT.relative_to(ROOT))


if __name__ == "__main__":
    build()
