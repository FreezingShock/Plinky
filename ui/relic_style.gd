class_name RelicStyle
extends RefCounted
## Colours for relic UI. Defaults are Zone 1 Meadow Tally. The theme's palette code should call
## set_palette() on zone change so panels recolour. Rarity colours are NOT here: they are fixed.

static var ink: Color = Color("#14161c")      ## role 0
static var edge: Color = Color("#5fa36a")     ## role 3
static var dim: Color = Color("#5fa36a")      ## role 3, unavailable text
static var good: Color = Color("#b7d978")     ## role 4
static var accent: Color = Color("#f2e6a0")   ## role 5
static var text: Color = Color("#f6efd9")     ## role 7

## Secondary text that stays readable on the dark panels: `dim` lifted halfway to the main text colour.
static func soft() -> Color:
	return dim.lerp(text, 0.5)


## colors: the 8 palette entries, index 0 to 7 (art bible section 3).
static func set_palette(colors: PackedColorArray) -> void:
	if colors.size() < 8:
		return
	ink = colors[0]; edge = colors[3]; dim = colors[3]
	good = colors[4]; accent = colors[5]; text = colors[7]
	palette = colors.duplicate()


## The 8 palette entries the colours above came from. Meadow until set_palette runs.
static var palette: PackedColorArray = PackedColorArray([Color("14161c"), Color("1f3b35"), Color("2f6b55"), Color("5fa36a"), Color("b7d978"), Color("f2e6a0"), Color("c2784e"), Color("f6efd9")])
## Palette roles for tiers 1 to 5 of a tab's rail. Tiers beyond that take their currency's colour.
const TIER_RAMP: Array[int] = [3, 6, 4, 5, 7]


## The colour of tier `i` (0-based) on a zone currency's rail: a palette role, so every zone reads from its own palette.
static func tier_color(i: int, cur: StringName) -> Color:
	if i < 0 or i >= TIER_RAMP.size() or palette.size() < 8:
		return StatStyle.color(cur)
	return palette[TIER_RAMP[i]]


## Ink frame colour that brightens toward the text colour while `amount` (0..1) is up. Used for flashes.
static func flash_ink(amount: float) -> Color:
	if amount <= 0.0 or FxConfig.reduce_flashing:
		return ink
	return ink.lerp(text, clampf(amount, 0.0, 1.0))
