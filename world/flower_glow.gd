class_name FlowerGlow
extends Node2D
## Night light on the flower fields. Each field keeps its own irregular shape: flowers of one statistic that stand close
## together form one field, and each flower head adds its own soft light to the ground under it, so the summed light
## follows the real outline of the patch and every head shows as a glint in its own colour (GardenArt.COLORS, the petal).
##
## Built from the same flower list the GardenLayer draws (world/larkmoor_gardens.json, world/clearing_gardens.json),
## so it never drifts from the flowers. Each field is one baked texture (LEVELS alpha steps, one texel per world texel),
## drawn in one additive pass. Night only changes the node's alpha, so the glow costs no redraws between dusk and dawn
## and a handful of texture draws per frame.
##
## The clustering and the bake are arithmetic over every flower head, so they run on a worker thread and the zone's load
## frame does not wait for them. The textures are made on the main thread once the bake finishes, and the glow fills in
## over the first moments of a zone. finish() waits for the bake at once (tests and tools use it).

## The tunables. Static so the mockup tool (tools/flower_glow_shots.gd) can try looks; the shipped values are these defaults.
static var enabled: bool = true
static var LINK_RANGE: float = 30.0     # texels: flowers closer than this belong to one field
static var HEAD_RADIUS: float = 11.0    # texels: how far one head's light reaches on the ground
static var SATURATE: float = 2.2        # summed head light that reads as full strength (lower = the fields fill in sooner)
static var DAY_ALPHA: float = 0.0       # the glow by day (0 keeps the open daytime meadow as it was)
static var NIGHT_ALPHA: float = 0.6     # the glow at full night
## Winter nights: the glow is scaled by this. The bare winter stalks sit under a blue halo at full strength, which reads as
## dither, so in winter the halo is calmer (0.6 x 0.42 = 0.25 at full night). Other seasons keep NIGHT_ALPHA.
static var WINTER_SCALE: float = 0.42
## The colour: the flower's own petal hue at 75% saturation and full brightness (NEON, NEON_SAT), so each field glows in
## its flower's colour. TINT_MIX pulls it toward TINT_TOWARD if ever wanted (0 = off).
static var NEON: bool = true
static var NEON_SAT: float = 0.75      # saturation of the glow hue: 1 is full neon, 0.75 keeps each field's colour without the glare
static var NEON_VAL: float = 1.0       # brightness of the neon hue (1 = full)
static var TINT_TOWARD: Color = Color("ffe9a8")
static var TINT_MIX: float = 0.0
## A wider, fainter spill from each head that reaches onto the path and the grass around a field. 0 turns it off.
static var SPILL_RADIUS: float = 34.0   # texels
static var SPILL_SATURATE: float = 2.5  # summed light that reads as full strength in the spill
static var SPILL_ALPHA: float = 0.35    # the spill's strength against the core
const LEVELS: int = 16                  # alpha steps: pixel-crisp, no soft gradient to band
const BREATH_TIME: float = 3.0          # seconds for one slow breath
const BREATH_DEPTH: float = 0.12        # how far the breath dims the glow (0 = none)
## The field light stays off the pad plates: under each plate it is cut to PAD_CUT, easing back to full by PAD_CUT_EDGE
## (plate units, diamond-ellipse norm). The pad rings then read against dark ground, not against the field.
const PAD_CUT: float = 0.5
const PAD_CUT_EDGE: float = 1.2
const START_DELAY_FRAMES: int = 8       # frames after a zone's glow is set up before its bake starts on a worker

var _fields: Array = []   # built layers: {"tex": ImageTexture, "pos": Vector2, "a": float}
var _job: BakeJob = null  # the bake queued for this zone (running on a worker thread once started), or null
var _start_in: int = 0   # frames left before the bake goes to a worker: the zone's entry frames stay clear of it
var _night: float = 0.0


func _ready() -> void:
	material = TexelPad.additive_material()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## flowers: [x, y, stat index, variant] per flower, in ground texels (the GardenLayer list). pads: the plate centres in the
## same texels (pad_centres), so the field light is cut under them. Queues the whole bake (the clustering and every
## field's core and spill layer) on a worker thread; the textures appear when it finishes.
func setup(flowers: Array, pads: PackedVector2Array = PackedVector2Array()) -> void:
	_fields.clear()
	_job = null
	if flowers.is_empty():
		return
	# Packed arrays are values in GDScript: fill local copies, then hand them to the job whole.
	var xs := PackedInt32Array()
	var ys := PackedInt32Array()
	var stats := PackedInt32Array()
	for f: Array in flowers:
		xs.append(int(f[0]))
		ys.append(int(f[1]))
		stats.append(int(f[2]))
	var tints: Array = []
	# The petal colours are read here, on the main thread, one per statistic.
	for s in GardenArt.STATS.size():
		tints.append(_tint(s))
	var job := BakeJob.new()
	job.xs = xs
	job.ys = ys
	job.stats = stats
	job.tints = tints
	job.link_range = LINK_RANGE
	job.head_radius = HEAD_RADIUS
	job.saturate = SATURATE
	job.spill_radius = SPILL_RADIUS
	job.spill_saturate = SPILL_SATURATE
	job.spill_alpha = SPILL_ALPHA
	job.levels = LEVELS
	job.pads = pads
	_job = job
	_start_in = START_DELAY_FRAMES
	_apply_alpha()


## Builds the bake's textures now, running the bake on this thread if it has not started. The game does not need this
## (the glow fills in moments after a zone loads); the tests and the mockup tool use it to read the finished fields.
func finish() -> void:
	if _job != null:
		if _job.task < 0:
			_job.run()
		else:
			WorkerThreadPool.wait_for_task_completion(_job.task)
		_install(_job)
		_job = null
	_apply_alpha()


## The number of built layers (a field's core and its spill each count once).
func field_count() -> int:
	return _fields.size()


## Night level 0..1 from the zone's sky. Lifts the alpha only; the fields are not redrawn.
func set_night(night01: float) -> void:
	var n: float = clampf(night01, 0.0, 1.0)
	if n != _night:
		_night = n
		_apply_alpha()


var _rain_seen: float = -1.0
var _winter: bool = false   # the zone's season is winter: the glow uses WINTER_SCALE

func _process(_delta: float) -> void:
	if _job != null:
		if _job.task < 0:
			_start_in -= 1
			if _start_in <= 0:
				_job.task = WorkerThreadPool.add_task(_job.run, false, "flower glow bake")
		elif WorkerThreadPool.is_task_completed(_job.task):
			WorkerThreadPool.wait_for_task_completion(_job.task)
			_install(_job)
			_job = null
	if _fields.is_empty():
		return
	# rain changes the glow even with Reduce motion on, so the alpha follows it; the breath stays off under Reduce motion
	if MeadowLife.rain != _rain_seen:
		_rain_seen = MeadowLife.rain
		_apply_alpha()
		return
	if FxConfig.still() or FxConfig.reduce_flashing or not _breathes():
		return
	_apply_alpha()


func _draw() -> void:
	for field: Dictionary in _fields:
		draw_texture(field.tex as ImageTexture, field.pos as Vector2, Color(1.0, 1.0, 1.0, float(field.a)))


## Rain: the flower light swells by RAIN_BLOOM at full rain (the lamps' bloom is SkyModel.lamp_bloom).
const RAIN_BLOOM: float = 0.5

## Winter or not. Only the alpha changes, so the season costs no redraw.
func set_winter(on: bool) -> void:
	if on != _winter:
		_winter = on
		_apply_alpha()


func _apply_alpha() -> void:
	var season_k: float = WINTER_SCALE if _winter else 1.0
	var a: float = lerpf(DAY_ALPHA, NIGHT_ALPHA, _night) * season_k * (1.0 + RAIN_BLOOM * clampf(MeadowLife.rain, 0.0, 1.0))
	if not (FxConfig.still() or FxConfig.reduce_flashing):
		var phase: float = fposmod(float(Time.get_ticks_msec()) / 1000.0 / BREATH_TIME, 1.0)
		a *= 1.0 - BREATH_DEPTH * (0.5 - 0.5 * cos(TAU * phase))
	modulate.a = a


## The breath only matters while there is light to breathe.
func _breathes() -> bool:
	return _night > 0.0 and BREATH_DEPTH > 0.0


## Makes each finished layer's texture on the main thread and adds it to the drawn layers.
func _install(job: BakeJob) -> void:
	for layer: Dictionary in job.layers:
		var img: Image = Image.create_from_data(int(layer.w), int(layer.h), false, Image.FORMAT_RGBA8, layer.bytes as PackedByteArray)
		_fields.append({"tex": ImageTexture.create_from_image(img), "pos": Vector2(layer.origin as Vector2i), "a": float(layer.a)})
	queue_redraw()


## The petal colour of one statistic (GardenArt.COLORS), so each field's light matches its flowers.
static func _tint(stat_index: int) -> Color:
	var stat: StringName = GardenArt.STATS[clampi(stat_index, 0, GardenArt.STATS.size() - 1)]
	var petal: Color = Color(String((GardenArt.COLORS[stat] as Array)[0]))
	if NEON:
		petal = Color.from_hsv(petal.h, NEON_SAT, NEON_VAL)
	return petal.lerp(TINT_TOWARD, TINT_MIX)


## Groups the flowers into fields: the same statistic, linked when closer than link_range (a flood fill over a grid of
## link_range cells, so only neighbouring cells are checked). Returns the flower indices of each field.
static func cluster_fields(xs: PackedInt32Array, ys: PackedInt32Array, stats: PackedInt32Array, link_range: float) -> Array:
	var n: int = xs.size()
	var buckets: Dictionary = {}   # Vector2i cell -> PackedInt32Array of flower indices
	for i in n:
		var key: Vector2i = _cell_of(xs[i], ys[i], link_range)
		if not buckets.has(key):
			buckets[key] = PackedInt32Array()
		var bucket_list: PackedInt32Array = buckets[key]   # packed arrays copy on read: write the list back after appending
		bucket_list.append(i)
		buckets[key] = bucket_list
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(n)
	seen.fill(0)
	var out: Array = []
	for start in n:
		if seen[start] != 0:
			continue
		seen[start] = 1
		var stack: PackedInt32Array = PackedInt32Array([start])
		var group: PackedInt32Array = PackedInt32Array()
		while not stack.is_empty():
			var i: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			group.append(i)
			var base: Vector2i = _cell_of(xs[i], ys[i], link_range)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var key: Vector2i = base + Vector2i(dx, dy)
					if not buckets.has(key):
						continue
					var bucket: PackedInt32Array = buckets[key]
					for j: int in bucket:
						if seen[j] != 0 or stats[j] != stats[i]:
							continue
						if Vector2(float(xs[i] - xs[j]), float(ys[i] - ys[j])).length() <= link_range:
							seen[j] = 1
							stack.append(j)
		out.append(group)
	return out


## The plate centres of a zone's pad anchors (kind "pad", sx and sy in texels), for setup.
static func pad_centres(anchors: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for a: Dictionary in anchors:
		if String(a.kind) == "pad":
			out.append(Vector2(float(a.sx), float(a.sy)))
	return out


static func _cell_of(x: int, y: int, cell: float) -> Vector2i:
	return Vector2i(floori(float(x) / cell), floori(float(y) / cell))


## Everything the worker thread needs, copied in on the main thread. The worker reads these packed copies and writes only
## its own layers, so it never touches a node, the GardenArt data or the caller's flower list.
class BakeJob extends RefCounted:
	var xs: PackedInt32Array = PackedInt32Array()
	var ys: PackedInt32Array = PackedInt32Array()
	var stats: PackedInt32Array = PackedInt32Array()
	var tints: Array = []          # one petal Color per statistic index
	var link_range: float = 30.0
	var head_radius: float = 11.0
	var saturate: float = 2.2
	var spill_radius: float = 0.0
	var spill_saturate: float = 2.5
	var spill_alpha: float = 0.35
	var levels: int = 16
	var pads: PackedVector2Array = PackedVector2Array()   # plate centres the field light is cut under
	var task: int = -1
	var layers: Array = []         # finished layers: {"w", "h", "origin": Vector2i, "bytes", "a"}

	## Clusters the fields, then bakes each field's core layer and (when on) its spill layer.
	func run() -> void:
		var groups: Array = FlowerGlow.cluster_fields(xs, ys, stats, link_range)
		for group: PackedInt32Array in groups:
			var tint: Color = tints[clampi(stats[group[0]], 0, tints.size() - 1)] as Color
			layers.append(_bake(group, head_radius, saturate, 1.0, tint))
			if spill_radius > 0.0:
				layers.append(_bake(group, spill_radius, spill_saturate, spill_alpha, tint))

	## Dims the field light under each pad plate, so the plate's ring reads against dark ground rather than the field.
	func _cut_pads(density: PackedFloat32Array, w: int, h: int, org: Vector2i) -> void:
		var hx: float = TexelPad.HALF.x
		var hy: float = TexelPad.HALF.y
		for pc: Vector2 in pads:
			var cx: float = pc.x - float(org.x)
			var cy: float = pc.y - float(org.y)
			var x0: int = maxi(0, floori(cx - hx * PAD_CUT_EDGE))
			var x1: int = mini(w - 1, ceili(cx + hx * PAD_CUT_EDGE))
			var y0: int = maxi(0, floori(cy - hy * PAD_CUT_EDGE))
			var y1: int = mini(h - 1, ceili(cy + hy * PAD_CUT_EDGE))
			for y in range(y0, y1 + 1):
				var ny: float = (float(y) - cy) / hy
				for x in range(x0, x1 + 1):
					var nx: float = (float(x) - cx) / hx
					var e: float = sqrt(nx * nx + ny * ny)
					if e >= PAD_CUT_EDGE:
						continue
					var t: float = clampf((e - 1.0) / (PAD_CUT_EDGE - 1.0), 0.0, 1.0)
					var f: float = lerpf(PAD_CUT, 1.0, t * t * (3.0 - 2.0 * t))
					density[y * w + x] *= f

	## One layer's texture data. Every head stamps a soft round light (squared falloff to zero at radius) into a density
	## grid, the grid is quantised to LEVELS alpha steps, and the colour is the field's petal colour. One texel per texel.
	func _bake(group: PackedInt32Array, radius: float, sat: float, alpha: float, tint: Color) -> Dictionary:
		var lo: Vector2i = Vector2i(1 << 30, 1 << 30)
		var hi: Vector2i = Vector2i(-(1 << 30), -(1 << 30))
		for i: int in group:
			lo = Vector2i(mini(lo.x, xs[i]), mini(lo.y, ys[i]))
			hi = Vector2i(maxi(hi.x, xs[i]), maxi(hi.y, ys[i]))
		var r: int = ceili(radius)
		var org: Vector2i = lo - Vector2i(r, r)
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
			var cx: int = xs[i] - org.x
			var cy: int = ys[i] - org.y
			for ky in side:
				var row: int = (cy - r + ky) * w + (cx - r)
				for kx in side:
					density[row + kx] += kernel[ky * side + kx]
		_cut_pads(density, w, h, org)
		var bytes: PackedByteArray = PackedByteArray()
		bytes.resize(w * h * 4)
		var red: int = roundi(tint.r * 255.0)
		var green: int = roundi(tint.g * 255.0)
		var blue: int = roundi(tint.b * 255.0)
		var steps: float = float(levels)
		for p in w * h:
			var a: float = floorf(clampf(density[p] / sat, 0.0, 1.0) * steps) / steps * alpha
			bytes[p * 4] = red
			bytes[p * 4 + 1] = green
			bytes[p * 4 + 2] = blue
			bytes[p * 4 + 3] = roundi(a * 255.0)
		return {"w": w, "h": h, "origin": org, "bytes": bytes, "a": alpha}
