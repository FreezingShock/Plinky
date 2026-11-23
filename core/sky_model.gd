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


## Where the light comes from on screen's x axis: -1 on the left, +1 on the right. The sun rises on the left (the
## way the baked art is lit), is overhead at 0 at noon and sets on the right. The moon rises on the left at
## sunset's far side and sets on the right, so it rides the same arc.
func azimuth(t: float) -> float:
	var p: float = phase(t)
	if p >= 0.25 and p <= 0.75:
		return -cos((p - 0.25) / 0.5 * PI)
	var n: float = (p - 0.75) / 0.5 if p > 0.75 else (p + 0.25) / 0.5
	return -cos(clampf(n, 0.0, 1.0) * PI)


## Sun height 0..1 above the horizon (0 at or below it). The moon uses the same arc, reversed by the caller.
func elevation(t: float) -> float:
	return clampf(sun_of(phase(t)), 0.0, 1.0)


## 1 when the sun is low (golden hour: long shadows, warm rim, god rays), 0 at noon and by night.
func low_sun(t: float) -> float:
	var e: float = elevation(t)
	return smoothstep(0.62, 0.05, e) * smoothstep(-0.02, 0.06, sun_of(phase(t)))


## Shadow length in units of object height: short at noon, long when the sun is low, a faint moon shadow at night.
func shadow_length(t: float, noon: float, low: float, moon: float) -> float:
	var e: float = elevation(t)
	var day: float = lerpf(low, noon, smoothstep(0.0, 1.0, e))
	var moon_up: float = clampf(-sun_of(phase(t)), 0.0, 1.0)
	return lerpf(day, moon, smoothstep(0.0, 0.2, moon_up))


## Shadow darkness 0..1 (`rain01` is rain intensity 0..1): fades out near the horizon crossing and under rain, a little survives by night.
func shadow_strength(t: float, moon: float, rain01: float = 0.0) -> float:
	var s: float = sun_of(phase(t))
	var sun_part: float = smoothstep(0.0, 0.18, s) * (1.0 - 0.8 * clampf(rain01, 0.0, 1.0))
	var moon_part: float = moon * smoothstep(0.1, 0.5, -s)
	return maxf(sun_part, moon_part)


## God ray strength 0..1: only while the sun is low, and not in rain.
func rays(t: float, rain01: float = 0.0) -> float:
	return low_sun(t) * (1.0 - clampf(rain01, 0.0, 1.0))


## Ground mist 0..1: thickest at dawn, thinner through the day, back up after dusk, and extra after rain.
func mist(t: float, rain01: float = 0.0) -> float:
	var s: float = sun_of(phase(t))
	var dawn_part: float = exp(-pow((phase(t) - 0.27) / 0.07, 2.0))
	var dusk_part: float = 0.55 * exp(-pow((phase(t) - 0.74) / 0.07, 2.0))
	var night_part: float = 0.35 * smoothstep(0.0, -0.8, s)
	var wet: float = 0.5 * clampf(rain01, 0.0, 1.0)
	return clampf(0.18 + dawn_part * 0.7 + dusk_part + night_part + wet, 0.0, 1.0)


## Time of day as 0..1 along a looping colour ramp: 0 = midnight, 0.25 = sunrise, 0.5 = noon, 0.75 = sunset.
## The ramps in sky.tres are Gradient resources sampled at this value.
func ramp(t: float) -> float:
	return phase(t)
