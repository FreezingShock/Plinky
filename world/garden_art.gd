class_name GardenArt
extends RefCounted
## Pixel sprites for the flower gardens that grow around each statistic's pad row (world/garden_layer.gd draws them).
## Four hand-drawn flower variants per statistic, then two leafy shrubs (variants 4 and 5) that frame a garden. Each is baked once into three sway frames
## (leaning left, upright, leaning right), so a garden of hundreds of flowers is one draw call per flower and no node per flower.
## Letters: # petal, d shaded petal, l light petal, c heart, g leaf, G shaded leaf, s stem. '.' is empty.
## Rows run top to bottom; the sprite stands on its last row, centred on its middle column.

## Variants 0 to 3 are small flowers, 4 and 5 are shrubs: leafy mounds dotted with the statistic's petals, so a garden has bushes around it
## without a single prop node. Variants 6 and up are the FIELD flowers: the statistic's own pad flower (TexelPad.FLOWERS, 13 by 10
## texels) at 1x, 2x or 3x with a one texel ink outline, in four tints (the last one mirrored), so a field of them reads as the
## pad's flower grown large. Variant = FIELD_FIRST + scale index * FIELD_TINTS + tint.
const FLOWER_VARIANTS: int = 4
const FIELD_FIRST: int = 6
const FIELD_SCALES: Array[int] = [1, 2, 3]
const FIELD_TINTS: int = 4
const INK: Color = Color("14161c")
## Which TexelPad.FLOWERS table each statistic's pad stands on.
const PAD_FLOWER: Dictionary = {
	&"dewdrop": &"sprout", &"clover": &"clover", &"thistle": &"thistle",
	&"heather": &"heather", &"foxglove": &"foxglove", &"starbloom": &"starbloom",
}

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
static var _atlas: Texture2D = null             # every frame of every stat, one texture (see atlas())
static var _atlas_rects: Array[Rect2] = []      # where each frame sits in _atlas, indexed by frame_index()
const ATLAS_WIDTH: int = 512
const ATLAS_GUTTER: int = 1


## How many hand-drawn variants (flowers and shrubs) a statistic has.
static func table_count(stat: StringName) -> int:
	return (VARIANTS[stat] as Array).size()


## Every variant id a flower may carry: the hand-drawn ones, then the field flowers.
static func variant_count(_stat: StringName) -> int:
	return FIELD_FIRST + FIELD_SCALES.size() * FIELD_TINTS


static func is_field(variant: int) -> bool:
	return variant >= FIELD_FIRST


static func field_scale(variant: int) -> int:
	return FIELD_SCALES[(variant - FIELD_FIRST) / FIELD_TINTS]


static func field_tint(variant: int) -> int:
	return (variant - FIELD_FIRST) % FIELD_TINTS


## Texels the sprite hangs below its foot row: a field flower's outline adds one row under the stem.
static func foot_drop(variant: int) -> int:
	return 1 if is_field(variant) else 0


static func sprite_size(stat: StringName, variant: int) -> Vector2i:
	return Vector2i(frame(stat, variant, 0).get_size())


## The baked sprite for `stat`/`variant` leaning -1, 0 or +1. The top rows shift a texel with the lean, the stem foot stays put.
static func frame(stat: StringName, variant: int, lean: int) -> Texture2D:
	var key: String = "%s:%d:%d" % [stat, variant, lean]
	if _frames.has(key):
		return _frames[key] as Texture2D
	var tex: ImageTexture = ImageTexture.create_from_image(_image(stat, variant, lean))
	_frames[key] = tex
	return tex


## Position of one frame in the atlas: stat index (STATS), then variant, then lean (-1, 0, +1).
static func frame_index(stat_index: int, variant: int, lean: int) -> int:
	return (stat_index * variant_count(&"") + variant) * 3 + lean + 1


## Every frame of every statistic in one texture, built the first time it is asked for. GardenLayer draws from it: the
## canvas batches consecutive draws of one texture, so a garden is a few draw calls, not one per flower, and nothing is
## baked while the world is on screen (before, each new variant was baked on the first frame it was seen).
static func atlas() -> Texture2D:
	if _atlas == null:
		_build_atlas()
	return _atlas


## Where frame `index` (see frame_index) sits inside atlas(), in texels.
static func atlas_rect(index: int) -> Rect2:
	if _atlas == null:
		_build_atlas()
	return _atlas_rects[index]


static func _build_atlas() -> void:
	PerfStats.lap_begin()
	var images: Array[Image] = []
	for stat: StringName in STATS:
		for v in variant_count(stat):
			for lean: int in [-1, 0, 1]:
				images.append(_image(stat, v, lean))
	var rects: Array[Rect2] = []
	var x: int = ATLAS_GUTTER
	var y: int = ATLAS_GUTTER
	var shelf: int = 0
	for img: Image in images:
		var w: int = img.get_width()
		var h: int = img.get_height()
		if x + w + ATLAS_GUTTER > ATLAS_WIDTH:
			x = ATLAS_GUTTER
			y += shelf + ATLAS_GUTTER
			shelf = 0
		rects.append(Rect2(x, y, w, h))
		x += w + ATLAS_GUTTER
		shelf = maxi(shelf, h)
	var sheet := Image.create(ATLAS_WIDTH, y + shelf + ATLAS_GUTTER, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.0, 0.0, 0.0, 0.0))
	for i in images.size():
		sheet.blit_rect(images[i], Rect2i(Vector2i.ZERO, images[i].get_size()), Vector2i(rects[i].position))
	_atlas = ImageTexture.create_from_image(sheet)
	_atlas_rects = rects
	PerfStats.lap("garden atlas")


## One frame as pixels: a hand-drawn variant or a field flower.
static func _image(stat: StringName, variant: int, lean: int) -> Image:
	if is_field(variant):
		return _field_image(stat, variant, lean)
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
	return img


## A field flower: the pad's flower table at its scale, a one texel ink outline, a leaning top half. Padded one texel each side so
## a lean never clips.
static func _field_image(stat: StringName, variant: int, lean: int) -> Image:
	var rows: Array = TexelPad.FLOWERS[PAD_FLOWER[stat]] as Array
	var k: int = field_scale(variant)
	var tint: int = field_tint(variant)
	var n: int = rows.size()
	var cols: int = (rows[0] as String).length()
	var body_w: int = cols * k
	var body_h: int = n * k
	var w: int = body_w + 4        # outline and lean room each side
	var h: int = body_h + 2        # outline above and below
	var base: Color = TexelPad.STAT_COLORS[stat] as Color
	var petal: Color = base
	match tint:
		1: petal = base.lightened(0.22)
		2: petal = base.darkened(0.24)
		3: petal = base.lerp(Color("ffe9a8"), 0.18)
	var shade: Color = petal.darkened(0.35)
	var leaf: Color = Color(LEAF).lightened(0.1) if tint == 1 else (Color(LEAF).darkened(0.12) if tint == 2 else Color(LEAF))
	var cells: Dictionary = {}   # Vector2i -> Color, before the lean
	for ry in n:
		var line: String = rows[ry]
		for rx in cols:
			var ch: String = line[(cols - 1 - rx) if tint == 3 else rx]   # tint 3 is the mirror image
			if ch == ".":
				continue
			var col: Color = petal
			match ch:
				"d": col = shade
				"c", "W": col = Color.WHITE
				"g": col = leaf
			for oy in k:
				for ox in k:
					cells[Vector2i(rx * k + ox, ry * k + oy)] = col
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var shifted: Dictionary = {}
	for c: Vector2i in cells:
		var from_bottom: int = body_h - 1 - c.y
		var shift: int = lean if (lean != 0 and from_bottom * 2 >= body_h) else 0   # the upper half leans, the stem foot stays planted
		shifted[Vector2i(c.x + 2 + shift, c.y + 1)] = cells[c]
	for c: Vector2i in shifted:
		for o: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var q: Vector2i = c + o
			if not shifted.has(q) and q.x >= 0 and q.y >= 0 and q.x < w and q.y < h:
				img.set_pixelv(q, INK)
	for c: Vector2i in shifted:
		img.set_pixelv(c, shifted[c] as Color)
	return img

