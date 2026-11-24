class_name PopupStyle
extends RefCounted
## Look and motion tables for press popups, as pure functions: no nodes, no autoloads, so tests call them directly.
## One tier is one look: 0 Plain, 1 Gold, 2 Ice, 3 Rainbow, 4 Chroma, 5 Galaxy (names live in GameConfig.popup_tier_names).
## Tier ramps are fixed hex like rarity colours (the same in every zone); Plain follows the zone palette.
## Everything is stepped: whole-pixel offsets, integer font sizes, hard colour steps, no blending.

enum Motion { RISE, ARC, SPRING, WAVE, ZIG, SLAM, ORBIT }

const TIERS: int = 6
const SIZES: Array[int] = [12, 16, 20, 24, 32]
## Starting index into SIZES for each tier, so a higher tier simply reads bigger.
const TIER_SIZE: Array[int] = [1, 1, 2, 2, 3, 3]
const EASE_COUNT: int = 5

## Motions each tier may roll. A popup picks one at spawn, so no two presses move alike.
const MOTIONS: Array = [
	[Motion.RISE, Motion.ARC, Motion.SPRING],
	[Motion.RISE, Motion.ARC, Motion.SPRING, Motion.SLAM],
	[Motion.RISE, Motion.ZIG, Motion.WAVE, Motion.ARC],
	[Motion.WAVE, Motion.ARC, Motion.SPRING, Motion.ZIG],
	[Motion.ZIG, Motion.SLAM, Motion.WAVE, Motion.SPRING],
	[Motion.ORBIT, Motion.SPRING, Motion.WAVE, Motion.ORBIT],
]

const INK: Color = Color("14161c")
const GOLD: Array[Color] = [Color("3d2408"), Color("e0a526"), Color("ffd95a"), Color("fff6c8")]
const ICE: Array[Color] = [Color("0d2a4a"), Color("4ea9e0"), Color("a8e6ff"), Color("f4ffff")]
const RAINBOW: Array[Color] = [Color("ff5a5a"), Color("ff9a3c"), Color("ffe14a"), Color("6fe05a"), Color("3fd8d0"), Color("5a8cff"), Color("c46bff")]
const CHROMA: Array[Color] = [Color("ff2d6f"), Color("ffd400"), Color("00e5a0"), Color("00b8ff"), Color("8a4dff")]
const CHROMA_RED: Color = Color("ff2055")
const CHROMA_CYAN: Color = Color("00e5ff")
const GALAXY: Array[Color] = [Color("2a1f7a"), Color("5b3bc4"), Color("a14ee0"), Color("e46bd8"), Color("6be3ff")]
const STAR: Color = Color("ffffff")
const PULSE: Color = Color("7fe8ff")


static func ease_fn(id: int, x: float) -> float:
	var t: float = clampf(x, 0.0, 1.0)
	match id:
		0:
			return 1.0 - pow(1.0 - t, 3.0)                    # out cubic
		1:
			var c1: float = 1.70158                           # out back: overshoots, then settles
			return 1.0 + (c1 + 1.0) * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)
		2:
			return 1.0 if t >= 1.0 else 1.0 - pow(2.0, -10.0 * t)   # out expo
		3:
			return -(cos(PI * t) - 1.0) * 0.5                 # in-out sine
		4:
			if t <= 0.0 or t >= 1.0:                          # out elastic
				return t
			return pow(2.0, -9.0 * t) * sin((t * 10.0 - 0.75) * (TAU / 3.0)) + 1.0
	return t


## Cheap deterministic 0..1 noise from two ints. Twinkles and glitches use it, so they never need a random stream.
static func hash01(a: int, b: int) -> float:
	var h: int = (a * 73856093) ^ (b * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0


## Popups never fade by alpha, so no glyph is ever half-transparent. The last 30% of a popup's life blinks off and on
## in whole steps. Reduce Flashing (blink false) holds the popup solid to its end instead.
const FADE_START: float = 0.7
const BLINK_HZ: float = 8.0


## True if a popup is drawn this frame. progress is 0 to 1 of its float-away; age is seconds alive.
static func shows_now(progress: float, age: float, blink: bool) -> bool:
	if progress < FADE_START or not blink:
		return true
	return int(age * BLINK_HZ) % 2 == 0


static func pick_motion(tier: int, roll: float) -> int:
	var list: Array = MOTIONS[clampi(tier, 0, TIERS - 1)] as Array
	return int(list[clampi(int(roll * float(list.size())), 0, list.size() - 1)])


## Index into SIZES for a popup. crit and a long hold step it up; a relic pulse is one smaller (never below 0).
static func size_index(tier: int, crit: bool, pulse: bool, hold_digits: int) -> int:
	var i: int = TIER_SIZE[clampi(tier, 0, TIERS - 1)]
	if crit:
		i += 1
	if pulse:
		i -= 1
	i += clampi(hold_digits, 0, 2)
	return clampi(i, 0, SIZES.size() - 1)


## Rise height in pixels. Higher tiers float further, so they stay readable above the lower ones.
static func rise_for(tier: int, size_idx: int) -> float:
	return 14.0 + 3.0 * float(tier) + 2.0 * float(size_idx)


## Offset of the whole popup from its anchor at progress p (0 to 1 of the float-away). y is negative upward.
static func motion_offset(motion: int, p: float, rnd: int, dir: float, rise: float, ease_id: int) -> Vector2:
	var q: float = clampf(p, 0.0, 1.0)
	var up: float = ease_fn(ease_id, minf(q / 0.8, 1.0)) * rise
	var s: float = float(rnd % 628) * 0.01
	match motion:
		Motion.ARC:
			return Vector2(dir * rise * 0.6 * q, -(rise * 1.1 * 4.0 * q * (1.0 - q) + rise * 0.45 * q))
		Motion.SPRING:
			return Vector2(0.0, -(rise * 0.55 * ease_fn(1, minf(q / 0.3, 1.0)) + rise * 0.45 * q))
		Motion.ZIG:
			return Vector2(sin(q * TAU * 1.5 + s) * 5.0 * (1.0 - 0.3 * q), -up)
		Motion.SLAM:
			var drop: float = rise * 0.9 * pow(1.0 - minf(q / 0.14, 1.0), 2.0)
			return Vector2(0.0, -drop - rise * 0.8 * ease_fn(0, maxf(q - 0.14, 0.0) / 0.86))
		Motion.ORBIT:
			return Vector2(cos(q * TAU * 0.8 + s) * 7.0 * (1.0 - 0.5 * q), -up + sin(q * TAU * 0.8 + s) * 3.0)
	return Vector2(0.0, -up)


## Per-letter vertical wobble in pixels (WAVE popups and the floating Galaxy look). Whole pixels.
static func char_wave(motion: int, tier: int, i: int, t: float) -> float:
	if motion == Motion.WAVE:
		return roundf(sin(t * 14.0 - float(i) * 0.9) * 2.0)
	if tier == 5:
		return roundf(sin(t * 5.0 - float(i) * 0.6))
	return 0.0


## Chroma glitch: an occasional letter jumps 2 pixels sideways for one 1/20 s slot. Off when `calm`.
static func glitch_x(tier: int, rnd: int, i: int, t: float, calm: bool) -> float:
	if tier != 4 or calm:
		return 0.0
	var slot: int = int(t * 20.0)
	return 0.0 if hash01(rnd + i * 31, slot) > 0.07 else (2.0 if hash01(i, slot) > 0.5 else -2.0)


## Fill colour of letter i of n at animation time t.
static func char_color(tier: int, i: int, n: int, t: float, rnd: int, zone: String) -> Color:
	match tier:
		0:
			return PlinkyPalette.role(zone, "text") if t < 0.08 else PlinkyPalette.role(zone, "accent")
		1:
			var d: float = fposmod(float(i) * 0.7 - t * 6.0, float(n) + 4.0)
			return GOLD[3] if d < 0.9 else (GOLD[2] if d < 2.0 else GOLD[1])
		2:
			var g: float = fposmod(float(i) * 0.8 - t * 7.0, float(n) + 5.0)
			if g < 0.9:
				return ICE[3]
			return ICE[2] if (i + int(t * 6.0)) % 3 != 0 else ICE[1]
		3:
			return RAINBOW[(i + int(t * 12.0) + rnd) % RAINBOW.size()]
		4:
			if hash01(rnd, int(t * 18.0)) < 0.08:
				return STAR
			return CHROMA[(i * 2 + int(t * 16.0)) % CHROMA.size()]
		5:
			if hash01(rnd + i * 17, int(t * 9.0)) < 0.07:
				return STAR
			var v: float = sin(float(i) * 0.9 + t * 3.0 + float(rnd % 7)) + sin(float(i) * 0.4 - t * 2.1)
			return GALAXY[clampi(int((v + 2.0) / 4.0 * float(GALAXY.size())), 0, GALAXY.size() - 1)]
	return STAR


## Outline colour: ink for Plain, a deep shade of the tier for the rest, so each look keeps a dark edge.
static func outline_color(tier: int) -> Color:
	match tier:
		1:
			return GOLD[0]
		2:
			return ICE[0]
		5:
			return Color("0a0620")
	return INK


## Bright colour used for pad rings, burst pixels and the pulse diamond. t is time, for tiers that cycle.
static func accent_color(tier: int, t: float, zone: String) -> Color:
	match tier:
		1:
			return GOLD[2]
		2:
			return ICE[2]
		3:
			return RAINBOW[int(t * 14.0) % RAINBOW.size()]
		4:
			return CHROMA[int(t * 18.0) % CHROMA.size()]
		5:
			return GALAXY[2 + int(t * 8.0) % 3]
	return PlinkyPalette.role(zone, "accent")


## Colours for sparkle particles of a tier (hard colours, picked at random).
static func spark_colors(tier: int, zone: String) -> Array[Color]:
	var out: Array[Color] = []
	match tier:
		1:
			out.assign([GOLD[1], GOLD[2], GOLD[3]])
		2:
			out.assign([ICE[1], ICE[2], ICE[3]])
		3:
			out.assign(RAINBOW)
		4:
			out.assign(CHROMA)
		5:
			out.assign([GALAXY[2], GALAXY[3], GALAXY[4], STAR])
		_:
			out.assign([PlinkyPalette.role(zone, "accent"), PlinkyPalette.role(zone, "text")])
	return out
