class_name GardenArt
extends RefCounted
## Pixel sprites for the flower gardens that grow around each statistic's pad row (world/garden_layer.gd draws them).
## Four hand-drawn flower variants per statistic, then two leafy shrubs (variants 4 and 5) that frame a garden. Each is baked once into three sway frames
## (leaning left, upright, leaning right), so a garden of hundreds of flowers is one draw call per flower and no node per flower.
## Letters: # petal, d shaded petal, l light petal, c heart, g leaf, G shaded leaf, s stem. '.' is empty.
## Rows run top to bottom; the sprite stands on its last row, centred on its middle column.

## Variants 0 to 3 are flowers, 4 and 5 are shrubs: leafy mounds dotted with the statistic's petals, so a garden has bushes around it
## without a single prop node.
const FLOWER_VARIANTS: int = 4

const STATS: Array[StringName] = [&"dewdrop", &"clover", &"thistle", &"heather", &"foxglove", &"starbloom"]

## Petal colour, shade, light, heart per statistic (the stat colours of TexelPad.STAT_COLORS, shaded by hand).
const COLORS: Dictionary = {
	&"dewdrop": ["e4f1ff", "93bfe6", "ffffff", "6fa8dc"],
	&"clover": ["6be86b", "36a846", "c4f7b0", "f6efd9"],
	&"thistle": ["7f9bff", "4a62c8", "c9d6ff", "ff9bd8"],
	&"heather": ["c27cff", "8447c4", "ecc6ff", "fff0ff"],
	&"foxglove": ["ffb62e", "d27a14", "ffe28a", "7a3416"],
	&"starbloom": ["ff7bff", "c248c2", "ffc9ff", "ffffff"],
}
const LEAF: String = "3d9a45"
const LEAF_DARK: String = "28683a"

const VARIANTS: Dictionary = {
	# Dewdrop: white bells that nod on a thread of stem, a daisy, a seed head of dew, a bud pair.
	&"dewdrop": [
		["..l..", ".#l#.", ".###.", "..d..", "..s..", "..s..", ".gsg.", "..s.."],
		["#.l.#", ".###.", "#.c.#", ".###.", "..s..", "g.s.g", ".gsg.", "..s.."],
		[".l.", "###", "#d#", ".s.", ".s.", "gsg", ".s."],
		["l...", "##.#", "#d.d", ".s.s", ".gsg", "..s."],
		["...ggg...", ".gggGggg.", "ggGgg#ggg", "gggg#gGgg", "gGggggg#g", ".GGGGGGG."],
		["..gggg...", ".ggGgggg.", "gg#gggGgg", "gGgg#gggg", "gggGgg#gg", ".GGGGGGG."],
	],
	# Clover: three-leaf patches with a round white-green blossom on a stem.
	&"clover": [
		[".#.#.", "#####", ".#c#.", "..s..", ".ggg.", "g.s.g"],
		[".l#l.", "#####", ".###.", "..s..", "..s.."],
		["gg.gg", "gGggG", ".gGg.", "..s..", "gg.gg", ".gGg."],
		["..c..", ".l#l.", "#####", ".###.", "..s..", ".gsg."],
		["...ggg...", ".gggGggg.", "gGggggGgg", "ggg#ggggg", "gGgggg#gg", ".GGGGGGG."],
		["..gggg...", ".gGgggg#.", "gggGggggg", "g#gggGggg", "gggg#gggg", ".GGGGGGG."],
	],
	# Thistle: a spiky violet crown on a stem with jagged leaves.
	&"thistle": [
		["#.#.#", ".#l#.", "#####", ".ddd.", "..s..", ".gsg.", "g.s.g", "..s.."],
		["..#..", ".#l#.", ".###.", ".ddd.", "..s..", "g.s..", ".gsg.", "..s.."],
		["#.#.#", ".###.", "..d..", "..s..", ".gsg.", "g.s.g"],
		[".#.#.", "#l#l#", ".###.", "..s..", "g.sg.", "..s.."],
		["..g.ggg..", ".gggGgg#.", "ggGggg#gg", "gggg#gGgg", "gGggggg#g", ".GGGGGGG."],
		["...ggg...", ".ggggGgg.", "g#gGgggg#", "gggg#gGgg", "gGggggggg", ".GGGGGGG."],
	],
	# Heather: short purple sprigs of bells up a woody stem, in tufts.
	&"heather": [
		["..#..", ".d#..", "..#d.", ".#d..", "..s..", ".gsg."],
		[".#.#.", "#l#.#", ".d#d.", ".s.s.", ".sgs.", "..s.."],
		["..#.", ".d#.", ".#d#", "..#d", ".s..", ".sg."],
		["#..#", "dl.d", ".#d.", "..s.", ".gs.", "..s."],
		["...ggg...", ".gg#gggg.", "g#ggGg#gg", "gg#gg#ggg", "gGg#ggg#g", ".GGGGGGG."],
		["..gggg...", ".ggg#ggg.", "gg#gggGg#", "g#gg#gggg", "gggg#gg#g", ".GGGGGGG."],
	],
	# Foxglove: tall spires of bells, lighter at the top, heart-spotted.
	&"foxglove": [
		["..#..", "..#..", ".#l#.", ".#c#.", "#d#d#", ".#c#.", "#d#d#", "..s..", ".gsg.", "g.s.g"],
		["..#..", ".#l#.", ".#d#.", "#d#d#", ".#c#.", "..s..", ".gsg.", "..s.."],
		[".l.", "###", "dcd", "###", ".s.", "gsg", ".s."],
		["..l..", ".#d#.", ".#c#.", "#d#d#", "..s..", "g.s.g", ".gsg.", "..s.."],
		["...ggg...", ".gggGgg#.", "gGggg#ggg", "ggg#gGg#g", "gGggggggg", ".GGGGGGG."],
		["..g.ggg..", ".ggggg#g.", "gg#gGgggg", "gggg#gGg#", "gGggggggg", ".GGGGGGG."],
	],
	# Starbloom: five-petal stars on a stem, one with a bright centre, one a small pair.
	&"starbloom": [
		["..l..", "l#c#l", ".###.", ".d#d.", "..s..", ".gsg.", "..s.."],
		["#.l.#", ".#c#.", "#####", ".#d#.", "..s..", "g.s.g", "..s.."],
		[".l.", "#c#", ".#.", ".s.", "gsg"],
		["l..l", "#cc#", ".##.", ".ds.", ".gs.", "..s."],
		["...ggg...", ".gggG#gg.", "ggGggggg#", "g#ggg#gGg", "gGggggggg", ".GGGGGGG."],
		["..gggg...", ".g#ggggg.", "gggG#gggg", "gg#gggG#g", "gGgggggg#", ".GGGGGGG."],
	],
}

static var _frames: Dictionary = {}   # "stat:variant:lean" -> ImageTexture (lean 0 upright, -1 left, 1 right)


static func variant_count(stat: StringName) -> int:
	return (VARIANTS[stat] as Array).size()


static func sprite_size(stat: StringName, variant: int) -> Vector2i:
	var rows: Array = (VARIANTS[stat] as Array)[variant]
	return Vector2i((rows[0] as String).length(), rows.size())


## The baked sprite for `stat`/`variant` leaning -1, 0 or +1. The top rows shift a texel with the lean, the stem foot stays put.
static func frame(stat: StringName, variant: int, lean: int) -> Texture2D:
	var key: String = "%s:%d:%d" % [stat, variant, lean]
	if _frames.has(key):
		return _frames[key] as Texture2D
	var rows: Array = (VARIANTS[stat] as Array)[variant]
	var w: int = (rows[0] as String).length()
	var h: int = rows.size()
	var pad: int = 1
	var img := Image.create(w + pad * 2, h, false, Image.FORMAT_RGBA8)
	var col: Array = COLORS[stat] as Array
	for y in h:
		var line: String = rows[y]
		var from_bottom: int = h - 1 - y
		var shift: int = 0
		if lean != 0 and from_bottom * 2 >= h:   # the upper half leans, the lower half is planted
			shift = lean
		for x in w:
			var ch: String = line[x]
			if ch == ".":
				continue
			var c: Color = Color.WHITE
			match ch:
				"#": c = Color(String(col[0]))
				"d": c = Color(String(col[1]))
				"l": c = Color(String(col[2]))
				"c": c = Color(String(col[3]))
				"g": c = Color(LEAF)
				"G", "s": c = Color(LEAF_DARK)
			img.set_pixel(x + pad + shift, y, c)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_frames[key] = tex
	return tex
