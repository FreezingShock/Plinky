"""Mark the meadow's south sea as water in its G-buffer (ground_n.png, blue channel = material code).

The sea is painted into ground.png in the water ramp, but gen_meadow3d.py leaves those texels at code 0, so the
glow (render/shaders/water_night.gdshader) and the ground relight skip them. This script sets code 110 (deep)
or 111 (shallow) on code-0 texels whose colour is the sea's painted colour, and changes nothing else (R, G, A and every
other code are kept). Run once from the repo root: python3 tools/art/water_sea_mask.py <dir>
Default dir: assets/art/zone1/meadow3d. Re-run it after any regeneration of ground.png or ground_n.png.
"""
import os
import sys

import numpy as np
from PIL import Image

# New codes for the sea, each with a one-entry ramp in prop_ramps.gdshaderinc (see gen_meadow3d.py), so the relight
# keeps the painted colour: 110 = deep sea (palette 1), 111 = shallow sea (palette 2).
SEA_CODES = {(31, 59, 53): 110, (47, 107, 85): 111}


def main(folder: str) -> None:
    ground = np.asarray(Image.open(os.path.join(folder, 'ground.png')).convert('RGBA')).astype(np.int32)
    path = os.path.join(folder, 'ground_n.png')
    n_img = Image.open(path).convert('RGBA')
    n = np.asarray(n_img).copy()
    sea = np.zeros(ground.shape[:2], bool)
    for rgb, code in SEA_CODES.items():
        hit = (ground[..., 0] == rgb[0]) & (ground[..., 1] == rgb[1]) & (ground[..., 2] == rgb[2]) & (ground[..., 3] > 0) & (n[..., 2] == 0)
        n[..., 2][hit] = code
        sea |= hit
        print('colour %s -> code %d: %d texels' % (rgb, code, int(hit.sum())))
    Image.fromarray(n, 'RGBA').save(path)
    print('sea texels marked: %d of %d' % (int(sea.sum()), sea.size))


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'assets/art/zone1/meadow3d')
