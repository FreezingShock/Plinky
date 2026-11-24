class_name LavaFlicker
extends RefCounted
## Flicker for the Ember Quarry's light sources (lava, vents, braziers, lamps). Pure: time in, number out, no nodes.
## Steps at 6 fps, so a flame never changes faster than the 6 fps limit in docs/decisions/art.md. The same inputs give
## the same value on every machine, so the tests can pin it.

const STEP_HZ: float = 6.0


## Frame index for time t (seconds). Constant for 1/6 s at a time.
static func frame(t: float) -> int:
	return int(floorf(maxf(t, 0.0) * STEP_HZ))


## Pseudo-random value in 0..1 for one source and one frame.
static func hash01(id: int, f: int) -> float:
	var n: float = sin(float(id) * 12.9898 + float(f) * 78.233) * 43758.5453
	return n - floorf(n)


## Brightness multiplier for one source: 1.0 at most, down to 1.0 - depth. Steady (Reduce Motion or Reduce Flashing)
## returns 1.0 for everything.
static func level(t: float, id: int, depth: float, steady: bool) -> float:
	if steady or depth <= 0.0:
		return 1.0
	return 1.0 - clampf(depth, 0.0, 1.0) * hash01(id, frame(t))
