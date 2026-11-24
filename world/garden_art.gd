class_name GardenArt
extends RefCounted
## Sprites for the flower gardens that grow around each statistic's pad row (world/garden_layer.gd draws them).
## Every flower is seen from the elevated, looking-down camera (the wheat mockup D angle): its head is a foreshortened
## rosette on a stem, with the top lit from the upper left and a soft ground shadow under the foot. Four small flowers per
## statistic, two leafy shrubs that frame a garden (variants 4 and 5), and twelve field flowers (variants 6 and up): the
## same rosette at 1x, 2x or 3x in four tints. Each is baked once per season, open or closed, into three sway frames
## (leaning left, upright, leaning right), so a garden of hundreds of flowers is one draw call per flower and no node per flower.
## Seasons: spring buds (closed heads, fresh leaves), summer full bloom, autumn faded and seeded, winter bare stalks with frost.
## Night and early morning can close the petals (`closed`). Shrubs keep their shape and only change colour and dots.

const FLOWER_VARIANTS: int = 4
const SHRUB_VARIANTS: int = 2
const FIELD_FIRST: int = 6
const FIELD_SCALES: Array[int] = [1, 2, 3]
const FIELD_TINTS: int = 4
## Milliseconds of atlas baking a frame while a pre-game screen (boot, title, loading) is up. See prepare_slice().
const BAKE_SLICE_MS: float = 3.0
## A bigger slice once the loader is done but the atlas still bakes, so the loading screen holds only briefly.
const BAKE_CATCHUP_MS: float = 10.0
const SEASON_SPRING: int = 0
const SEASON_SUMMER: int = 1
const SEASON_AUTUMN: int = 2
const SEASON_WINTER: int = 3
const INK: Color = Color("14161c")
const LEAF: String = "3d9a45"
const LEAF_DARK: String = "28683a"
const LEAF_LIGHT: String = "7ccf6a"
const SEED: String = "6b4a2a"
const FROST: String = "eaf6ff"
const DEW: String = "ffffff"      # the bright drops on an open head at dawn
const STATES: int = 3              # head states in the atlas: open, shut at night, dew at dawn
const SHADOW: Color = Color(0.04, 0.14, 0.10, 0.42)   # soft ground shadow: a translucent dark green, so grass shows through
const SHADOW_ALPHA: Array[float] = [0.42, 0.24, 0.1]   # the shadow's three rows, from the foot down
const RIME_ALPHA: Array[float] = [0.55, 0.3, 0.12]     # the same oval as a pale winter rime
const SHADOW_ROWS: int = 3
const FOLD_CLOSED: float = 0.56   # the petal radius when a head is shut at night
const FOLD_SPRING: float = 0.74   # spring heads are half open buds

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

## Petal count and edge sharpness per statistic: dewdrop a six-bell daisy, clover a trefoil, thistle a spiky crown,
## heather five bells, foxglove a ring of seven bells, starbloom a sharp five-point star.
const SHAPE: Dictionary = {
	&"dewdrop": [6, 1.0], &"clover": [3, 1.0], &"thistle": [9, 2.4],
	&"heather": [5, 1.0], &"foxglove": [7, 1.6], &"starbloom": [5, 3.0],
}

## Small flower layout per variant: radius across, petal phase, stem length, leaves on the stem.
const HEADS: Array = [[4, 0.0, 2, 1], [4, 0.5, 3, 0], [4, 0.2, 2, 2], [4, 0.9, 3, 1]]
## Shrub layout: radius across, radius down, hash seed (so the two shrubs differ).
const SHRUBS: Array = [[5, 3, 11], [6, 4, 29]]

static var _frames: Dictionary = {}   # "stat:variant:lean:season:closed" -> ImageTexture
static var _atlas: Texture2D = null             # every frame of every stat, season and night state, one texture (see atlas())
static var _atlas_rects: Array[Rect2] = []      # where each frame sits in _atlas, indexed by frame_index()
static var _atlas_count: int = 0                # how many distinct frames the atlas holds
const ATLAS_WIDTH: int = 512
const ATLAS_GUTTER: int = 1


## How many hand-drawn variants (flowers and shrubs) a statistic has.
static func table_count(_stat: StringName) -> int:
	return FLOWER_VARIANTS + SHRUB_VARIANTS


## Every variant id a flower may carry: the hand-drawn ones, then the field flowers.
static func variant_count(_stat: StringName) -> int:
	return FIELD_FIRST + FIELD_SCALES.size() * FIELD_TINTS


static func is_field(variant: int) -> bool:
	return variant >= FIELD_FIRST


static func is_shrub(variant: int) -> bool:
	return variant >= FLOWER_VARIANTS and variant < FIELD_FIRST


static func field_scale(variant: int) -> int:
	return FIELD_SCALES[(variant - FIELD_FIRST) / FIELD_TINTS]


static func field_tint(variant: int) -> int:
	return (variant - FIELD_FIRST) % FIELD_TINTS


## Texels the sprite hangs below its foot row: the ground shadow spills three rows under the foot (it is an oval, not a
## flat line), for flowers and shrubs alike.
static func foot_drop(_variant: int) -> int:
	return SHADOW_ROWS - 1


## Position of one frame in the atlas: stat index (STATS), variant, lean (-1, 0, +1), season, then the head state (0 open, 1 shut at
## night, 2 dew at dawn). A frame that looks the same whatever the lean or state (shrubs, and winter stalks) has one canonical index.
static func frame_index(stat_index: int, variant: int, lean: int, season: int = SEASON_SUMMER, closed: bool = false, dew: bool = false) -> int:
	var c: Dictionary = _canonical(variant, lean, season, closed, dew)
	return (((stat_index * variant_count(&"") + variant) * 3 + int(c.lean) + 1) * 4 + int(c.season)) * STATES + int(c.state)


## The arguments that change a frame's pixels: shrubs ignore lean and state, winter has no head to shut or dew.
static func _canonical(variant: int, lean: int, season: int, closed: bool, dew: bool) -> Dictionary:
	if is_shrub(variant):
		return {"lean": 0, "season": season, "state": 0}
	var state: int = 2 if dew else (1 if closed else 0)
	if season == SEASON_WINTER:
		state = 0
	return {"lean": lean, "season": season, "state": state}


## Every frame of every statistic, season and night state in one texture, built the first time it is asked for. GardenLayer draws
## from it, so a garden is a few canvas batches and no frame is baked while the world is on screen.
static func atlas() -> Texture2D:
	if _atlas == null:
		prepare_slice(INF)
	return _atlas


## Where frame `index` (see frame_index) sits inside atlas(), in texels.
static func atlas_rect(index: int) -> Rect2:
	if _atlas == null:
		prepare_slice(INF)
	return _atlas_rects[index]


static var _plan: Array = []              ## one entry per distinct frame of the atlas, planned by prepare()
static var _baked: Array[Image] = []      ## the frames baked so far, in plan order (prepare_slice fills it)


## Plans the atlas: which frames it holds and where each comes from. Cheap; the baking is prepare_slice's job. Safe to call
## again; a no-op once the plan exists or the atlas is built.
static func prepare() -> void:
	if _atlas != null or not _plan.is_empty():
		return
	var seen: Dictionary = {}
	for stat_index in STATS.size():
		var stat: StringName = STATS[stat_index]
		for v in variant_count(stat):
			for lean: int in [-1, 0, 1]:
				for season in 4:
					for state in STATES:
						var idx: int = frame_index(stat_index, v, lean, season, state == 1, state == 2)
						if seen.has(idx):
							continue
						seen[idx] = true
						var c: Dictionary = _canonical(v, lean, season, state == 1, state == 2)
						_plan.append({"idx": idx, "stat": stat, "variant": v, "lean": int(c.lean), "season": int(c.season), "closed": int(c.state) == 1, "dew": int(c.state) == 2})


## True once the atlas exists, so the game never bakes it on its first frame.
static func is_ready() -> bool:
	return _atlas != null


## Bakes the atlas for up to `budget_ms` on the main thread, then packs and uploads it. The boot and title screens call this
## a few milliseconds a frame (more once loading is done), so the game's first frame does not bake it. Returns true once the atlas
## exists. Image work only, so it stays on the main thread: a worker thread here made script loading fail (the preloads
## of walker_atlas.png and PixelifySans.ttf came back as parse errors in the boot smoke test).
static func prepare_slice(budget_ms: float) -> bool:
	if _atlas != null:
		return true
	prepare()
	var start: int = Time.get_ticks_usec()
	while _baked.size() < _plan.size():
		var e: Dictionary = _plan[_baked.size()] as Dictionary
		_baked.append(_bake(e.stat as StringName, int(e.variant), int(e.lean), int(e.season), bool(e.closed), bool(e.dew)))
		if float(Time.get_ticks_usec() - start) / 1000.0 >= budget_ms:
			return false
	_pack_atlas()
	return true


## Packs the baked frames into one sheet, tallest first, and uploads it.
static func _pack_atlas() -> void:
	var total: int = STATS.size() * variant_count(&"") * 3 * 4 * STATES
	var order: Array[int] = []
	for i in _baked.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return _baked[a].get_height() > _baked[b].get_height())
	var rects: Array[Rect2] = []
	rects.resize(total)
	var x: int = ATLAS_GUTTER
	var y: int = ATLAS_GUTTER
	var shelf: int = 0
	for i: int in order:
		var img: Image = _baked[i]
		var w: int = img.get_width()
		var h: int = img.get_height()
		if x + w + ATLAS_GUTTER > ATLAS_WIDTH:
			x = ATLAS_GUTTER
			y += shelf + ATLAS_GUTTER
			shelf = 0
		rects[int((_plan[i] as Dictionary).idx)] = Rect2(x, y, w, h)
		x += w + ATLAS_GUTTER
		shelf = maxi(shelf, h)
	var sheet := Image.create(ATLAS_WIDTH, y + shelf + ATLAS_GUTTER, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.0, 0.0, 0.0, 0.0))
	for i in _baked.size():
		sheet.blit_rect(_baked[i], Rect2i(Vector2i.ZERO, _baked[i].get_size()), Vector2i(rects[int((_plan[i] as Dictionary).idx)].position))
	_atlas = ImageTexture.create_from_image(sheet)
	_atlas_rects = rects
	_atlas_count = _baked.size()
	_plan = []
	_baked = []


## The baked sprite for `stat`/`variant` leaning -1, 0 or +1 in `season` (0 spring to 3 winter), open or `closed`.
## The head's top rows shift a texel with the lean and the stem foot stays put. Shrubs do not lean.
static func frame(stat: StringName, variant: int, lean: int, season: int = SEASON_SUMMER, closed: bool = false, dew: bool = false) -> Texture2D:
	var c: Dictionary = _canonical(variant, lean, season, closed, dew)
	var key: String = "%s:%d:%d:%d:%d" % [stat, variant, int(c.lean), int(c.season), int(c.state)]
	if _frames.has(key):
		return _frames[key] as Texture2D
	var tex: ImageTexture = ImageTexture.create_from_image(_bake(stat, variant, int(c.lean), int(c.season), int(c.state) == 1, int(c.state) == 2))
	_frames[key] = tex
	return tex


## Palette of one stat: petal, shade, light, heart as colours.
static func _palette(stat: StringName) -> Array[Color]:
	var pal: Array = COLORS[stat] as Array
	var out: Array[Color] = []
	for s: String in pal:
		out.append(Color(s))
	return out


static func _bake(stat: StringName, variant: int, lean: int, season: int, closed: bool, dew: bool) -> Image:
	var cells: Dictionary = {}   # Vector2i -> Color, centred on x = 0; y grows downward, the head sits around y = 0
	if is_shrub(variant):
		_shrub(cells, SHRUBS[variant - FLOWER_VARIANTS] as Array, season, _palette(stat))
		return _to_image(cells, 0)
	var pal: Array[Color] = _palette(stat)
	var petal: Color = pal[0]
	var shade: Color = pal[1]
	var light: Color = pal[2]
	var heart: Color = pal[3]
	var shape: Array = SHAPE[stat] as Array
	var n: int = int(shape[0])
	var sharp: float = float(shape[1])
	var rx: int
	var stem: int
	var leaves: int
	var phase: float = 0.0
	var outline: bool = is_field(variant)
	if is_field(variant):
		var k: int = field_scale(variant)
		var tint: int = field_tint(variant)
		rx = 4 * k + 1
		stem = 3 * k
		leaves = 2
		phase = 0.35 * float(tint) if tint < 3 else -0.6   # the last tint is the mirror image
		if tint == 1:
			petal = petal.lightened(0.22)
		elif tint == 2:
			petal = petal.darkened(0.24)
		elif tint == 3:
			petal = petal.lerp(Color("ffe9a8"), 0.18)
		shade = petal.darkened(0.35)
		light = petal.lightened(0.35)
	else:
		var head: Array = HEADS[variant] as Array
		rx = int(head[0])
		phase = float(head[1])
		stem = int(head[2])
		leaves = int(head[3])
	var ry: int = maxi(2, roundi(float(rx) * 0.7))   # the head is a foreshortened ellipse: about 0.7 as tall as it is wide
	# seasons: buds in spring, faded petals and seed heads in autumn, bare stalks in winter
	var fold: float = FOLD_CLOSED if closed else (FOLD_SPRING if season == SEASON_SPRING else 1.0)
	if season == SEASON_AUTUMN:
		petal = petal.lerp(Color("b0743a"), 0.5)
		shade = shade.lerp(Color("6b4420"), 0.5)
		light = light.lerp(Color("d9a25a"), 0.4)
		heart = Color(SEED)
	elif season == SEASON_SPRING:
		petal = petal.lerp(Color(LEAF_LIGHT), 0.1)
		heart = heart.lerp(Color(LEAF_LIGHT), 0.25)
	var foot: int = ry + stem + 1
	if stat == &"clover" and season != SEASON_WINTER:
		foot = maxi(foot, 2 * _clover_radius(rx, fold) + 4)   # the stalk shows under the lowest leaflet, the shadow stays clear of it
	# winter field stalks differ by tint: each tint adds three texels of height, tints 1 and 3 carry a dry seed head, tint 2 is fully frosted
	# and tint 0 has only a frosted tip
	var tint_w: int = field_tint(variant) if is_field(variant) and season == SEASON_WINTER else 0
	var stem_top: int = 0 if season != SEASON_WINTER else -ry - tint_w * 3
	var leaf_row: int = ry + 2 if season != SEASON_WINTER else foot - 2   # winter: the dead leaves lie at the stalk's foot
	for y in range(stem_top, foot):
		cells[Vector2i(0, y)] = Color(LEAF_DARK)
	if season == SEASON_WINTER:
		if is_field(variant) and (tint_w == 1 or tint_w == 3):
			# a dry seed head on the stalk, with one frosted shoulder so it reads at 1x
			cells[Vector2i(0, stem_top)] = Color(SEED)
			for x in [-1, 0, 1]:
				cells[Vector2i(x, stem_top + 1)] = Color(SEED)
			cells[Vector2i(0, stem_top + 2)] = Color(SEED).darkened(0.25)
			cells[Vector2i(-1, stem_top)] = Color(FROST)
		else:
			# frost: the stalk's top rows are white, and tint 2 adds a crown either side, so a bare stalk reads at 1x
			for y in [stem_top, stem_top + 1]:
				cells[Vector2i(0, y)] = Color(FROST)
			if not (is_field(variant) and tint_w == 0):
				for x in [-1, 1]:
					cells[Vector2i(x, stem_top + 1)] = Color(FROST)
					cells[Vector2i(x, stem_top + 2)] = Color("b9d6e0")
	var leaf_color: Color = Color(LEAF) if season != SEASON_WINTER else Color(LEAF_DARK)
	if season == SEASON_AUTUMN:
		leaf_color = Color("b8702e")
	# the basal leaves lie flat round the stem foot, drawn as a small ring seen from above, not as side-on bars: lit on the
	# upper-left, darker on the lower-right, and frosted in winter
	if leaves > 0:
		for dy in [-1, 0, 1]:
			for dx in [-2, -1, 0, 1, 2]:
				if (dx == 0 and dy == 0) or float(dx * dx) / 4.0 + float(dy * dy) > 1.0:
					continue
				var lit: bool = dx < 0 or dy < 0
				var c: Color = leaf_color if lit else Color(LEAF_DARK)
				if season == SEASON_WINTER:
					c = Color(FROST) if lit else Color("9fc0cc")
				elif season == SEASON_AUTUMN and not lit:
					c = Color("7a4220")
				cells[Vector2i(dx, leaf_row + dy)] = c
	var extent: Vector2i = Vector2i(rx, ry)   # how far the head reaches, for the dew
	if season != SEASON_WINTER:
		if stat == &"clover":
			extent = _clover(cells, rx, fold, petal, shade, light, heart)
		else:
			_head(cells, rx, ry, n, sharp, phase, fold, petal, shade, light, heart)
		if dew and not closed:
			_dew(cells, extent.x, extent.y, stat_seed(stat), heart)
	# the outline goes round the plant only, so the ground shadow below is never inked
	if outline:
		_outline(cells)
	# the ground shadow: an oval under the foot, widest on the foot row and fainter as it drops away. In winter a pale rime
	# lies on the ground instead. Only where nothing is drawn yet.
	if season == SEASON_WINTER:
		_ground_shadow(cells, rx, foot, RIME_ALPHA, Color(0.78, 0.9, 0.94))
	else:
		_ground_shadow(cells, rx, foot, SHADOW_ALPHA, Color(SHADOW.r, SHADOW.g, SHADOW.b))
	return _to_image(cells, lean)


## A foreshortened rosette: an ellipse about 0.62 as tall as wide, its edge scalloped into petals. The top-left of the
## petals is lit and the lower-right is shaded, so the head reads as a surface seen from above.
static func _head(cells: Dictionary, rx: int, ry: int, n: int, sharp: float, phase: float, fold: float,
		petal: Color, shade: Color, light: Color, heart: Color) -> void:
	for y in range(-ry, ry + 1):
		for x in range(-rx, rx + 1):
			var u: float = float(x) / float(rx)
			var v: float = float(y) / float(ry)
			var r: float = sqrt(u * u + v * v)
			var lobe: float = pow(0.5 + 0.5 * cos(float(n) * atan2(v, u) + phase), sharp)
			var edge: float = (0.62 + 0.38 * lobe) * fold
			if r > edge + 0.05:
				continue
			var lit: float = -(u * 0.7 + v * 0.7)
			var c: Color = petal
			if lit > 0.45:
				c = light
			elif lit < -0.25:
				c = shade
			if r <= 0.34:
				c = heart
			cells[Vector2i(x, y)] = c


## Leaflet radius of the four-leaf clover: half the head's radius across, shrunk when the head shuts.
static func _clover_radius(rx: int, fold: float) -> int:
	return maxi(1, roundi(float(rx) * 0.5 * fold))


## Four-leaf clover seen from above: four round leaflets, north, east, south and west of a cream heart, with a gap of one or two
## texels between them so each leaf reads on its own. The leaflets are lit upper-left like the petals of the other heads.
## Returns how far the plant reaches from its centre, for the dew.
static func _clover(cells: Dictionary, rx: int, fold: float, petal: Color, shade: Color, light: Color, heart: Color) -> Vector2i:
	var r: int = _clover_radius(rx, fold)
	var d: int = r + 2                                     # leaflet centre, two texels out from the heart
	var centres: Array[Vector2i] = [Vector2i(0, -d), Vector2i(d, 0), Vector2i(0, d), Vector2i(-d, 0)]
	for c: Vector2i in centres:
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				var dx: float = float(x) / float(r)
				var dy: float = float(y) / float(r)
				if dx * dx + dy * dy > 1.0 + 0.5 / float(r * r):
					continue
				var lit: float = -(dx * 0.7 + dy * 0.7)
				var col: Color = petal
				if lit > 0.45:
					col = light
				elif lit < -0.25:
					col = shade
				cells[c + Vector2i(x, y)] = col
	cells[Vector2i.ZERO] = heart
	return Vector2i(d + r, d + r)


## An oval ground shadow under the foot row. Each row below is narrower and fainter than the one above.
static func _ground_shadow(cells: Dictionary, rx: int, foot: int, alphas: Array[float], rgb: Color) -> void:
	for dy in alphas.size():
		var half: int = rx + 1 - dy * 2
		for x in range(-half, half + 1):
			var q := Vector2i(x, foot + dy)
			if not cells.has(q):
				cells[q] = Color(rgb.r, rgb.g, rgb.b, alphas[dy])


## Dew at dawn: a few pale drops on the lit petals of an open head, placed by the same hash as everything else.
static func _dew(cells: Dictionary, rx: int, ry: int, seed_v: int, heart: Color) -> void:
	for y in range(-ry, ry + 1):
		for x in range(-rx, rx + 1):
			var q := Vector2i(x, y)
			if not cells.has(q) or (cells[q] as Color).is_equal_approx(heart):
				continue
			if _hash(x, y, seed_v + 29) < 0.24:
				cells[q] = Color(DEW)


static func stat_seed(stat: StringName) -> int:
	return STATS.find(stat) * 101 + 7


## A leafy mound seen from above: lit upper-left, a darker front lip for depth, petal dots on top and a soft shadow.
static func _shrub(cells: Dictionary, layout: Array, season: int, pal: Array[Color]) -> void:
	var rx: int = int(layout[0])
	var ry: int = int(layout[1])
	var seed_v: int = int(layout[2])
	var lit: Color = Color(LEAF_LIGHT)
	var base: Color = Color(LEAF)
	var dark: Color = Color(LEAF_DARK)
	var dots: float = 0.16
	match season:
		SEASON_SPRING:
			lit = Color("a6e27a")
			dots = 0.07
		SEASON_AUTUMN:
			lit = Color("e0a448")
			base = Color("b8702e")
			dark = Color("7a4220")
			dots = 0.1
		SEASON_WINTER:
			lit = Color("4f9a6a")
			base = Color("2b6a4a")
			dark = Color("1d4a36")
			dots = 0.0
	for y in range(-ry, ry + 1):
		for x in range(-rx, rx + 1):
			var u: float = float(x) / float(rx)
			var v: float = float(y) / float(ry)
			var r: float = sqrt(u * u + v * v)
			if r > 1.0 + (_hash(x, y, seed_v) - 0.5) * 0.14:
				continue
			var c: Color = base
			var lit_amount: float = -(u * 0.7 + v * 0.7)
			if lit_amount > 0.35:
				c = lit
			elif v > 0.55 and r > 0.7:
				c = dark                  # the front lip of the mound
			elif lit_amount < -0.3:
				c = dark
			var h: float = _hash(x, y, seed_v + 7)
			if season == SEASON_WINTER and c == lit and h < 0.5:
				c = Color(FROST)
			elif h < dots:
				var pick: float = _hash(x, y, seed_v + 13)
				c = pal[0] if pick < 0.5 else (pal[2] if pick < 0.8 else pal[1])
			cells[Vector2i(x, y)] = c
	# the same soft oval under the mound as under a flower, starting one row below its front lip
	_ground_shadow(cells, rx, ry + 1, SHADOW_ALPHA, Color(SHADOW.r, SHADOW.g, SHADOW.b))


## A one texel ink line round the outside of a field flower (empty cells beside it only).
static func _outline(cells: Dictionary) -> void:
	var edge: Array[Vector2i] = []
	for c: Vector2i in cells:
		for o: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var q: Vector2i = c + o
			if not cells.has(q) and not edge.has(q):
				edge.append(q)
	for q: Vector2i in edge:
		cells[q] = INK


## Cell map to an image: centred on the middle column with room for a lean each side. A lean moves the top half one texel.
static func _to_image(cells: Dictionary, lean: int) -> Image:
	var half: int = 2
	var ymin: int = 0
	var ymax: int = 0
	var first: bool = true
	for c: Vector2i in cells:
		half = maxi(half, absi(c.x) + 2)
		if first:
			ymin = c.y
			ymax = c.y
			first = false
		else:
			ymin = mini(ymin, c.y)
			ymax = maxi(ymax, c.y)
	var h: int = ymax - ymin + 1
	var img := Image.create(half * 2 + 1, maxi(h, 1), false, Image.FORMAT_RGBA8)
	for c: Vector2i in cells:
		var from_bottom: int = ymax - c.y
		var shift: int = lean if (lean != 0 and from_bottom * 2 >= h) else 0
		img.set_pixel(c.x + half + shift, c.y - ymin, cells[c] as Color)
	return img


## A cheap deterministic 0 to 1 value per texel, so a shrub's dots and edge are the same every bake.
static func _hash(x: int, y: int, seed_v: int) -> float:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ (seed_v * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return float(h & 0xffff) / 65535.0
