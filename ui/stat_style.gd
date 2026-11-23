class_name StatStyle
extends RefCounted
## One colour per stat, shared by every tooltip so Cash always reads gold and Multiplier always reads blue.
## Fixed hex like the buy colours and rarity colours: they read the same in every zone. No node or autoload use.

const BUY_GREEN: Color = Color("5fd068")   ## affordable, a gain
const BUY_RED: Color = Color("d8483c")     ## not affordable
const COLORS: Dictionary = {
	&"sunlight": Color("ffd95a"), &"dewdrop": Color("e4f1ff"), &"clover": Color("6be86b"), &"thistle": Color("7f9bff"),
	&"heather": Color("c27cff"), &"foxglove": Color("ffb62e"), &"starbloom": Color("ff7bff"),
	&"cash": Color("f2c94c"), &"mult": Color("55aaff"), &"reb": Color("c77dff"), &"slag": Color("5fb0e0"), &"ironore": Color("5fb26a"), &"ingot": Color("a07ee0"), &"alloy": Color("e8b43a"), &"emberheart": Color("ff5aa0"),
	&"prestige": Color("f08fb0"), &"rp": Color("9ee2c0"), &"crit_chance": Color("ff6b5a"), &"crit_damage": Color("ffae42"),
	&"luck": Color("7be08a"), &"press_rate": Color("6fd6e8"), &"walk_speed": Color("a3d96a"),
	&"offline_cap": Color("8aa6ff"), &"mastery": Color("ffd166"),
}
const PAPER: Color = Color("f6efd9")
## Attribute effect id -> the stat id whose colour it uses.
const EFFECT_STAT: Dictionary = {&"offline_hours": &"offline_cap", &"mastery_xp": &"mastery", &"pad_yield": &"sunlight"}


static func color(id: StringName) -> Color:
	return AccessOptions.tint(COLORS.get(EFFECT_STAT.get(id, id), PAPER) as Color)


## The affordable / gain colour and the can't-afford colour, swapped for colour-safe ones when that option is on.
static func gain() -> Color:
	return AccessOptions.tint(BUY_GREEN)


static func cant() -> Color:
	return AccessOptions.tint(BUY_RED)


## Green when the player can afford a cost, red when not.
static func buy(can: bool) -> Color:
	return gain() if can else cant()


## The all-caps tag face (rarity tags, MOMENTUM): Pixelify Sans emboldened, size TAG_SIZE.
const TAG_SIZE: int = 14
static var _tag_font: FontVariation = null


static func tag_font() -> FontVariation:
	if _tag_font == null:
		_tag_font = FontVariation.new()
		_tag_font.base_font = load("res://fonts/PixelifySans.ttf") as Font
		_tag_font.variation_embolden = 0.6
	return _tag_font
