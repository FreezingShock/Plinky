#!/usr/bin/env python3
"""Ember Quarry ladder art: six tier objects, each as 16x16 master with 3 flicker frames
plus an 8x8 icon and a 32x32 icon. Palette-indexed (Ember Quarry roles 0-7).
Usage: python3 tools/art/gen_quarry_ladder.py [outdir]"""
import sys, os
from PIL import Image
PAL = ["1a1116","4a1f2a","8a3a2e","d0602f","e9a845","b77a7a","5b3d5c","f1d9b5"]
RGB = [tuple(int(h[i:i+2],16) for i in (0,2,4)) for h in PAL]
FLICK = {0:4, 1:7, 2:3}   # 'a' pixel colour per frame (hot spots shimmer)
FLICK2 = {0:7, 1:4, 2:4}  # 'b'
def grid(rows, n):
    rows = [r.ljust(n,'.') for r in rows]
    rows += ['.'*n]*(n-len(rows))
    assert all(len(r)==n for r in rows), rows
    return rows
def px(rows, n, f):
    im = Image.new("RGBA",(n,n),(0,0,0,0))
    for y,r in enumerate(grid(rows,n)):
        for x,c in enumerate(r):
            if c=='.': continue
            i = FLICK[f] if c=='a' else FLICK2[f] if c=='b' else int(c)
            im.putpixel((x,y),RGB[i]+(255,))
    return im
M16 = {
"cinder": ["", "", "......a.b.......", ".......a........", ".....00000......", "...0012210......", "..012a22210.....", ".0122122b2210...", ".0122a12221210..", ".01222122a22210.", "..012222122210..", "...0112222110...", "....0001111000.."],
"ore": ["", "", "", "", "....0000000.....", "...016666610....", "..01666655510...", ".016664444610...", ".0166644b4661...", ".016666444661...", ".0166666666110..", "..01111111110...", "...0000000000..."],
"slag": ["", ".......b........", "......a.a.......", ".......a........", "", "....0000........", "..0033330.......", ".033a3333300....", ".03433b33a330...", ".0233333333320..", "..02222222220...", "...0011111100...", "....00000000...."],
"ingot": ["", "", "", "", "....000000......", "...04444440.....", "..0477777340....", "..0033333300....", ".0000000000000..", ".044444444444400", ".047777777773400", ".003333333333300", "..000000000000.."],
"alloy": ["", "...00000000000..", "..0555555544410.", "..0577777444310.", "..0333333333300.", "...0000000000...", ".....0666660....", "......06660.....", ".....0666660....", "...0066666600...", "..066666666660..", "..011111111110..", "...0000000000..."],
"ember": ["", "...000...000....", "..03330.03330...", ".0377a3033b330..", ".037744433a330..", ".0374444444330..", "..04444444430...", "...044444430....", "....0444430.....", ".....04430......", "......030.......", ".......0........"],
}
M8 = {
"cinder": ["", "", "..0a0...", ".01221..", "012a210.", "01222210", ".011110."],
"ore": ["", "", "..0000..", ".016610.", "01644610", "01666610", ".011110."],
"slag": ["", ".a.b....", "", ".0330...", "03a3b30.", ".02220..", "..000..."],
"ingot": ["", "", "..0000..", ".047340.", "00000000", "04773340", "00000000"],
"alloy": ["", "00000000", "05774430", ".000000.", "..0660..", ".066660.", ".000000."],
"ember": ["", "00.00...", "0440440.", "04a444b0", ".04444 0.".replace(' ',''), "..0440..", "...00..."],
}
def icon32(rows, f):
    big = px(rows,16,f).resize((32,32),Image.NEAREST)
    out = big.copy(); P=out.load(); B=big.load()
    # ink outline drawn inside the 2x blocks' neighbours plus a lit edge on the top-left
    for y in range(32):
        for x in range(32):
            if B[x,y][3]==0:
                for dx,dy in ((1,0),(-1,0),(0,1),(0,-1)):
                    nx,ny=x+dx,y+dy
                    if 0<=nx<32 and 0<=ny<32 and B[nx,ny][3] and B[nx,ny][:3]!=RGB[0]:
                        P[x,y]=RGB[0]+(255,)
    for y in range(1,32):
        for x in range(1,32):
            c=B[x,y]
            if c[3] and c[:3] not in (RGB[0],RGB[7]) and B[x-1,y-1][3]==0 and (x+y)%2==0:
                P[x,y]=RGB[7]+(255,)  # bayer-ish rim light
    return out
def main(out):
    os.makedirs(out,exist_ok=True)
    names=list(M16)
    sheet = Image.new("RGBA",(16*3*len(names)//1,16),(0,0,0,0))
    for i,n in enumerate(names):
        for f in range(3):
            px(M16[n],16,f).save(f"{out}/{n}_16_f{f}.png")
            sheet.paste(px(M16[n],16,f),((i*3+f)*16,0))
        px(M8[n],8,0).save(f"{out}/{n}_8.png")
        icon32(M16[n],0).save(f"{out}/{n}_32.png")
    sheet.save(f"{out}/ladder_frames_1x.png")
    # preview: 6x on a quarry-dark ground, 16 frames row + 8 and 32 icons
    S=6; W=len(names)*(32*S//2+8)
    pv=Image.new("RGB",(len(names)*110, 330),RGB[1]); 
    for i,n in enumerate(names):
        for f in range(3):
            pv.paste(px(M16[n],16,f).resize((32,32),Image.NEAREST),(i*110+f*34,6),px(M16[n],16,f).resize((32,32),Image.NEAREST))
        pv.paste(px(M16[n],16,0).resize((96,96),Image.NEAREST),(i*110+4,50),px(M16[n],16,0).resize((96,96),Image.NEAREST))
        pv.paste(px(M8[n],8,0).resize((48,48),Image.NEAREST),(i*110+4,160),px(M8[n],8,0).resize((48,48),Image.NEAREST))
        pv.paste(icon32(M16[n],0),(i*110+56,160),icon32(M16[n],0))
        pv.paste(icon32(M16[n],0).resize((96,96),Image.NEAREST),(i*110+4,215),icon32(M16[n],0).resize((96,96),Image.NEAREST))
    pv.save(f"{out}/ladder_preview.png")
if __name__=="__main__":
    main(sys.argv[1] if len(sys.argv)>1 else "assets/art/zone2/ladder")
