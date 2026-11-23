#!/usr/bin/env python3
"""Ember Quarry ladder art, v2: isometric voxel renders, one colour ramp per tier (tier colour follows rarity).
Every object is a 16^3 voxel model rendered 2:1 isometric with three face tones, a smooth ramp height gradient (dither only at the band edge),
emissive glow voxels and a 1 px ink outline. Output per tier:
  <tier>_hero.png   full model (about 64 px wide), 3 flicker frames <tier>_hero_f0..2.png
  <tier>_game.png   model halved to an 8^3 lattice (about 32 px wide), pad size, 3 frames <tier>_game_f0..2.png
  <tier>_32.png <tier>_16.png <tier>_8.png  UI icons, fitted from the game render
Usage: python3 tools/art/gen_quarry_ladder.py [outdir]"""
import sys, os, math
from PIL import Image

def rgb(h): return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))
# ramp: 5 body tones dark->light, 'c' secondary body ramp, 'a' glow ramp (dark->white-hot, 4)
TIERS = {
 "cinder": dict(name="Cinder", rarity="common",
   body=["1a1416","332a2c","54484a","7e7070","b8a89c"], sec=["14100f","2a2220","443836","665655","8e7c74"],
   glow=["8a2a1e","d0602f","e9a845","f8e0a0"]),
 "ore": dict(name="Ore", rarity="uncommon",
   body=["0e2218","1d4630","2f7a4a","5fb26a","b8f0a0"], sec=["0a1810","15301f","224f35","357a50","58a870"],
   glow=["8a4a1e","c8793a","f0b060","fff0c0"]),
 "slag": dict(name="Slag", rarity="rare",
   body=["0c1428","1a3260","2c5fa0","58a8e0","c0eeff"], sec=["080e1c","121e3c","1e3a6a","305a98","4a82c0"],
   glow=["a0301c","f0602a","ffb040","fff0b0"]),
 "ingot": dict(name="Ingot", rarity="epic",
   body=["1a0e2e","3a2866","6a4ca8","a07ee0","e6d2ff"], sec=["120a22","271a48","44307a","6a52ac","9a86d0"],
   glow=["6a2a8a","b060e0","f0a0ff","ffffff"]),
 "alloy": dict(name="Alloy", rarity="legendary",
   body=["2a1808","68420e","b07a1c","e8b43a","fff0a0"], sec=["1a1008","3a3438","68646c","9c98a4","d0ccd8"],
   glow=["c04010","f08020","ffd060","ffffff"]),
 "ember": dict(name="Emberheart", rarity="mythic",
   body=["2a0618","701040","c02070","ff5aa0","ffd0e8"], sec=["1a0410","3e0a28","7a1a50","b02e78","d85aa0"],
   glow=["c01848","ff4060","ffa0b0","fffff0"]),
}
N = 16
def ellipsoid(vox, c, r, mat, zmin=0):
    for x in range(N):
        for y in range(N):
            for z in range(zmin, N):
                if ((x-c[0])/r[0])**2 + ((y-c[1])/r[1])**2 + ((z-c[2])/r[2])**2 <= 1: vox[(x,y,z)] = mat
def box(vox, x0, x1, y0, y1, z0, z1, mat):
    for x in range(x0, x1+1):
        for y in range(y0, y1+1):
            for z in range(z0, z1+1): vox[(x,y,z)] = mat
def h(x, y, z): return ((x*73856093) ^ (y*19349663) ^ (z*83492791)) & 0xffff
def surface(vox):
    return [k for k in vox if any((k[0]+d[0], k[1]+d[1], k[2]+d[2]) not in vox for d in ((1,0,0),(-1,0,0),(0,1,0),(0,-1,0),(0,0,1)))]

def m_cinder():
    v = {}
    for c, r, m in (((8,8,3),(6,6,3.4),'c'), ((5,6,5),(3.4,3.4,3.4),'b'), ((11,6,5),(3.2,3.2,3.2),'c'), ((8,11,6),(3.6,3.6,3.6),'b'), ((7,7,8),(3,3,3),'c')):
        ellipsoid(v, c, r, m)
    for k in surface(v):
        hv = h(*k)
        if k[2] <= 6 and hv % 6 == 0: v[k] = 'a'
        elif k[2] > 3 and hv % 17 == 0: v[k] = 'b'
    for p in ((7,7,12),(9,8,14),(6,8,15),(10,6,13)): v[p] = 'w'
    return v
def m_ore():
    v = {}; ellipsoid(v, (8,8,6), (6.5,5.5,6), 'b')
    for k in list(v):                       # chisel flat facets
        if k[0]+k[2] > 17 or k[1]-k[2] > 6 or k[0]-k[1] > 9: del v[k]
    for k in surface(v):
        if (k[0]+2*k[1]+k[2]) % 7 == 0 and h(*k) % 3: v[k] = 'a'
    ellipsoid(v, (3,11,2), (2.2,2.2,2.2), 'c'); ellipsoid(v, (12,4,1), (2,2,1.6), 'c')
    for (x, y, z0, z1) in ((11,11,0,5),(12,10,0,3),(4,4,0,4)):
        for z in range(z0, z1+1): v[(x,y,z)] = 'w' if z == z1 else 'b'
    return v
def m_slag():
    v = {}
    ellipsoid(v, (8,8,1), (7.5,6.5,2), 'c')
    for k in list(v):
        if k[2] > 2: del v[k]
    for k in list(v):
        if k[2] == 2 and ((k[0]*3 + k[1]*2) % 9 < 2): v[k] = 'a'
    ellipsoid(v, (8,8,3), (3,3,3), 'a')
    v[(8,8,6)] = 'w'; v[(7,8,5)] = 'w'
    for p in ((2,8),(13,6),(8,2),(9,13),(4,12)): box(v, p[0], p[0]+1, p[1], p[1]+1, 0, 2, 'b')
    return v
def m_ingot():
    v = {}
    def bar(x0, y0, z0, mat):
        for x in range(x0, x0+7):
            for y in range(y0, y0+4):
                for z in range(z0, z0+3):
                    inset = 1 if z == z0+2 else 0
                    if x0+inset <= x <= x0+6-inset and y0+(inset and 0) <= y <= y0+3: v[(x,y,z)] = mat
    bar(1,2,0,'b'); bar(8,2,0,'b'); bar(1,9,0,'b'); bar(8,9,0,'b'); bar(4,5,3,'c'); bar(1,5,3,'b'); bar(8,5,3,'b')
    for x in range(4, 11):
        for y in range(5, 9): v[(x,y,6)] = 'b'
    box(v, 5, 9, 6, 7, 6, 7, 'b'); box(v, 6, 8, 6, 7, 8, 8, 'a')
    for p in ((3,3,2),(10,3,2),(3,10,2),(10,10,2)): v[p] = 'a'
    return v
def m_alloy():
    v = {}
    box(v, 4, 11, 5, 10, 0, 2, 'c'); box(v, 6, 9, 6, 9, 3, 5, 'c')
    box(v, 3, 12, 4, 11, 6, 8, 'b');
    for i, x in enumerate((2, 1, 0)):
        box(v, x, x, 6, 9, 7 - i if i < 2 else 7, 7, 'b')
    box(v, 2, 3, 5, 10, 6, 7, 'b')
    box(v, 5, 11, 7, 8, 9, 10, 'a'); box(v, 6, 10, 7, 8, 11, 11, 'w')
    for p in ((4,4,6),(11,11,6)): v[p] = 'w'
    for p in ((8,3,6),(8,12,6)): v[p] = 'a'
    return v
def m_ember():
    v = {}
    box(v, 4, 11, 4, 11, 0, 1, 'c'); box(v, 5, 10, 5, 10, 2, 2, 'c')
    cx, cz = 7.5, 8.2
    for x in range(N):
        for z in range(3, N):
            X = (x - cx) / 5.6; Z = (z - cz) / 5.2
            f = (X*X + Z*Z - 1)**3 - X*X*Z**3
            if f <= 0:
                half = 3 - (1 if f > -0.05 else 0)
                for y in range(8 - half, 8 + half):
                    v[(x, y, z)] = 'b'
    for k in surface(v):
        if k[2] > 3 and ((k[0]*2 + k[2]*3) % 11 == 0): v[k] = 'a'
    for p in ((6,5,10),(6,5,9),(7,5,8),(9,5,11)):
        if p in v: v[p] = 'w'
    return v
MODELS = {"cinder": m_cinder, "ore": m_ore, "slag": m_slag, "ingot": m_ingot, "alloy": m_alloy, "ember": m_ember}

BAYER = [[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]]
def lattice_half(vox):
    out = {}
    cnt = {}
    for (x, y, z), m in vox.items():
        k = (x//2, y//2, z//2); cnt.setdefault(k, []).append(m)
    for k, ms in cnt.items():
        if len(ms) < 3: continue
        for pick in ('w', 'a', 'c', 'b'):
            if pick in ms and (pick in ('w', 'a') or ms.count(pick) >= 2): out[k] = pick; break
        else: out[k] = max(set(ms), key=ms.count)
    return out
def render(vox, tier, frame, n):
    t = TIERS[tier]
    B = [rgb(c) for c in t["body"]]; C = [rgb(c) for c in t["sec"]]; G = [rgb(c) for c in t["glow"]]
    W = 4*n + 8; H = 4*n + 10
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0)); P = img.load()
    ox, oy = W//2, H - 4 - 2*n - 2
    def setpx(x, y, col):
        if 0 <= x < W and 0 <= y < H: P[x, y] = col + (255,)
    for (x, y, z) in sorted(vox, key=lambda k: (k[0]+k[1], k[2], k[0])):
        m = vox[(x, y, z)]
        sx = ox + (x - y)*2; sy = oy + (x + y) - z*2
        g = z / (n - 1)
        for py in range(sy - 1, sy + 4):
            for px in range(sx - 2, sx + 2):
                dx = px - sx + 0.5; dy = py - sy + 0.5
                if abs(dx)/2 + abs(dy) <= 1: face = 0
                elif dx < 0 and dy > (dx + 2)/2 - 0.0 and dy <= 2 + (dx + 2)/2 - 0.0 - 0: face = 1
                elif dx >= 0 and dy > 1 - dx/2 and dy <= 3 - dx/2: face = 2
                else: continue
                bay = BAYER[py & 3][px & 3] / 16.0
                up = 1 if g > 0.5 + (bay - 0.5)*0.12 else 0  # hard band; dither only in a thin transition
                if m in 'bc':
                    ramp = B if m == 'b' else C
                    base = (3, 2, 1)[face]
                    col = ramp[min(4, base + up)] if face != 2 or g > 0.35 else ramp[base]
                    
                elif m == 'a':
                    flick = 1 if ((x*3 + y*5 + z + frame*2) % 4 == 0 and bay < 0.7) else 0
                    col = G[min(3, (2, 1, 0)[face] + 1 + flick) if face == 0 else min(3, (2, 1, 0)[face] + flick)]
                else:
                    col = G[3] if (frame + x + y) % 3 else G[2]
                setpx(px, py, col)
    ink = B[0]; out = img.copy(); Q = out.load()
    for y in range(H):
        for x in range(W):
            if P[x, y][3] == 0:
                for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < W and 0 <= ny < H and P[nx, ny][3]: Q[x, y] = ink + (255,); break
    return out.crop(out.getbbox())
def fit(im, size):
    w, h_ = im.size; s = min((size-2)/w, (size-2)/h_)
    nw, nh = max(1, round(w*s)), max(1, round(h_*s))
    r = im.resize((nw, nh), Image.NEAREST)
    c = Image.new("RGBA", (size, size), (0, 0, 0, 0)); c.paste(r, ((size-nw)//2, size-nh-1), r); return c
def main(out):
    os.makedirs(out, exist_ok=True)
    names = list(MODELS)
    rows = []
    for n in names:
        full = MODELS[n](); half = lattice_half(full)
        hero = [render(full, n, f, 16) for f in range(3)]
        game = [render(half, n, f, 8) for f in range(3)]
        for f in range(3):
            hero[f].save(f"{out}/{n}_hero_f{f}.png"); game[f].save(f"{out}/{n}_game_f{f}.png")
        hero[0].save(f"{out}/{n}_hero.png"); game[0].save(f"{out}/{n}_game.png")
        for s in (32, 16, 8): fit(game[0] if s < 32 else hero[0], s).save(f"{out}/{n}_{s}.png")
        rows.append((n, hero, game))
    pv = Image.new("RGB", (len(names)*150, 330), (26, 17, 22))
    for i, (n, hero, game) in enumerate(rows):
        x0 = i*150 + 6
        pv.paste(hero[0], (x0, 8), hero[0])
        for f in range(3): pv.paste(game[f], (x0 + f*34, 90), game[f])
        for j, s in enumerate((32, 16, 8)):
            ic = Image.open(f"{out}/{n}_{s}.png"); pv.paste(ic, (x0 + (0, 36, 56)[j], 132), ic)
        big = game[0].resize((game[0].width*3, game[0].height*3), Image.NEAREST); pv.paste(big, (x0, 170), big)
    pv.save(f"{out}/ladder_preview.png")
if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "assets/art/zone2/ladder")
