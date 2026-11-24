"""Shared depth pass for the baked 3D scenes (gen_meadow3d.py, gen_larkmoor.py).

Screen-space work on the z-buffer of the finished render, done before the Bayer dither so every effect
lands as a lighting band shift and stays inside the palette:
  ao   contact / crevice occlusion. A pixel darkens when neighbours within a few texels sit higher in world z,
       so petals separate from stems, leaf balls from each other, and props sit on the ground.
  rim  a one texel lit edge on the sun side of any object, one pixel in from the ink outline.
  lean a small lift on surfaces higher than their surroundings (tops of petals, crowns), which reads as relief.
Pure numpy. Returns additive light terms, the caller adds them to its light image."""
import numpy as np

RINGS = ((1, .55), (2, 1.0), (3, .8), (5, .6), (8, .45))          # (radius in texels, weight)
DIRS = ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1))


def _shift(a, dx, dy, fill):
    out = np.full_like(a, fill)
    h, w = a.shape
    ys0, ys1 = max(0, dy), min(h, h + dy); xs0, xs1 = max(0, dx), min(w, w + dx)
    out[ys0:ys1, xs0:xs1] = a[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx]
    return out


def compute(img_z, img_id, light_xy, detail=None, strength_ao=.62, strength_rim=.55, strength_lean=.18):
    """img_z: world height per pixel (any value where img_id == -1). img_id: object id, -1 empty.
    light_xy: unit screen vector pointing toward the sun (x right, y down). Returns (ao, rim, lean), each H x W,
    ao in 0..1 (1 = fully occluded), rim 0..1, lean -1..1."""
    has = img_id >= 0
    solid = (img_id >= 10) | (detail if detail is not None else False)   # detail: ground-cover texels (flowers, tufts) that share the terrain id
    z = np.where(has, img_z, -1e4).astype(np.float32)
    # only props occlude: terrain steps (cliff lips, path edges) must not grow dark seams
    zo = np.where(solid, img_z, -1e4).astype(np.float32)
    occ = np.zeros(z.shape, np.float32); wsum = 0.0
    for r, wgt in RINGS:
        for dx, dy in DIRS:
            k = r * (.7071 if dx and dy else 1.0)
            nz_ = _shift(zo, int(round(dx * k)), int(round(dy * k)), -1e4)
            # a neighbour only occludes when it stands clearly above this pixel; the ramp saturates at 7 units
            dz = nz_ - z - 1.2
            occ += wgt * np.clip(dz / 7.0, 0, 1) * np.clip((13.0 - dz) / 5.0, 0, 1)   # things far above do not contact-shade
            wsum += wgt
    ao = np.where(has, np.clip(occ / wsum * 3.2, 0, 1), 0).astype(np.float32)
    lx, ly = light_xy
    sx_, sy_ = int(round(lx * 2)), int(round(ly * 2))
    toward = _shift(img_id, -sx_, -sy_, -1)
    toward_z = _shift(z, -sx_, -sy_, -1e4)
    open_side = (toward != img_id) | (toward_z < z - 4.0)
    ink_side = _shift(img_id, -int(np.sign(lx)), -int(np.sign(ly)), -1) != img_id     # the texel next to us is the outline
    rim = (has & solid & (img_id >= 10) & open_side & ~ink_side).astype(np.float32)
    avg = np.zeros(z.shape, np.float32); n = 0
    for dx, dy in DIRS:
        avg += _shift(np.where(has, img_z, 0).astype(np.float32), 3 * dx, 3 * dy, 0); n += 1
    lean = np.where(has & solid, np.clip((img_z - avg / n) / 6.0, -1, 1), 0).astype(np.float32)
    return strength_ao * ao, strength_rim * rim, strength_lean * lean


# ---- runtime relight data (consumed by render/shaders/wind_sway.gdshader through world/prop_relight.gd) ----
# One RGBA "_n.png" beside each tall-prop sprite, same size:
#   R, G  world-space normal x (u) and y (v), encoded n * .5 + .5; nz is rebuilt as sqrt(1 - x^2 - y^2)
#   B     material code (the RAMP key, 10..47) for lit texels; 0 for outline ink, which is never relit
#   A     baked light value l, encoded (l + .4) / 1.8, never below 1/255 inside the sprite
# The shader keeps the baked texel while the sun is near the baked sun and re-quantises through the material ramp otherwise.
L_ENC_OFF, L_ENC_SCALE = .4, 1.8


def write_relight_data(path, aux, y0, y1, x0, x1, mask):
    from PIL import Image
    sl = (slice(y0, y1 + 1), slice(x0, x1 + 1))
    d = np.zeros(mask.shape + (4,), np.uint8)
    d[..., 0] = np.clip((aux['nu'][sl] * .5 + .5) * 255, 0, 255)
    d[..., 1] = np.clip((aux['nv'][sl] * .5 + .5) * 255, 0, 255)
    mat = aux['mat'][sl]
    lit = mask & (aux['out'][sl] != 0) & (mat >= 10) & (mat < 112)
    d[..., 2] = np.where(lit, mat, 0)
    d[..., 3] = np.where(mask, np.clip(np.round((aux['l'][sl] + L_ENC_OFF) / L_ENC_SCALE * 255), 1, 255), 0)
    Image.fromarray(d).save(path)


def write_height(path, z, mask):
    """Greyscale world height for AO and shadows: 1..255 inside the scene (z scaled to the scene's own range), 0 outside."""
    from PIL import Image
    zz = np.where(mask, z, 0.0)
    lo, hi = float(zz[mask].min()), float(zz[mask].max())
    d = np.where(mask, 1 + np.clip((zz - lo) / max(hi - lo, 1e-6), 0, 1) * 254, 0).astype(np.uint8)
    Image.fromarray(d).save(path)


def write_ramp_include(path, ramp, pal, mat_lo=10, mat_hi=112):
    """Shader include with the palette and the per-material ramps, so the shader quantises to the same colours as the baker."""
    starts, lens, idx = [], [], []
    for m in range(mat_hi):
        r = ramp.get(m) if m >= mat_lo else None
        starts.append(len(idx)); lens.append(len(r) if r else 0)
        idx.extend(r or [])
    cols = ', '.join('vec3(%.5f, %.5f, %.5f)' % tuple(int(h[k:k + 2], 16) / 255 for k in (1, 3, 5)) for h in pal)
    open(path, 'w').write('// Generated by tools/art/depth_pass.py write_ramp_include from gen_meadow3d.py. Do not edit.\n'
        'const vec3 PAL[8] = vec3[8](%s);\nconst int RAMP_START[%d] = int[%d](%s);\nconst int RAMP_LEN[%d] = int[%d](%s);\nconst int RAMP_IDX[%d] = int[%d](%s);\n'
        % (cols, mat_hi, mat_hi, ', '.join(map(str, starts)), mat_hi, mat_hi, ', '.join(map(str, lens)), len(idx), len(idx), ', '.join(map(str, idx))))
