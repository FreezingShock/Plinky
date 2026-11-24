class_name AmbientMix
extends RefCounted
## Pure ambient soundscape mix: which loop layers are audible for a zone, a time of day and a season, 0..1 each.
## No nodes and no audio here; audio/ambient_scape.gd turns the numbers into volumes and crossfades them.

const AREA_MEADOW: StringName = &"meadow"
const AREA_LARKMOOR: StringName = &"larkmoor"
const AREA_QUARRY: StringName = &"quarry"

const L_WIND_DAY: StringName = &"wind_day"
const L_WIND_NIGHT: StringName = &"wind_night"
const L_WIND_WINTER: StringName = &"wind_winter"
const L_CRICKETS: StringName = &"crickets"
const L_LEAVES: StringName = &"leaves"
const L_CRACKLE: StringName = &"crackle"
const LAYERS: Array[StringName] = [L_WIND_DAY, L_WIND_NIGHT, L_WIND_WINTER, L_CRICKETS, L_LEAVES, L_CRACKLE]

const EDGE: float = 0.04          # sunrise and sunset fade over +-4% of a day (about 12 s of a 5 min day)
## Per season (spring, summer, autumn, winter): how loud the crickets are at night, and how much birdsong there is by day.
const CRICKET_BY_SEASON: Array[float] = [0.55, 1.0, 0.6, 0.0]
const BIRDS_BY_SEASON: Array[float] = [1.0, 0.85, 0.5, 0.12]


## Which area's soundscape a zone id uses.
static func area_of(zone_id: StringName) -> StringName:
	var z: String = String(zone_id)
	if z.begins_with("quarry") or z == "zone2":
		return AREA_QUARRY
	if z == "larkmoor":
		return AREA_LARKMOOR
	return AREA_MEADOW


## 1 in full daylight, 0 at night, smooth through sunrise and sunset. `day_fraction` is the clock (0 midnight, 0.5 noon).
static func daylight(day_fraction: float, daylight_fraction: float) -> float:
	var sunrise: float = (1.0 - daylight_fraction) * 0.5
	var sunset: float = sunrise + daylight_fraction
	var up: float = smoothstep(sunrise - EDGE, sunrise + EDGE, day_fraction)
	var down: float = 1.0 - smoothstep(sunset - EDGE, sunset + EDGE, day_fraction)
	return clampf(up * down, 0.0, 1.0)


## 0..1, peaks at sunrise: the dawn chorus.
static func dawn(day_fraction: float, daylight_fraction: float) -> float:
	var sunrise: float = (1.0 - daylight_fraction) * 0.5
	var x: float = (day_fraction - (sunrise + 0.03)) / 0.05
	return exp(-x * x)


static func _dot(weights: Array[float], values: Array[float]) -> float:
	var s: float = 0.0
	for i in mini(weights.size(), values.size()):
		s += weights[i] * values[i]
	return s


## Layer id -> gain 0..1. Seasons crossfade because `season_weights` does (4 floats summing to 1).
static func layers(area: StringName, day_fraction: float, daylight_fraction: float, season_weights: Array[float]) -> Dictionary:
	var day: float = daylight(day_fraction, daylight_fraction)
	var night: float = 1.0 - day
	var winter: float = season_weights[3] if season_weights.size() > 3 else 0.0
	var autumn: float = season_weights[2] if season_weights.size() > 2 else 0.0
	var out: Dictionary = {}
	for l in LAYERS:
		out[l] = 0.0
	if area == AREA_QUARRY:
		# Sheltered stone: a quiet hollow wind, the forge crackle always, louder when it is dark.
		out[L_WIND_DAY] = day * 0.25 * (1.0 - winter)
		out[L_WIND_NIGHT] = night * 0.4
		out[L_WIND_WINTER] = winter * 0.25
		out[L_CRACKLE] = 0.7 + 0.3 * night
		return out
	var open_air: float = 1.0 if area == AREA_LARKMOOR else 0.8      # Larkmoor is wider and windier than the starting meadow
	out[L_WIND_DAY] = day * open_air * (1.0 - 0.7 * winter)
	out[L_WIND_NIGHT] = night * open_air * 0.8
	out[L_WIND_WINTER] = winter * open_air * (0.55 + 0.25 * day)
	out[L_CRICKETS] = night * _dot(season_weights, CRICKET_BY_SEASON)
	out[L_LEAVES] = autumn * (0.45 + 0.55 * day) * open_air
	return out


## How much birdsong to play, 0..1.3: zero at night, richer in spring, thin in winter, a burst at dawn. Quarry has none.
static func bird_scale(area: StringName, day_fraction: float, daylight_fraction: float, season_weights: Array[float]) -> float:
	if area == AREA_QUARRY:
		return 0.0
	var day: float = daylight(day_fraction, daylight_fraction)
	return day * _dot(season_weights, BIRDS_BY_SEASON) * (1.0 + 0.3 * dawn(day_fraction, daylight_fraction))


## Rain bed gain, 0..1: follows the rain, silent under snow and in the quarry (no weather there). Pure, so the
## audio scape and its tests read the same rule.
static func rain_gain(rain01: float, snow_w: float, area: StringName) -> float:
	if area == AREA_QUARRY:
		return 0.0
	return clampf(rain01, 0.0, 1.0) * (1.0 - clampf(snow_w, 0.0, 1.0))
