class_name IconSet
extends RefCounted
## Staged icons: every stat, currency, attribute and perk icon is hand-drawn at 8, 12, 16, 24 and 32 px
## (tools/art/staged). Ask for the size you will draw at and get the drawing made for it, never a scaled copy.

const SIZES: Array[int] = [8, 12, 16, 24, 32]


## Path of icon `name` at exactly `px` (one of SIZES).
static func path(name: String, px: int) -> String:
	if name.begins_with("r_"):   # relic icons: 16 px beside s8 s12 s24 s32 folders under icons/relics
		return "res://assets/icons/relics/%s.png" % name if px == 16 else "res://assets/icons/relics/s%d/%s.png" % [px, name]
	match px:
		16:
			return "res://assets/icons/%s.png" % name
		32:
			return "res://assets/icons/big/%s.png" % name
	return "res://assets/icons/s%d/%s.png" % [px, name]


## The largest staged size that fits in `px`, or the smallest when none fits.
static func best_size(px: int) -> int:
	var pick: int = SIZES[0]
	for s: int in SIZES:
		if s <= px:
			pick = s
	return pick


## Icon `name` drawn for a `px` square slot. Null when the icon does not exist at that size.
static func get_icon(name: String, px: int) -> Texture2D:
	var p: String = path(name, best_size(px))
	return load(p) as Texture2D if ResourceLoader.exists(p) else null
