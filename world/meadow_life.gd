class_name MeadowLife
extends RefCounted
## Shared pieces of the zone 1 world life. The layers are life_ground.gd (grass under the walker)
## and life_air.gd (fireflies, pollen, butterflies, glow, sparkles, pad shimmer). Data comes from
## world/meadow_life.json, written by tools/art/gen_life_anchors.py from the baked backdrop.

const DATA_PATH: String = "res://world/meadow_life.json"

## Set by the settings screen (M4). Stops drifting, sway and wandering. Blinks, glows and twinkles stay,
## because they change in place rather than travel.
static var reduce_motion: bool = false

## Wind strength 0..1, written by SkyCycle each frame. LifeGround leans the grass tips further in a gust.
static var wind: float = 0.2

## Time of day and weather, written by SkyCycle each frame so the air layer can tune itself: fireflies come out at
## dusk and stay through the night, pollen and dust motes belong to the day and catch the low sun.
static var night: float = 0.0      # 0 day .. 1 deep night
static var low_sun: float = 0.0    # 1 at golden hour, sunrise and sunset
static var rain: float = 0.0       # 0..1

## 4x4 Bayer matrix, art-bible section 2. Threshold for index i is (BAYER[i] + 0.5) / 16.
const BAYER: Array = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]


static func load_data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return parsed as Dictionary if parsed is Dictionary else {}


## Deterministic hash in [0, 1). The same n always gives the same value, so layouts never reshuffle.
static func hash01(n: int) -> float:
	return fposmod(sin(float(n) * 12.9898 + 78.233) * 43758.5453, 1.0)


## Ordered-dither threshold for a texel, in (0, 1).
static func bayer(x: int, y: int) -> float:
	return (float(BAYER[(y & 3) * 4 + (x & 3)]) + 0.5) / 16.0
