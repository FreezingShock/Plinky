class_name AchievementStyle
extends RefCounted
## Per-section look and sound for the achievement banner: the particle style, the chime and how loud it is. The colour
## and icon come from LedgerPanel (one source for the Ledger and the banner). Presentation only; no balance here.

## Every category in Achievements.CATEGORIES has a row. shape picks the particle style (see AchievementSparks),
## sound an Audio one-shot, pitch and db shape it. Quiet on purpose: these play often.
const STYLES: Dictionary = {
	&"presses": {"shape": &"spark", "sound": &"tier_up_2", "pitch": 1.0, "db": -9.0},       # gold sparks off the ends
	&"meadow": {"shape": &"petal", "sound": &"pulse_echo", "pitch": 1.15, "db": -10.0},     # petals drifting down
	&"streaks": {"shape": &"flame", "sound": &"tier_up_5", "pitch": 1.2, "db": -9.0},       # short rising flame
	&"relics": {"shape": &"gem", "sound": &"relic_rare", "pitch": 1.0, "db": -9.0},         # twinkling gems
	&"rebirth": {"shape": &"ring", "sound": &"rebirth", "pitch": 1.0, "db": -10.0},         # rings out from the centre
	&"growth": {"shape": &"bubble", "sound": &"pulse_echo", "pitch": 0.8, "db": -10.0},     # bubbles rising
	&"quarry": {"shape": &"ember", "sound": &"tier_up_1", "pitch": 0.7, "db": -9.0},        # embers floating up
	&"journey": {"shape": &"dust", "sound": &"gate_open", "pitch": 1.0, "db": -12.0},       # dust streaks across
}

## Particles per burst for each shape, before GraphicsQuality scales them.
const SHAPE_COUNT: Dictionary = {
	&"spark": 14, &"petal": 9, &"flame": 12, &"gem": 12, &"ring": 2, &"bubble": 6, &"ember": 14, &"dust": 8,
}

## An achievement that earns a title gets more particles, a louder shake and a second, quieter chime.
const TITLE_BOOST: float = 1.5
const TITLE_SOUND: StringName = &"relic_uncommon"
const TITLE_DB: float = -10.0


static func of(cat: StringName) -> Dictionary:
	return STYLES.get(cat, STYLES[&"presses"]) as Dictionary


static func shape_of(cat: StringName) -> StringName:
	return of(cat)["shape"] as StringName


static func count_of(shape: StringName, titled: bool) -> int:
	var n: int = int(SHAPE_COUNT.get(shape, 8))
	return roundi(float(n) * TITLE_BOOST) if titled else n
