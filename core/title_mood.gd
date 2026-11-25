class_name TitleMood
extends RefCounted
## Time of day for the title and loading backdrop, as pure data. Keyframes are sampled by SkyModel phase (0 midnight,
## 0.25 sunrise, 0.5 noon, 0.75 sunset), so the title follows the same sun arc, golden light and night shade as the
## meadow. Each keyframe gives the sky and far land (8 colours, same role per index as the meadow palette), the meadow
## ground (4 colours), the scenery tint and the extra night shade. No nodes, no state: the same phase always gives the
## same look, so tests can sample any moment.

## One full day on the title takes this many real seconds. Long enough that each golden hour holds for a few seconds.
const DAY_SECONDS: float = 150.0
## Where the title starts: golden hour, the look Nathan asked for first.
const START_PHASE: float = 0.72
## Sun and moon arc, in texels on the 640x360 backdrop. The arc sits right of the menu column.
const ARC_CENTRE_X: float = 410.0
const ARC_HALF_WIDTH: float = 110.0
const ARC_HORIZON_Y: float = 196.0
const ARC_HEIGHT: float = 130.0

## Keyframes in phase order, first one at 0. Sky roles: 0 ink, 1 dark, 2 mid, 3 light, 4 bright, 5 sun or moon, 6 earth
## or mauve (flowers, trunks), 7 paper (snow, stars). Ground roles: deep, dark, mid, light. Golden hour and sunset
## sit on the README banner's palette: warm plum sky, orange horizon, gold sun.
const KEYS: Array[Dictionary] = [
	{"name": "Night", "phase": 0.0, "sky": ["0a0c18", "151b33", "233257", "34486a", "5a6f8c", "d8e0c8", "3a3046", "e9ecd9"],
		"ground": ["0a1424", "15263a", "1f3a46", "2d4f4f"], "tint": "5a6aa0", "shade": 0.5},
	{"name": "Dawn", "phase": 0.2, "sky": ["12101f", "2c2448", "4a3a66", "8a5a6e", "c08a7a", "f4c08a", "5a3c4a", "f2dccb"],
		"ground": ["15161f", "233240", "33504a", "4f6a4e"], "tint": "d8a0b0", "shade": 0.28},
	{"name": "Sunrise", "phase": 0.27, "sky": ["1a1116", "4a2146", "8a3a5a", "e0705a", "f5a86a", "ffe49a", "9a4a4a", "fbe6c4"],
		"ground": ["2a2226", "3c3a2a", "5a6a34", "8aa04a"], "tint": "f2b08a", "shade": 0.1},
	{"name": "Morning", "phase": 0.37, "sky": ["14202e", "285a7a", "4a8aa0", "9cc8b0", "d8e8a8", "fff0a8", "c2784e", "f6efd9"],
		"ground": ["1f3b35", "2f6b55", "5fa36a", "b7d978"], "tint": "fff4e0", "shade": 0.0},
	{"name": "Noon", "phase": 0.5, "sky": ["17283a", "2d6a8e", "56a0b8", "a8d8d0", "e4f0c0", "fff6b8", "c2784e", "fff8e6"],
		"ground": ["1f3b35", "2f6b55", "5fa36a", "b7d978"], "tint": "ffffff", "shade": 0.0},
	{"name": "Afternoon", "phase": 0.63, "sky": ["1a2636", "335f80", "5f8c9c", "c8c49a", "f0d890", "fff0b0", "c2784e", "f8f0dc"],
		"ground": ["1f3b35", "2f6b55", "5a9a5e", "a8c870"], "tint": "fff0d8", "shade": 0.0},
	{"name": "Golden Hour", "phase": 0.72, "sky": ["1c1220", "4a2350", "9a3a5a", "e87a4a", "ffb060", "ffe49a", "a05a4a", "ffe6c0"],
		"ground": ["2a2a22", "4a4a2a", "7a8a3a", "c9b050"], "tint": "ffd29a", "shade": 0.0},
	{"name": "Sunset", "phase": 0.75, "sky": ["1a1116", "4a1f2a", "8a3a2e", "d0602f", "e9a845", "ffd27a", "b77a7a", "f1d9b5"],
		"ground": ["2a2220", "3e3426", "6a6a30", "a2963e"], "tint": "ffb07a", "shade": 0.1},
	{"name": "Dusk", "phase": 0.82, "sky": ["120e1e", "2e1a40", "5a2a5a", "a04a58", "d87a5a", "f4b070", "6e4a5e", "e8c8b0"],
		"ground": ["1a1c22", "262c30", "34443e", "4a6248"], "tint": "c08aa0", "shade": 0.3},
]


## Colour for a hex string from KEYS.
static func _hex(s: String) -> Color:
	return Color.html("#" + s)


## Position in the day, 0..1, wrapped.
static func wrap_phase(p: float) -> float:
	return fposmod(p, 1.0)


## Index of the keyframe whose phase is the last one at or before p (p in 0..1).
static func key_before(p: float) -> int:
	var q: float = wrap_phase(p)
	var found: int = 0
	for i in KEYS.size():
		if float(KEYS[i]["phase"]) <= q:
			found = i
	return found


## Sample the backdrop at phase p. Colours blend between the two keyframes around p with a smoothstep, so
## transitions have no hard edges. Returns {sky: PackedColorArray(8), ground: PackedColorArray(4), tint: Color,
## shade: float, name: String}, where name is the nearer keyframe's name.
static func sample(p: float) -> Dictionary:
	var q: float = wrap_phase(p)
	var a: int = key_before(q)
	var b: int = (a + 1) % KEYS.size()
	var pa: float = float(KEYS[a]["phase"])
	var pb: float = float(KEYS[b]["phase"]) + (1.0 if b == 0 else 0.0)
	var span: float = maxf(pb - pa, 0.0001)
	var f: float = clampf((q - pa) / span, 0.0, 1.0)
	f = f * f * (3.0 - 2.0 * f)
	var ka: Dictionary = KEYS[a]
	var kb: Dictionary = KEYS[b]
	var sky := PackedColorArray()
	var sa: Array = ka["sky"]
	var sb: Array = kb["sky"]
	for i in 8:
		sky.append(_hex(str(sa[i])).lerp(_hex(str(sb[i])), f))
	var ground := PackedColorArray()
	var ga: Array = ka["ground"]
	var gb: Array = kb["ground"]
	for i in 4:
		ground.append(_hex(str(ga[i])).lerp(_hex(str(gb[i])), f))
	return {
		"sky": sky,
		"ground": ground,
		"tint": _hex(str(ka["tint"])).lerp(_hex(str(kb["tint"])), f),
		"shade": lerpf(float(ka["shade"]), float(kb["shade"]), f),
		"name": str(ka["name"]) if f < 0.5 else str(kb["name"]),
	}


## Name of the keyframe nearest to phase p, for the time chip.
static func name_at(p: float) -> String:
	return str(sample(p)["name"])


## Phase of the next keyframe strictly after p, so the time chip can skip forward to it.
static func next_phase(p: float) -> float:
	var q: float = wrap_phase(p)
	for i in KEYS.size():
		var kp: float = float(KEYS[i]["phase"])
		if kp > q + 0.001:
			return kp
	return float(KEYS[0]["phase"]) + 1.0


## Sun or moon position in backdrop texels. By day the sun rides the arc; at night the moon rides the same arc, so
## the body is always on screen and sets behind the far land.
static func body(sky: SkyModel, t: float) -> Vector2:
	return arc_point(sky.phase(t))


## The arc position of the sun or moon at phase p (0..1, wraps). The sun rides sunrise to sunset (0.25 to 0.75), the moon
## the rest of the day, so the body is the sun by day and the moon by night.
static func arc_point(p_in: float) -> Vector2:
	var p: float = fposmod(p_in, 1.0)
	var sun: bool = sun_half(p)
	return arc_at(p if (sun or p >= 0.75) else p + 1.0, sun)


## True when phase p is on the sun's half of the day (sunrise 0.25 to sunset 0.75, both ends included). Decided by phase
## range, never by the sign of sun_of: at 0.25 and 0.75 sun_of is a float hair either side of zero, so a sign test
## would put the same body on different halves from one frame to the next.
static func sun_half(p: float) -> bool:
	var q: float = fposmod(p, 1.0)
	return q >= 0.25 and q <= 0.75


## The arc position on one half of the day, for an unwrapped phase u: the sun's half (sun true, sunrise 0.25 to sunset
## 0.75) or the moon's (moonrise 0.75 to moonset 1.25). The height is the sun's height, or the moon's depth below the horizon.
static func arc_at(u: float, sun: bool) -> Vector2:
	var e: float = clampf(absf(SkyModel.sun_of(u)), 0.0, 1.0)
	var x: float = ARC_CENTRE_X + arc_azimuth(u, sun) * ARC_HALF_WIDTH
	return Vector2(x, ARC_HORIZON_Y - e * ARC_HEIGHT)


## Left-to-right position on one half of the arc: -1 at its start (sunrise, or moonrise), +1 at its far end. Each half
## runs half a day, so the sun's x and the moon's x each sweep the full width once.
static func arc_azimuth(u: float, sun: bool) -> float:
	var n: float = clampf((u - arc_start(sun)) / 0.5, 0.0, 1.0)
	return -cos(n * PI)


## First phase of the body's half of the arc: 0.25 (sunrise) for the sun, 0.75 (moonrise) for the moon.
static func arc_start(sun: bool) -> float:
	return 0.25 if sun else 0.75


## The unwrapped phase on the sun's or moon's half that puts the body at backdrop x: the inverse of arc_azimuth. The arc's
## azimuth is -cos(theta), so theta = acos(-azimuth). An x past either end clamps to that end.
static func phase_for_x(x: float, sun: bool) -> float:
	var a: float = clampf((x - ARC_CENTRE_X) / ARC_HALF_WIDTH, -1.0, 1.0)
	return arc_start(sun) + 0.5 * acos(-a) / PI


## Star visibility 0..1: none by day, full on a clear night.
static func stars(sky: SkyModel, t: float) -> float:
	var n: float = sky.night(t) / maxf(sky.night_strength, 0.01)
	return smoothstep(0.2, 0.7, n)


## Night amount 0..1 for the fireflies (same curve as the stars).
static func night_amount(sky: SkyModel, t: float) -> float:
	return stars(sky, t)


## Day amount 0..1 for the birds: they fly once the sun is clear of the horizon.
static func day_amount(sky: SkyModel, t: float) -> float:
	return smoothstep(0.1, 0.4, SkyModel.sun_of(sky.phase(t)))


## Session seconds at which the sky reads phase p. Used to start a screen at a chosen time of day.
static func seconds_for(sky: SkyModel, p: float) -> float:
	return fposmod(p - sky.start_phase, 1.0) * sky.day_seconds


## A fresh SkyModel that runs the title cycle. Every title and loading screen builds its clock from this, so they agree.
static func make_sky() -> SkyModel:
	var sky := SkyModel.new()
	sky.day_seconds = DAY_SECONDS
	sky.start_phase = START_PHASE
	return sky
