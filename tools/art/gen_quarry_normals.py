"""Normal maps for the Ember Quarry props (assets/art/zone2/quarry/sprites).

Each sprite gets a `<name>_n.png` beside it, same size. The props are hand-drawn 2D sprites with no 3D render behind
them, so the normal is read from the sprite's own silhouette: alpha, blurred into a soft height field, then its slope.
Edges tilt away from the middle, so a rock's rim faces the lava and lamps that light it.

Encoding (read by render/shaders/quarry_prop.gdshader):
  R, G  normal x and y, encoded n * .5 + .5 (y runs down the image, like the texture). z is rebuilt in the shader.
  B     alpha, so the shader knows which texels are the sprite.
  A     alpha.

Usage: python3 tools/art/gen_quarry_normals.py   (rerun after the sprites are regenerated)
"""
import glob
import os

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'art', 'zone2', 'quarry', 'sprites')
BLUR_SIGMA = 2.0      # texels: softens the silhouette into a height field
SLOPE = 2.5           # how steep the edge tilts; higher = more rim
ALPHA_CUT = 0.5


def gaussian_blur(a, sigma):
    """Separable Gaussian with numpy only (no SciPy needed)."""
    r = int(np.ceil(sigma * 3))
    k = np.exp(-(np.arange(-r, r + 1) ** 2) / (2 * sigma * sigma))
    k /= k.sum()
    pad = np.pad(a, r, mode='constant')
    tmp = np.apply_along_axis(lambda row: np.convolve(row, k, mode='same'), 1, pad)
    out = np.apply_along_axis(lambda col: np.convolve(col, k, mode='same'), 0, tmp)
    return out[r:-r, r:-r]


def normal_map(rgba):
    alpha = rgba[..., 3].astype(np.float64) / 255.0
    solid = (alpha >= ALPHA_CUT).astype(np.float64)
    height = gaussian_blur(solid, BLUR_SIGMA)
    dy, dx = np.gradient(height)
    nx = -dx * SLOPE
    ny = -dy * SLOPE
    nz = np.ones_like(nx)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny = nx / length, ny / length
    out = np.zeros(rgba.shape, np.uint8)
    out[..., 0] = np.clip(np.round((nx * .5 + .5) * 255), 0, 255)
    out[..., 1] = np.clip(np.round((ny * .5 + .5) * 255), 0, 255)
    out[..., 2] = rgba[..., 3]
    out[..., 3] = rgba[..., 3]
    return out


def main():
    paths = sorted(p for p in glob.glob(os.path.join(ROOT, '*.png')) if not p.endswith('_n.png'))
    for p in paths:
        img = np.asarray(Image.open(p).convert('RGBA'))
        Image.fromarray(normal_map(img)).save(p[:-4] + '_n.png')
    print('wrote %d normal maps' % len(paths))


if __name__ == '__main__':
    main()
