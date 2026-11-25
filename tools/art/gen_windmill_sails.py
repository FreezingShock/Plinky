"""Larkmoor windmill sails: pre-rendered turning frames about the hub.

Reads the sails sprite that tools/art/gen_larkmoor.py exports (`windmill_sails_900001.png`, kind `windmill_sails`)
and its foot from assets/art/zone1b/larkmoor/placements3d.json. Writes eight frames that turn the sails from 0 to
78.75 degrees in 11.25 degree steps. Four arms repeat every 90 degrees, so the sheet loops with no seam.

Rotation is nearest-neighbour: every output texel samples the source texel under it, so the pixel art stays crisp.
A live rotation of a pixel sprite would blur and shimmer, which is why the turn is baked into frames.

Output: assets/art/zone1b/larkmoor/windmill_sails_sheet.png (8 frames side by side) and
windmill_sails_sheet.json (frame size, frame count, and the offset that puts the hub on the sprite's foot).

Run: python3 tools/art/gen_windmill_sails.py
"""
import json
import math
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
ZONE = os.path.join(ROOT, 'assets', 'art', 'zone1b', 'larkmoor')
FRAMES = 8
STEP_DEG = 90.0 / FRAMES          # 11.25 degrees; four arms make 90 degrees the loop


def load_sails():
    data = json.load(open(os.path.join(ZONE, 'placements3d.json')))
    s = next(sp for sp in data['sprites'] if sp['kind'] == 'windmill_sails')
    img = Image.open(os.path.join(ZONE, s['file'])).convert('RGBA')
    fx, fy = float(s['foot'][0]), float(s['foot'][1])
    hub = (fx - float(s['x']), fy - float(s['y']))        # the hub in source texels
    return img, hub, (fx, fy)


def rotated_frame(src: np.ndarray, hub_src, frame_size: int, hub_frame, angle_deg: float) -> np.ndarray:
    """One frame: each output texel samples the source texel under it after rotating about the hub."""
    a = math.radians(-angle_deg)                          # sample with the inverse rotation
    ca, sa = math.cos(a), math.sin(a)
    h, w = src.shape[:2]
    ys, xs = np.mgrid[0:frame_size, 0:frame_size]
    px = xs + 0.5 - hub_frame[0]
    py = ys + 0.5 - hub_frame[1]
    sx = hub_src[0] + ca * px - sa * py
    sy = hub_src[1] + sa * px + ca * py
    ix = np.floor(sx).astype(int)
    iy = np.floor(sy).astype(int)
    inside = (ix >= 0) & (ix < w) & (iy >= 0) & (iy < h)
    out = np.zeros((frame_size, frame_size, 4), dtype=np.uint8)
    out[inside] = src[iy[inside], ix[inside]]
    return out


def main() -> int:
    img, hub, foot = load_sails()
    src = np.array(img)
    h, w = src.shape[:2]
    # Radius from the hub to the furthest opaque texel, so no arm is clipped at any angle.
    ys, xs = np.nonzero(src[..., 3] > 0)
    dist = np.hypot(xs + 0.5 - hub[0], ys + 0.5 - hub[1])
    rc = int(math.ceil(float(dist.max()))) + 1
    size = 2 * rc
    # Keep the source texel grid aligned: source texel (floor(hub.x), floor(hub.y)) lands on frame texel (rc, rc).
    hub_frame = (rc + (hub[0] - math.floor(hub[0])), rc + (hub[1] - math.floor(hub[1])))
    frames = [rotated_frame(src, hub, size, hub_frame, k * STEP_DEG) for k in range(FRAMES)]
    sheet = np.concatenate(frames, axis=1)
    out_dir = ZONE
    Image.fromarray(sheet, 'RGBA').save(os.path.join(out_dir, 'windmill_sails_sheet.png'))
    # The sprite's position is the foot. Its texture origin must be a whole texel, so the offset carries the fraction.
    offset = [-float(rc), -float(rc) - (foot[1] - math.floor(foot[1])) ]
    manifest = {'file': 'windmill_sails_sheet.png', 'frames': FRAMES, 'frame': size,
                'offset': offset, 'step_deg': STEP_DEG}
    with open(os.path.join(out_dir, 'windmill_sails_sheet.json'), 'w') as f:
        json.dump(manifest, f, indent=1)
    print('wrote windmill_sails_sheet.png', sheet.shape[1], 'x', sheet.shape[0], 'offset', offset)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
