class_name AccessOptions
extends RefCounted
## Accessibility options that other systems read: the colour-safe palette mode, large tooltip text and
## sound subtitles. Values are set by the Access tab (ui/settings/settings_registry.gd); this file holds no
## nodes. Colours that carry meaning (rarity tiers, buy green and red, stat colours) go through tint().

const MODE_OFF: String = "off"
const MODE_RED_GREEN: String = "rg"      ## protanopia and deuteranopia: no red against green, Okabe-Ito hues
const MODE_BLUE_YELLOW: String = "by"    ## tritanopia: no blue against green, no yellow against pink

static var color_mode: String = MODE_OFF
static var large_text: bool = false
static var subtitles: bool = false
## Bumped whenever an option changes, so panels that cache a colour know to redraw.
static var revision: int = 0

## Original colour (html, no alpha) -> replacement, per mode. Anything not listed passes through.
const SWAPS: Dictionary = {
	"rg": {
		"5fd068": "56b4e9", "d8483c": "e69f00", "d9604c": "e69f00",             # buy green and red -> blue and orange
		"55ff55": "2fd4a0", "5555ff": "3a86ff", "aa00aa": "cc79a7",             # uncommon, rare, epic
		"ff55ff": "f0e442", "55ffff": "bdf4ff", "ff5555": "d55e00",             # mythic, divine, special
		"7be08a": "40d0b0", "a3d96a": "c8d96a", "ff6b5a": "d55e00",             # luck, walk speed, crit chance
	},
	"by": {
		"55aaff": "3d7bff", "ffaa00": "ff8030", "ffae42": "ff8030",             # mult, legendary / slag, crit damage
		"ff55ff": "ff4d6d", "55ffff": "7dffb0", "f2c94c": "ffb000",             # mythic, divine, cash
		"f08fb0": "ff6fa0", "6fd6e8": "7fe8c8",                                 # prestige, press rate
	},
}


static func tint(c: Color) -> Color:
	if color_mode == MODE_OFF:
		return c
	var table: Dictionary = SWAPS.get(color_mode, {}) as Dictionary
	var key: String = c.to_html(false)
	if table.has(key):
		var out := Color(String(table[key]))
		out.a = c.a
		return out
	return c


static func set_color_mode(v: String) -> void:
	color_mode = v if v in [MODE_OFF, MODE_RED_GREEN, MODE_BLUE_YELLOW] else MODE_OFF
	revision += 1


static func set_large_text(on: bool) -> void:
	large_text = on
	revision += 1


## Tooltip type: Pixelify Sans at a bigger size when large, Spleen otherwise. Sizes are whole numbers.
static func title_size() -> int:
	return 20 if large_text else 16


static func body_size() -> int:
	return 16 if large_text else 12
