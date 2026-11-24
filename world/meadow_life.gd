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
static var wet: float = 0.0        # 0..1 ground wetness (SkyCycle: a lagged rain, 0 under snow)

## Season mix (spring, summer, autumn, winter), written by SkyCycle with the same weights SeasonParticles gets, so
## butterflies and fireflies can follow the calendar: butterflies are a spring and summer thing, fireflies a summer one.
static var season: Array[float] = [1.0, 0.0, 0.0, 0.0]


## How many of the `full` butterflies are out: none at night or in winter, a few in autumn, most in summer, fewer in rain.
static func butterfly_share() -> float:
	var s: Array[float] = season
	var by_season: float = s[0] * 0.8 + s[1] * 1.0 + s[2] * 0.35 + s[3] * 0.0
	var by_light: float = clampf(1.0 - night * 1.6 - low_sun * 0.35, 0.0, 1.0)
	return by_season * by_light * (1.0 - rain)


## How many of the `full` fireflies come out: the season's share (a summer thing), times the dark.
static func firefly_season_share() -> float:
	var s: Array[float] = season
	return s[0] * 0.7 + s[1] * 1.0 + s[2] * 0.45 + s[3] * 0.0


## 4x4 Bayer matrix, art-bible section 2. Threshold for index i is (BAYER[i] + 0.5) / 16.
const BAYER: Array = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]


static func load_data(path: String = DATA_PATH) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


## Deterministic hash in [0, 1). The same n always gives the same value, so layouts never reshuffle.
static func hash01(n: int) -> float:
	return fposmod(sin(float(n) * 12.9898 + 78.233) * 43758.5453, 1.0)


## Ordered-dither threshold for a texel, in (0, 1).
static func bayer(x: int, y: int) -> float:
	return (float(BAYER[(y & 3) * 4 + (x & 3)]) + 0.5) / 16.0


## True when a critter at texel (x, y) should show at this fade level: a fade of 0.5 draws half the texels, by dither.
static func dissolved(fade: float, x: int, y: int) -> bool:
	return fade >= 1.0 or bayer(x, y) < fade


## The season mix weighted by the four values in `w` (spring, summer, autumn, winter).
static func season_mix(w: Array) -> float:
	var s: Array[float] = season
	return s[0] * float(w[0]) + s[1] * float(w[1]) + s[2] * float(w[2]) + s[3] * float(w[3])


## Distance between two points in the view's 2:1 units: y counts double, as everywhere in the world.
static func iso_distance(a: Vector2, b: Vector2) -> float:
	return Vector2(a.x - b.x, (a.y - b.y) * 2.0).length()


## True when p is within r texels of any point in pts.
static func near_any(p: Vector2, pts: Array[Vector2], r: float) -> bool:
	for q: Vector2 in pts:
		if p.distance_squared_to(q) < r * r:
			return true
	return false


## Normalised radius of p inside a water ellipse: below 1 is water, 1 is the edge, above 1 is land.
static func water_k(p: Vector2, w: Dictionary) -> float:
	var dx: float = (p.x - float(w.x)) / float(w.rx)
	var dy: float = (p.y - float(w.y)) / float(w.ry)
	return sqrt(dx * dx + dy * dy)


## True when p lies inside any water ellipse, grown by `grow` (1.0 = exactly the bounding edge).
static func in_water(p: Vector2, bodies: Array[Dictionary], grow: float) -> bool:
	for w: Dictionary in bodies:
		if water_k(p, w) < grow:
			return true
	return false
