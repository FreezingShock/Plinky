"""Shared depth pass for the baked 3D scenes (gen_meadow3d.py, gen_larkmoor.py).

Screen-space work on the z-buffer of the finished render, done before the Bayer dither so every effect
lands as a lighting band shift and stays inside the palette:
  ao   contact / crevice occlusion. A pixel darkens when neighbours within a few texels sit higher in world z,
       so petals separate from stems, leaf balls from each other, and props sit on the ground.
  rim  a one texel lit edge on the sun side of any object, one pixel in from the ink outline.
  lean a small lift on surfaces higher than their surroundings (tops of petals, crowns), which reads as relief.
Pure numpy. Returns additive light terms, the caller adds them to its light image."""
import numpy as np

RINGS = ((1, .55), (2, 1.0), (3, .8), (5, .6))          # (radius in texels, weight)
DIRS = ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1))


def _shift(a, dx, dy, fill):
    out = np.full_like(a, fill)
    h, w = a.shape
    ys0, ys1 = max(0, dy), min(h, h + dy); xs0, xs1 = max(0, dx), min(w, w + dx)
    out[ys0:ys1, xs0:xs1] = a[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx]
    return out


def compute(img_z, img_id, light_xy, strength_ao=.42, strength_rim=.30, strength_lean=.10):
    """img_z: world height per pixel (any value where img_id == -1). img_id: object id, -1 empty.
    light_xy: unit screen vector pointing toward the sun (x right, y down). Returns (ao, rim, lean), each H x W,
    ao in 0..1 (1 = fully occluded), rim 0..1, lean -1..1."""
    has = img_id >= 0
    z = np.where(has, img_z, -1e4).astype(np.float32)
    # only props occlude: terrain steps (cliff lips, path edges) must not grow dark seams
    zo = np.where(img_id >= 10, img_z, -1e4).astype(np.float32)
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
    rim = (has & (img_id >= 10) & open_side & ~ink_side).astype(np.float32)
    avg = np.zeros(z.shape, np.float32); n = 0
    for dx, dy in DIRS:
        avg += _shift(np.where(has, img_z, 0).astype(np.float32), 3 * dx, 3 * dy, 0); n += 1
    lean = np.where(has & (img_id >= 10), np.clip((img_z - avg / n) / 6.0, -1, 1), 0).astype(np.float32)
    return strength_ao * ao, strength_rim * rim, strength_lean * lean
