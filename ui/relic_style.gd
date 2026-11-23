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

## colors: the 8 palette entries, index 0 to 7 (art bible section 3).
static func set_palette(colors: PackedColorArray) -> void:
	if colors.size() < 8:
		return
	ink = colors[0]; edge = colors[3]; dim = colors[3]
	good = colors[4]; accent = colors[5]; text = colors[7]


## Ink frame colour that brightens toward the text colour while `amount` (0..1) is up. Used for flashes.
static func flash_ink(amount: float) -> Color:
	if amount <= 0.0 or FxConfig.reduce_flashing:
		return ink
	return ink.lerp(text, clampf(amount, 0.0, 1.0))
