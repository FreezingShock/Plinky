class_name SkyModel
extends RefCounted
## Time of day, rain and wind as pure functions of session time `t` in seconds. No nodes, no state, no
## randomness, so the same t always gives the same sky and tests can sample any moment.
## Phase: 0 midnight, 0.25 sunrise, 0.5 noon, 0.75 sunset. Values are set by the caller from content/config/sky.tres.

var day_seconds: float = 720.0
var start_phase: float = 0.32
var night_strength: float = 0.8
var dusk_strength: float = 0.4
var rain_period_a: float = 173.0
var rain_period_b: float = 271.0
var rain_phase_a: float = 4.0
var rain_phase_b: float = 0.5
var rain_threshold: float = 0.55
var rain_max: float = 0.6
var wind_calm: float = 0.2
var wind_rain_boost: float = 0.3
var gust_period_a: float = 23.0
var gust_period_b: float = 37.0


## Position in the day, 0..1.
func phase(t: float) -> float:
	return fposmod(start_phase + t / maxf(day_seconds, 1.0), 1.0)


## Sun height from phase: -1 at midnight, +1 at noon.
static func sun_of(p: float) -> float:
	return -cos(TAU * p)


## Shade density, 0 by day up to night_strength at midnight.
func night(t: float) -> float:
	return night_strength * smoothstep(0.15, -0.45, sun_of(phase(t)))


## Warm band around sunrise and sunset, 0..dusk_strength.
func dusk(t: float) -> float:
	var x: float = (sun_of(phase(t)) - 0.0) / 0.3
	return dusk_strength * exp(-x * x)


## Rain intensity, 0 (dry) to rain_max.
func rain(t: float) -> float:
	var n: float = 0.5 * (sin(TAU * t / rain_period_a + rain_phase_a) + sin(TAU * t / rain_period_b + rain_phase_b))
	return rain_max * smoothstep(rain_threshold, rain_threshold + 0.25, n)


## Wind strength 0..1: a steady breeze, gusts above it, and a little more while it rains.
func wind(t: float) -> float:
	var g: float = 0.5 + 0.5 * sin(TAU * t / gust_period_a + 0.4) * sin(TAU * t / gust_period_b + 1.9)
	var gust: float = smoothstep(0.55, 0.95, g)
	var rain_part: float = wind_rain_boost * (rain(t) / maxf(rain_max, 0.001))
	return clampf(wind_calm + (1.0 - wind_calm) * 0.8 * gust + rain_part, 0.0, 1.0)
