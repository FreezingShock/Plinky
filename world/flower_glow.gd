class_name FlowerGlow
extends Node2D
## Night light on the flower fields. Each field keeps its own irregular shape: flowers of one statistic that stand close
## together form one field, and each flower head adds its own soft light to the ground under it, so the summed light
## follows the real outline of the patch and every head shows as a glint in its own colour (GardenArt.COLORS, the petal).
##
## Built once from the same flower list the GardenLayer draws (world/larkmoor_gardens.json, world/clearing_gardens.json),
## so it never drifts from the flowers. Each field is one baked texture (LEVELS alpha steps, one texel per world texel),
## drawn in one additive pass. Night only changes the node's alpha, so the glow costs no redraws between dusk and dawn
## and a handful of texture draws per frame.

## The tunables. Static so the mockup tool (tools/flower_glow_shots.gd) can try looks; the shipped values are these defaults.
static var enabled: bool = true
static var LINK_RANGE: float = 30.0     # texels: flowers closer than this belong to one field
static var HEAD_RADIUS: float = 11.0    # texels: how far one head's light reaches on the ground
static var SATURATE: float = 2.2        # summed head light that reads as full strength (lower = the fields fill in sooner)
static var DAY_ALPHA: float = 0.0       # the glow by day (0 keeps the open daytime meadow as it was)
static var NIGHT_ALPHA: float = 0.6     # the glow at full night
## The colour: the flower's own bright "neon" petal hue at full saturation and brightness (NEON), so each field glows in
## its flower's colour. TINT_MIX pulls it toward TINT_TOWARD if ever wanted (0 = off).
static var NEON: bool = true
static var TINT_TOWARD: Color = Color("ffe9a8")
static var TINT_MIX: float = 0.0
## A wider, fainter spill from each head that reaches onto the path and the grass around a field. 0 turns it off.
static var SPILL_RADIUS: float = 34.0   # texels
static var SPILL_SATURATE: float = 2.5  # summed light that reads as full strength in the spill
static var SPILL_ALPHA: float = 0.35    # the spill's strength against the core
const LEVELS: int = 16                  # alpha steps: pixel-crisp, no soft gradient to band
const BREATH_TIME: float = 3.0          # seconds for one slow breath
const BREATH_DEPTH: float = 0.12        # how far the breath dims the glow (0 = none)

var _fields: Array = []   # per layer: {"tex": ImageTexture, "pos": Vector2, "a": float}
var _night: float = 0.0


func _ready() -> void:
	material = TexelPad.additive_material()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## flowers: [x, y, stat index, variant] per flower, in ground texels (the GardenLayer list). Bakes every field once.
func setup(flowers: Array) -> void:
	_fields.clear()
	for group: PackedInt32Array in _cluster(flowers):
		var core: Dictionary = _bake(flowers, group, HEAD_RADIUS, SATURATE, 1.0)
		if not core.is_empty():
			_fields.append(core)
		if SPILL_RADIUS > 0.0:
			var spill: Dictionary = _bake(flowers, group, SPILL_RADIUS, SPILL_SATURATE, SPILL_ALPHA)
			if not spill.is_empty():
				_fields.append(spill)
	queue_redraw()
	_apply_alpha()


func field_count() -> int:
	return _fields.size()


## Night level 0..1 from the zone's sky. Lifts the alpha only; the fields are not redrawn.
func set_night(night01: float) -> void:
	var n: float = clampf(night01, 0.0, 1.0)
	if n != _night:
		_night = n
		_apply_alpha()


func _process(_delta: float) -> void:
	if _fields.is_empty() or FxConfig.reduce_motion or FxConfig.reduce_flashing or not _breathes():
		return
	_apply_alpha()


func _draw() -> void:
	for field: Dictionary in _fields:
		draw_texture(field.tex as ImageTexture, field.pos as Vector2, Color(1.0, 1.0, 1.0, float(field.a)))


func _apply_alpha() -> void:
	var a: float = lerpf(DAY_ALPHA, NIGHT_ALPHA, _night)
	if not (FxConfig.reduce_motion or FxConfig.reduce_flashing):
		var phase: float = fposmod(float(Time.get_ticks_msec()) / 1000.0 / BREATH_TIME, 1.0)
		a *= 1.0 - BREATH_DEPTH * (0.5 - 0.5 * cos(TAU * phase))
	modulate.a = a


## The breath only matters while there is light to breathe.
func _breathes() -> bool:
	return _night > 0.0 and BREATH_DEPTH > 0.0


## Groups the flowers into fields: the same statistic, linked when closer than LINK_RANGE (a flood fill over a grid of
## LINK_RANGE cells, so only neighbouring cells are checked). Returns the flower indices of each field.
func _cluster(flowers: Array) -> Array:
	var cell: float = LINK_RANGE
	var buckets: Dictionary = {}   # Vector2i cell -> PackedInt32Array of flower indices
	for i in flowers.size():
		var key: Vector2i = _cell_of(flowers[i] as Array, cell)
		if not buckets.has(key):
			buckets[key] = PackedInt32Array()
		var bucket_list: PackedInt32Array = buckets[key]   # packed arrays copy on read: write the list back after appending
		bucket_list.append(i)
		buckets[key] = bucket_list
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(flowers.size())
	seen.fill(0)
	var out: Array = []
	for start in flowers.size():
		if seen[start] != 0:
			continue
		seen[start] = 1
		var stack: PackedInt32Array = PackedInt32Array([start])
		var group: PackedInt32Array = PackedInt32Array()
		while not stack.is_empty():
			var i: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			group.append(i)
			var f: Array = flowers[i] as Array
			var base: Vector2i = _cell_of(f, cell)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var key: Vector2i = base + Vector2i(dx, dy)
					if not buckets.has(key):
						continue
					var bucket: PackedInt32Array = buckets[key]
					for j: int in bucket:
						if seen[j] != 0 or int(flowers[j][2]) != int(f[2]):
							continue
						if _dist(f, flowers[j] as Array) <= LINK_RANGE:
							seen[j] = 1
							stack.append(j)
		out.append(group)
	return out


func _cell_of(f: Array, cell: float) -> Vector2i:
	return Vector2i(floori(float(f[0]) / cell), floori(float(f[1]) / cell))


func _dist(a: Array, b: Array) -> float:
	return Vector2(float(a[0]) - float(b[0]), float(a[1]) - float(b[1])).length()


## One field's texture: every head stamps a soft round light (squared falloff to zero at HEAD_RADIUS) into a density
## grid, the grid is quantised to LEVELS alpha steps, and the colour is the field's statistic petal colour.
func _bake(flowers: Array, group: PackedInt32Array, radius: float, saturate: float, alpha: float) -> Dictionary:
	if group.is_empty():
		return {}
	var lo: Vector2i = Vector2i(1 << 30, 1 << 30)
	var hi: Vector2i = Vector2i(-(1 << 30), -(1 << 30))
	for i: int in group:
		var f: Array = flowers[i] as Array
		lo = Vector2i(mini(lo.x, int(f[0])), mini(lo.y, int(f[1])))
		hi = Vector2i(maxi(hi.x, int(f[0])), maxi(hi.y, int(f[1])))
	var r: int = ceili(radius)
	var origin: Vector2i = lo - Vector2i(r, r)
	var w: int = hi.x - lo.x + 2 * r + 1
	var h: int = hi.y - lo.y + 2 * r + 1
	var side: int = 2 * r + 1
	var kernel: PackedFloat32Array = PackedFloat32Array()
	kernel.resize(side * side)
	for ky in side:
		for kx in side:
			var d: float = Vector2(float(kx - r), float(ky - r)).length() / radius
			kernel[ky * side + kx] = (1.0 - d) * (1.0 - d) if d < 1.0 else 0.0
	var density: PackedFloat32Array = PackedFloat32Array()
	density.resize(w * h)
	density.fill(0.0)
	for i: int in group:
		var f: Array = flowers[i] as Array
		var cx: int = int(f[0]) - origin.x
		var cy: int = int(f[1]) - origin.y
		for ky in side:
			var row: int = (cy - r + ky) * w + (cx - r)
			for kx in side:
				density[row + kx] += kernel[ky * side + kx]
	var tint: Color = _tint(int(flowers[group[0]][2]))
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(w * h * 4)
	var red: int = roundi(tint.r * 255.0)
	var green: int = roundi(tint.g * 255.0)
	var blue: int = roundi(tint.b * 255.0)
	for p in w * h:
		var a: float = floorf(clampf(density[p] / saturate, 0.0, 1.0) * LEVELS) / LEVELS * alpha
		bytes[p * 4] = red
		bytes[p * 4 + 1] = green
		bytes[p * 4 + 2] = blue
		bytes[p * 4 + 3] = roundi(a * 255.0)
	var img: Image = Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, bytes)
	return {"tex": ImageTexture.create_from_image(img), "pos": Vector2(origin), "a": alpha}


## The petal colour of one statistic (GardenArt.COLORS), so each field's light matches its flowers.
static func _tint(stat_index: int) -> Color:
	var stat: StringName = GardenArt.STATS[clampi(stat_index, 0, GardenArt.STATS.size() - 1)]
	var petal: Color = Color(String((GardenArt.COLORS[stat] as Array)[0]))
	if NEON:
		petal = Color.from_hsv(petal.h, 1.0, 1.0)
	return petal.lerp(TINT_TOWARD, TINT_MIX)
