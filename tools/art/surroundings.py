"""Shared backdrop for the zone 1 generators: sky, a panoramic mountain range that rises behind the island
and falls away into foothills, shoreline, and open water. See docs/style-guide.md (Backdrop).
paint(out, ...) fills every texel of `out` that is still -1 (nothing drawn there). Palette indices only."""
import numpy as np

def _smooth_cols(a, k):
    ker = np.ones(2 * k + 1) / (2 * k + 1)
    return np.convolve(np.pad(a, (k, k), mode='edge'), ker, mode='valid')

def paint(out, W, H, XX, YY, dith, vn2, fbm2, hor, water_scale):
    emp = out < 0
    if not emp.any():
        return
    xs = np.arange(W)
    HOR = hor + 3 * np.sin(XX * .05) + 2 * (vn2(XX / 23.0, YY * 0 + 3, 70) - .5)       # shoreline wobbles, no ruler-straight cut
    horc = HOR[0]
    # where the island's top edge sits per column, smoothed so the range can wrap around it
    solid = ~emp
    has = solid.any(0)
    crest = np.where(has, solid.argmax(0), H).astype(float)
    wgt = _smooth_cols(has.astype(float), 70)
    crest_s = _smooth_cols(np.where(has, crest, 0.0), 70) / np.maximum(wgt, 1e-3)
    cover = np.clip(wgt * 1.35, 0, 1); cover = cover * cover * (3 - 2 * cover)
    cover = cover * np.clip((hor + 14 - crest_s) / 14.0, 0, 1)                         # only where the island's crest rises into the sky (Larkmoor's sits below the horizon)           # 0 away from the island, 1 behind it
    sky = dith([0, 1, 1, 2], .15 + .75 * (YY / float(hor)) ** 1.2, emp)
    res = np.where(YY < HOR, sky, -1)
    # far to near: (base, free amplitude, feature size, ramp, seed, lift above the island crest, haze 0..1)
    layers = ((hor + 4, 84, 120, [1, 2], 5, 17, .55), (hor + 8, 60, 80, [1, 2, 2, 3], 6, 10, .3), (hor + 12, 34, 52, [2, 3, 3, 4], 7, 3, 0.0))
    land_any = np.zeros((H, W), bool)
    for k, (base, amp, fr, ramp, sd, lift, haze) in enumerate(layers):
        rid = 1 - np.abs(2 * fbm2(xs / float(fr) + k * 17, np.zeros(W), 4, sd) - 1)
        free = base - amp * rid ** 1.05 - 10                                              # away from the island
        wrapped = crest_s - lift - 0.55 * amp * rid ** 1.05 * (0.35 + .65 * (1 - k / 3.0)) # behind the island: tops out above its crest
        top_ = free * (1 - cover) + wrapped * cover
        m_ = max(hor - 160.0, 6.0) + 10 * k                                                      # soft floor: peaks stay inside the 640x360 frame, no flat shelf
        top_ = m_ + 7.0 * np.log1p(np.exp((np.minimum(top_, base - 3) - m_) / 7.0))
        top_ = _smooth_cols(top_, 1)
        below = YY >= top_[None, :]
        slope_ = np.clip(np.roll(top_, -2) - np.roll(top_, 2), -4, 4)
        depth = YY - top_[None, :]
        lit = np.clip(.5 - slope_[None, :] * .10 + (vn2((XX + YY * .6) / 6.0, YY / 4.0, sd + 3) - .5) * .30 - np.clip(depth, 0, 60) * .004, 0, .99)
        mt = dith(ramp, lit, emp)
        if k == 2:
            mt = np.where((mt == 3) & (vn2(XX / 2.0, YY / 2.0, 80) > .72), 2, mt)         # tree stipple on the foothills
        if haze > 0:                                                                      # atmospheric fade: lower flanks dissolve toward the mist
            bay = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]])[YY & 3, XX & 3] + .5) / 16
            fade = np.clip(depth / 46.0, 0, 1) * haze
            mt = np.where(bay < fade, np.maximum(ramp[0], 1), mt)
        res = np.where(below & (YY < HOR + 5), mt, res)
        land_any |= below
    # valley mist band where the range meets the water, so there is no hard horizon line
    bay4 = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]])[YY & 3, XX & 3] + .5) / 16
    mist = (YY < HOR) & (YY > HOR - 9) & (bay4 < (1 - (HOR - YY) / 9.0) * .45) & land_any
    res = np.where(mist, 2, res)
    wt = np.clip(.52 - (YY - HOR) / water_scale + (vn2(XX / 9.0, YY / 2.5, 60) - .5) * .30, 0, .99)
    wat = dith([1, 2, 2, 3], wt, emp)
    wat = np.where((wat <= 2) & (YY % 4 == 0) & (vn2(XX / 3.0, YY / 1.0, 61) > .86), 3, wat)
    wat = np.where((wat == 1) & (YY % 6 == 2) & (vn2(XX / 14.0, YY / 1.0, 63) > .55), 2, wat)      # long swell rows break the flat fill
    wat = np.where((wat == 2) & (YY % 6 == 5) & (vn2(XX / 9.0, YY / 1.0, 64) > .72), 3, wat)
    wat = np.where((vn2(XX / 3.0, YY / 1.2, 62) > .93) & (YY % 3 == 0), 4, wat)
    d = YY - HOR
    refl = (d >= 0) & (d < 18) & (bay4 < (1 - d / 18.0) * .8)                              # the range reflects in the water
    wat = np.where(refl, np.minimum(wat, 2), wat)
    shore = (d >= 0) & (d < 2) & (vn2(XX / 4.0, YY * 0 + 5, 71) > .38) & (((XX + YY) & 1) == 0)  # thin foam line at the foot of the hills
    wat = np.where(shore, 4, wat)
    res = np.where(YY >= HOR, wat, res)
    out[emp] = res[emp]
