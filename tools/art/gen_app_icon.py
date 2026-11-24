#!/usr/bin/env python3
"""Plinky app icon: the walker on its pad under a golden-hour sunset, drawn on a 64 texel grid.

Colours are the golden-hour keyframe from core/title_mood.gd (sky roles 0 to 7, ground roles), so the icon matches the
title. The walker is frame 0 of assets/brand/walker-press-sheet-1x.png, pasted unchanged. Every size is a nearest or
box scale of the 1024 master, so the pixel grid stays crisp. Run from anywhere: python3 tools/art/gen_app_icon.py
"""
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
SHEET = os.path.join(ROOT, "assets", "brand", "walker-press-sheet-1x.png")
OUT = os.path.join(ROOT, "assets", "brand")

N = 64
# Golden-hour keyframe (core/title_mood.gd, "Golden Hour"): sky roles 0 ink .. 7 paper, then the meadow ground.
SKY = ["1c1220", "4a2350", "9a3a5a", "e87a4a", "ffb060", "ffe49a", "a05a4a", "ffe6c0"]
GROUND = ["2a2a22", "4a4a2a", "7a8a3a", "c9b050"]
HILL = "3a1d40"
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def rgb(h: str) -> tuple:
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def bayer(x: int, y: int) -> float:
    return (BAYER[y % 4][x % 4] + 0.5) / 16.0


def ridge(x: int) -> float:
    return 41.0 - 3.0 * abs(__import__("math").sin(x * 0.3)) - 2.0 * abs(__import__("math").sin(x * 0.7 + 1.0))


def base_scene() -> Image.Image:
    img = Image.new("RGBA", (N, N), rgb(SKY[0]))
    px = img.load()
    sun = (15.0, 36.0)
    for y in range(N):
        for x in range(N):
            t = bayer(x, y)
            if y < 46:
                v = y / 46.0 + (t - 0.5) * 0.2
                idx = 0 if v < 0.12 else 1 if v < 0.3 else 2 if v < 0.48 else 3 if v < 0.66 else 4
                # Sun: a bright disc with a dithered gold halo, drawn over the sky and under the hills.
                d = ((x + 0.5 - sun[0]) ** 2 + (y + 0.5 - sun[1]) ** 2) ** 0.5
                if d < 9.0:
                    idx = 5 if d < 8.0 else 4
                elif d < 13.0 and t < 1.0 - (d - 9.0) / 4.0:
                    idx = 4
                elif d < 20.0 and t < 0.5 * (1.0 - (d - 13.0) / 7.0) and idx < 4:
                    idx = 3
                px[x, y] = rgb(SKY[idx])
            elif y < 64:
                gy = y - 46
                idx = 2
                if gy > 9:
                    idx = 1
                if gy > 15:
                    idx = 0
                if gy < 2:
                    idx = 3
                px[x, y] = rgb(GROUND[idx])
            # Far hills in plum, cutting the sun's lower edge.
            if y >= ridge(x) and y < 46:
                px[x, y] = rgb(HILL if y > ridge(x) + 1.0 else SKY[1])
    # Light patches on the grass, dithered.
    for y in range(47, 64):
        for x in range(N):
            if (x * 7 + y * 3) % 11 == 0 and bayer(x, y) < 0.5:
                px[x, y] = rgb(GROUND[3])
    # One texel ink border, so the icon reads on light and dark docks alike.
    for i in range(N):
        for p in ((i, 0), (i, N - 1), (0, i), (N - 1, i)):
            px[p] = rgb(SKY[0])
    return img


def build() -> Image.Image:
    scene = base_scene()
    walker = Image.open(SHEET).convert("RGBA").crop((0, 0, 64, 64))
    scene.alpha_composite(walker)
    return scene.resize((1024, 1024), Image.NEAREST)


def main() -> None:
    master = build()
    for size in (16, 32, 48, 256, 512, 1024):
        out = master.resize((size, size), Image.NEAREST if 1024 % size == 0 else Image.BOX)
        out.save(os.path.join(OUT, "plinky-icon-%d.png" % size))
    master.save(os.path.join(OUT, "plinky.icns"))
    master.save(os.path.join(OUT, "plinky.ico"), sizes=[(16, 16), (32, 32), (48, 48), (256, 256)])
    print("wrote icon set to", OUT)


if __name__ == "__main__":
    main()
