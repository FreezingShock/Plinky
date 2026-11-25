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
## Share of the day the sun is up (sunrise to sunset). 0.5 is the plain cosine; 0.6 gives 3 min of day and 2 of night
## on a 5 minute day. The clock runs linearly (midnight 0, noon 0.5); only the sun's phase is stretched to fit.
var daylight_fraction: float = 0.5
## Golden light: how high the sun can be (elevation 0..1) before the golden look is down to its floor, and the
## share of it that is kept at noon. Larger reach = longer golden hours (see golden()).
var golden_reach: float = 0.95
var golden_floor: float = 0.35


## Position in the day, 0..1.
func phase(t: float) -> float:
	if absf(daylight_fraction - 0.5) < 0.0001:
		return fposmod(start_phase + t / maxf(day_seconds, 1.0), 1.0)
	return phase_of_clock(fposmod(clock_of_phase(start_phase) + t / maxf(day_seconds, 1.0), 1.0))


## Sun phase for a linear clock fraction (0 midnight, 0.5 noon). Sunrise sits at (1 - daylight) / 2 on the clock.
func phase_of_clock(c: float) -> float:
	var d: float = clampf(daylight_fraction, 0.2, 0.8)
	var rise: float = (1.0 - d) * 0.5
	var set_c: float = rise + d
	if c >= rise and c < set_c:
		return 0.25 + (c - rise) / d * 0.5
	var n: float = (c - set_c) if c >= set_c else (c + 1.0 - set_c)    # clock time since sunset
	return fposmod(0.75 + n / (1.0 - d) * 0.5, 1.0)


## Inverse of phase_of_clock.
func clock_of_phase(p: float) -> float:
	var d: float = clampf(daylight_fraction, 0.2, 0.8)
	var rise: float = (1.0 - d) * 0.5
	var set_c: float = rise + d
	var pp: float = fposmod(p, 1.0)
	if pp >= 0.25 and pp < 0.75:
		return rise + (pp - 0.25) / 0.5 * d
	var n: float = (pp - 0.75) if pp >= 0.75 else (pp + 0.25)    # phase since sunset
	return fposmod(set_c + n / 0.5 * (1.0 - d), 1.0)


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


## One line on the sky for the clock tooltip: rain or snow falling, or clear with the ground still wet. Pure, so tests
## can read it. `rain01` is the rain now (0..1), `snow_k` the winter weight (0..1), `wet01` the ground's wetness.
static func weather_words(rain01: float, snow_k: float, wet01: float) -> String:
	if rain01 > 0.05:
		return "Snow is falling." if snow_k > 0.5 else "Rain is falling. Puddles are filling."
	if wet01 > 0.15:
		return "Clear now. The puddles are drying."
	return "Clear skies."


## How wet the ground is, 0..1: the mean rain over the last WET_WINDOW seconds, so puddles fill during a shower and
## drain slowly after it (a minute of rain takes about the same time to dry). Pure, sampled the same way as rain().
## Rain bloom: at full rain each lamp pool grows by BLOOM_RADIUS and gains BLOOM_STRENGTH, so lamps and pad rings glow
## wider and warmer in a shower. Returns (radius multiplier, strength multiplier) for rain01 0..1.
const BLOOM_RADIUS: float = 0.35
const BLOOM_STRENGTH: float = 0.4
const WET_WINDOW: float = 45.0
const WET_SAMPLES: int = 9
const WET_GAIN: float = 1.8

func wetness(t: float) -> float:
	var s: float = 0.0
	for i in WET_SAMPLES:
		s += rain(t - WET_WINDOW * float(i) / float(WET_SAMPLES - 1))
	return clampf(s / float(WET_SAMPLES) / maxf(rain_max, 0.001) * WET_GAIN, 0.0, 1.0)


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


## Golden-hour light 0..1: the warm, long-shadowed, high-contrast look. Unlike low_sun() it does not switch off when
## the sun climbs: it falls smoothly from 1 at the horizon to `golden_floor` at noon, so the morning and afternoon
## keep the look that sunrise and sunset have. Zero at night.
func golden(t: float) -> float:
	var e: float = elevation(t)
	var up: float = smoothstep(-0.02, 0.06, sun_of(phase(t)))
	return up * lerpf(golden_floor, 1.0, smoothstep(golden_reach, 0.3, e))


## Shadow length in units of object height: short at noon, long when the sun is low, a faint moon shadow at night.
func shadow_length(t: float, noon: float, low: float, moon: float) -> float:
	var e: float = elevation(t)
	var day: float = lerpf(low, noon, smoothstep(0.0, 1.0, e * e))   # e squared: shadows stay long through the morning and afternoon
	var moon_up: float = clampf(-sun_of(phase(t)), 0.0, 1.0)
	return lerpf(day, moon, smoothstep(0.0, 0.2, moon_up))


## Shadow darkness 0..1 (`rain01` is rain intensity 0..1): fades out near the horizon crossing and under rain, a little survives by night.
func shadow_strength(t: float, moon: float, rain01: float = 0.0) -> float:
	var s: float = sun_of(phase(t))
	var sun_part: float = smoothstep(0.0, 0.18, s) * (1.0 - 0.8 * clampf(rain01, 0.0, 1.0))
	var moon_part: float = moon * smoothstep(0.1, 0.5, -s)
	return maxf(sun_part, moon_part)


## God ray strength 0..1: while the sun is below about three quarters of its height, and not in rain. Zero at noon,
## so the full-area ray pass is skipped for the middle of the day.
func rays(t: float, rain01: float = 0.0) -> float:
	var e: float = elevation(t)
	var shafts: float = smoothstep(0.82, 0.3, e) * smoothstep(-0.02, 0.06, sun_of(phase(t)))
	return maxf(low_sun(t), shafts * 0.85) * (1.0 - clampf(rain01, 0.0, 1.0))


## Ground mist 0..1: thickest at dawn, thinner through the day, back up after dusk, and extra after rain.
func mist(t: float, rain01: float = 0.0) -> float:
	var s: float = sun_of(phase(t))
	var dawn_part: float = exp(-pow((phase(t) - 0.27) / 0.07, 2.0))
	var dusk_part: float = 0.55 * exp(-pow((phase(t) - 0.74) / 0.07, 2.0))
	var night_part: float = 0.35 * smoothstep(0.0, -0.8, s)
	var wet: float = 0.5 * clampf(rain01, 0.0, 1.0)
	var gold_part: float = 0.14 * golden(t)   # a thin haze holds through the golden hours
	return clampf(0.18 + dawn_part * 0.7 + dusk_part + night_part + wet + gold_part, 0.0, 1.0)


## Time of day as 0..1 along a looping colour ramp: 0 = midnight, 0.25 = sunrise, 0.5 = noon, 0.75 = sunset.
## The ramps in sky.tres are Gradient resources sampled at this value.
func ramp(t: float) -> float:
	return phase(t)


## Lamp pool bloom for a rain level: Vector2(radius multiplier, strength multiplier), both 1.0 when dry.
static func lamp_bloom(rain01: float) -> Vector2:
	var k: float = clampf(rain01, 0.0, 1.0)
	return Vector2(1.0 + BLOOM_RADIUS * k, 1.0 + BLOOM_STRENGTH * k)


## Mist halo: at full mist each lamp pool spreads by FOG_HALO more, so the light reads through the fog. 1.0 when clear.
const FOG_HALO: float = 0.6

static func fog_halo(mist01: float) -> float:
	return 1.0 + FOG_HALO * clampf(mist01, 0.0, 1.0)


## Lightning flash, 0..1, at game time t. Only in heavy rain (rain01 from 0.7 up, full at 1). Each 40 s window has a
## strike half the time, at a hashed moment in the window, and each strike flickers twice over about half a second.
## Pure: the same time always gives the same flash, so it can be tested.
static func lightning_flash(t: float, rain01: float) -> float:
	var heavy: float = clampf((rain01 - 0.7) / 0.3, 0.0, 1.0)
	if heavy <= 0.0:
		return 0.0
	var st: float = strike_time(int(floorf(t / 40.0)))
	if st < 0.0:
		return 0.0
	var d: float = t - st
	if d < 0.0 or d > 0.6:
		return 0.0
	var main: float = exp(-d * 14.0)
	var again: float = 0.55 * exp(-maxf(d - 0.18, 0.0) * 14.0) if d >= 0.18 else 0.0
	return clampf(maxf(main, again), 0.0, 1.0) * heavy


## When the strike in a 40 s window lands (game time), or -1 when that window has none. Half the windows have one, at a
## hashed moment in the window. Shared by the flash and the thunder, so the rumble follows the same strike.
static func strike_time(window: int) -> float:
	var w: float = float(window)
	var h: float = fposmod(sin(w * 12.9898 + 78.233) * 43758.5453, 1.0)
	if h < 0.5:
		return -1.0
	return w * 40.0 + fposmod(h * 7.31, 1.0) * 36.0


## Seconds the thunder trails the flash for a strike in `window` (sound is slower than light): 1.5 to 4.5 s, hashed.
static func thunder_delay(window: int) -> float:
	var h: float = fposmod(sin(float(window) * 39.3468 + 12.7) * 24634.6345, 1.0)
	return 1.5 + 3.0 * h
