class_name FarmProps
extends RefCounted
## The Larkmoor farm district (Foxglove Rise): irregular fields of wheat on tilled soil that gust and part around the walker, a barn, a
## shed, a scarecrow, hay bales, a cart and crates. The layout comes from assets/art/zone1b/farm/farm.json
## (tools/art/place_farm.py); the props from tools/art/gen_farm.py; the wheat sheets from tools/bake_wheat.gd, drawn by
## WheatClump from each clump's seed. Plain props are sprites at their foot with the meadow's rim light and a cast
## shadow. Wheat clumps are canvas items at their foot, owned by FarmWheat (no node each), so the walker sorts against them by Y.

const MANIFEST: String = "res://assets/art/zone1b/farm/farm.json"
const DIR: String = "res://assets/art/zone1b/farm/"
const FIELD_PREFIX: String = "farm_wheat"   # every wheat clump's kind starts with this
const FIELD_FRAME_W: int = 48                 # default for an item without its own width
const FENCE_PREFIX: String = "farm_fence"     # the fence ring: one sprite for the whole ring, low and open
const SOIL_PREFIX: String = "farm_soil"       # the tilled soil under each field: a ground decal, drawn behind everything


static func load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return parsed as Dictionary if parsed is Dictionary else {}


## True when a farm item of this kind is a wheat clump (an animated sheet that parts around the walker).
static func is_field(kind: String) -> bool:
	return kind.begins_with(FIELD_PREFIX)


## True when a farm item of this kind is the soil under a field: flat on the ground, so it takes no rim light and casts no shadow.
static func is_soil(kind: String) -> bool:
	return kind.begins_with(SOIL_PREFIX)


## True when a farm item of this kind casts a drop shadow. Wheat is ground cover and does not, the fence ring is
## low and open (one sprite over its whole box, so a shadow would cover the field), and soil is flat on the ground.
static func casts_shadow(kind: String) -> bool:
	return not is_field(kind) and not kind.begins_with(FENCE_PREFIX) and not is_soil(kind)


## One wheat clump's generation, run on a worker thread by prepare(). `clump` is set by the worker.
class ClumpJob extends RefCounted:
	var w: int = 0
	var h: int = 0
	var seed_value: int = 0
	var stage: int = 1
	var clump: Dictionary = {}


static var _data: Dictionary = {}     # the manifest prepare() read, which spawn() uses when no manifest is passed
static var _jobs: Array = []          # one ClumpJob per manifest item (null for the rest), in item order
static var _group: int = -1           # the worker group task that fills _jobs; -1 when nothing is prepared


## Reads the manifest and starts every wheat clump generating on the worker pool. The Larkmoor swap calls it while the
## wipe covers the screen, so spawn() waits on finished clumps instead of generating about 660 of them on the frame it
## spawns. Returns the sprite paths the farm uses, for ZoneAssets to load on its workers. Safe to call again: it does
## nothing while a prepare is already in flight.
static func prepare() -> PackedStringArray:
	var paths := PackedStringArray()
	if _group >= 0:
		return paths
	_data = load_manifest()
	_jobs = []
	var todo: Array = []
	for it: Variant in _data.get("items", []) as Array:
		var item: Dictionary = it as Dictionary
		var file: String = str(item.get("file", ""))
		if file != "":
			paths.append(DIR + file)
		var kind: String = str(item.get("kind", ""))
		if is_field(kind):
			var job := ClumpJob.new()
			job.w = int(item.get("w", FIELD_FRAME_W))
			job.h = int(item.get("h", FIELD_FRAME_W))
			job.seed_value = int(item.get("seed", 0))
			job.stage = int(item.get("stage", 1))
			_jobs.append(job)
			todo.append(job)
		else:
			_jobs.append(null)
	if not todo.is_empty():
		# two workers at most: the rest stay free for the scene's own decodes and loads
		_group = WorkerThreadPool.add_group_task(_generate.bind(todo), todo.size(), 2, false, "farm wheat")
	return paths


## A worker's share of prepare(): one clump, written into its own job so no two workers touch the same value.
static func _generate(i: int, todo: Array) -> void:
	var job: ClumpJob = todo[i] as ClumpJob
	job.clump = WheatClump.generate(job.seed_value, job.w, job.h, job.stage)


## Adds the farm under `parent`, which must be the y-sorted prop parent. Pass `manifest` to test with other data. With no
## manifest, a prepare() that ran (the Larkmoor swap's cover) supplies the data and the finished clumps. Builds in one go.
static func spawn(parent: Node2D, sky: SkyCycle, shadows: SkyShadows, rim: ShaderMaterial,
		manifest: Dictionary = {}) -> void:
	_build(parent, sky, shadows, rim, manifest, 0.0)


## The same farm as spawn, built over frames: it yields whenever `budget_ms` of a frame is used up, and it waits (without
## blocking) for the prepared clumps and the sprites' threaded loads. The Larkmoor swap uses it under the wipe, so the
## farm's 660-odd items never land on one frame.
static func spawn_sliced(parent: Node2D, sky: SkyCycle, shadows: SkyShadows, rim: ShaderMaterial, budget_ms: float) -> void:
	await _build(parent, sky, shadows, rim, {}, budget_ms)


static func _build(parent: Node2D, sky: SkyCycle, shadows: SkyShadows, rim: ShaderMaterial,
		manifest: Dictionary, budget_ms: float) -> void:
	var sliced: bool = budget_ms > 0.0
	var prepared: bool = manifest.is_empty() and _group >= 0
	if prepared and sliced:
		while not WorkerThreadPool.is_group_task_completed(_group):
			await parent.get_tree().process_frame
			if not is_instance_valid(parent) or not parent.is_inside_tree():
				return
	elif prepared:
		WorkerThreadPool.wait_for_group_task_completion(_group)
	var data: Dictionary = _data if prepared else (manifest if not manifest.is_empty() else load_manifest())
	var jobs: Array = _jobs if prepared else []
	if prepared:
		_group = -1
		_jobs = []
	if data.is_empty():
		push_warning("farm: no manifest at %s" % MANIFEST)
		return
	var wheat := FarmWheat.new()
	wheat.name = "FarmWheat"
	parent.add_child(wheat)
	var n: int = 0
	var items: Array = data.get("items", []) as Array
	var start_us: int = Time.get_ticks_usec()
	for k: int in items.size():
		if sliced and float(Time.get_ticks_usec() - start_us) / 1000.0 >= budget_ms:
			await parent.get_tree().process_frame
			if not is_instance_valid(parent) or not parent.is_inside_tree():
				return
			start_us = Time.get_ticks_usec()
		var item: Dictionary = items[k] as Dictionary
		var kind: String = str(item.get("kind", ""))
		var file: String = str(item.get("file", ""))
		var path: String = DIR + file
		if sliced:
			while not ZoneAssets.ready(path):
				await parent.get_tree().process_frame
				if not is_instance_valid(parent) or not parent.is_inside_tree():
					return
		var tex: Texture2D = ZoneAssets.texture(path)
		if tex == null:
			push_warning("farm: missing sprite for %s (run tools/bake_wheat.gd)" % kind)
			continue
		var fa: Array = item.get("foot", []) as Array
		var foot := Vector2(float(fa[0]), float(fa[1]))
		var origin := Vector2(float(item.get("x", 0)), float(item.get("y", 0)))
		if is_field(kind):
			# Wheat is a canvas item owned by the driver, not a node: it sorts by Y like a sprite and costs no node.
			var clump: Dictionary
			var job: ClumpJob = jobs[k] as ClumpJob if k < jobs.size() else null
			if job != null:
				clump = job.clump
			else:
				clump = WheatClump.generate(int(item.get("seed", 0)), int(item.get("w", FIELD_FRAME_W)),
					int(item.get("h", FIELD_FRAME_W)), int(item.get("stage", 1)))
			wheat.add_clump(parent, origin, foot, tex, clump, int(item.get("phase", 0)))
			continue
		var sp := Sprite2D.new()
		sp.name = "Farm%d_%s" % [n, kind.trim_prefix("farm_")]
		n += 1
		sp.texture = tex
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.centered = false
		sp.position = foot
		sp.offset = origin - foot
		if rim != null and not is_soil(kind):
			sp.material = rim
		parent.add_child(sp)
		if shadows != null and casts_shadow(kind):
			shadows.add_caster(sp, "", Vector2(float(item.get("w", 0)), float(item.get("h", 0))))
	var channels: Array = data.get("brooks", []) as Array
	if not channels.is_empty():
		var channel: CozyBrook = CozyBrook.make(channels)
		channel.name = "FarmChannel"
		parent.add_child(channel)
