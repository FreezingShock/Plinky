extends Node2D
## Larkmoor, the big meadow past the onboarding gate (tools/art/gen_larkmoor.py, layout in tools/art/larkmoor_layout.py).
## Same contract as meadow3d_scene.gd: one ground backdrop, tall props as y-sorted sprites with a foot anchor, and
## Marker2D anchors for what the game draws itself. The whole world is one 3040x1840 canvas at (0, 0), so texel
## coordinates are canvas pixels. Extra anchors: Arch (the way back to the onboarding meadow) and District_<id>
## markers that carry the district name for the banner.
const DIR: String = "res://assets/art/zone1b/larkmoor/"
const FAR_BACKDROP: Texture2D = preload("res://assets/art/zone1b/larkmoor/backdrop_far.png")
const GROUND_FG: Texture2D = preload("res://assets/art/zone1b/larkmoor/ground_fg.png")
const GROUND: Texture2D = preload("res://assets/art/zone1b/larkmoor/ground.png")
const LIFE_PATH: String = "res://world/larkmoor_life.json"
const GARDEN_PATH: String = "res://world/larkmoor_gardens.json"
const DISTRICT_RADIUS: float = 220.0   # texels (2x the old 110 with the frame); the banner shows the nearest district inside this

const PAD_SHADOW: Vector2 = Vector2(22.0, 4.0)   # the slab is 3 texels thick and 28 wide

## main.gd reads these to frame the zone (camera and walker bounds, walk mask, footstep and ambience lookups).
var world_rect: Rect2 = Rect2(260.0, 40.0, 2520.0, 1620.0)   # 2x the old frame; overwritten from larkmoor_life.json world
var mask_offset: Vector2i = Vector2i.ZERO
var placements_path: String = DIR + "placements3d.json"
var ground_path: String = DIR + "ground.png"

## Prop kinds that sway in the wind (world/sky_cycle.gd), as in the meadow.
const SWAY_KINDS: PackedStringArray = ["oak", "pine", "bush"]

var _data: Dictionary = {}
var react: LifeReact
var _sky: SkyCycle
var _shadows: SkyShadows
var _ground: Sprite2D
## Material for the pad plates (main.gd assigns it): they take the same cast shadows as the ground.
var pad_material: ShaderMaterial
var districts: Array[Dictionary] = []   # {id, name, pos}


func _ready() -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string(placements_path))
	var w: Array = _data.get("world", []) as Array
	if w.size() == 4:
		world_rect = Rect2(float(w[0]), float(w[1]), float(w[2]), float(w[3]))
	var bleed: Dictionary = _data.bleed
	var ground := Sprite2D.new()
	ground.name = "Ground"
	var far := FarLayer.new()
	far.texture = FAR_BACKDROP
	far.base = Vector2(float(bleed.ground_offset[0]) - 64.0, float(bleed.ground_offset[1]))
	add_child(far)
	ground.texture = GROUND_FG
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground.centered = false
	ground.position = Vector2(bleed.ground_offset[0], bleed.ground_offset[1])
	add_child(ground)
	var anchors := Node2D.new()
	anchors.name = "Anchors"
	add_child(anchors)
	var pad_i: int = 0
	for a: Dictionary in _data.anchors:
		var m := Marker2D.new()
		m.position = Vector2(a.sx, a.sy)
		match String(a.kind):
			"pad":
				m.name = "Pad%d" % pad_i
				m.set_meta("state", String(a.state))
				pad_i += 1
			"gate":
				m.name = "Gate"
			"arch":
				m.name = "Arch"
			"player_spawn":
				m.name = "Walker"
			"district":
				m.name = "District_" + String(a.id)
				m.set_meta("title", String(a.name))
				districts.append({"id": String(a.id), "name": String(a.name), "pos": m.position})
			"water":
				m.name = "Water_" + String(a.name)
				m.set_meta("radius", Vector2(a.rx, a.ry))
			_:
				continue
		anchors.add_child(m)
	_ground = ground
	_add_life(ground)
	_add_gardens()
	_add_sky()


## Day/night shade, rain and wind over the whole world (world/sky_cycle.gd).
func _add_sky() -> void:
	_shadows = SkyShadows.new()
	_shadows.name = "Shadows"
	add_child(_shadows)   # z 0, after the ground and grass: above them, below every prop and the walker
	_sky = SkyCycle.new()
	_sky.name = "Sky"
	_sky.area = world_rect.grow(10.0)
	_sky.noon_boost = 1.7   # Larkmoor's ground is brighter and greener than the meadow's, so its noon needs more exposure drop and a warmer cast
	_sky.shadows = _shadows
	_sky.ground_texture = GROUND   # haze and mist read the full picture, not the cut-out
	_ground.material = _sky.ground_material(load(DIR + "ground_n.png") as Texture2D, load(DIR + "ground_h.png") as Texture2D)
	pad_material = _sky.pad_material(load(DIR + "ground_h.png") as Texture2D, _ground.position)
	_place_atmosphere()
	add_child(_sky)
	_add_lights()


## Haze over the mountain strip along the top of the backdrop (all the way across: there is no island in front of
## it), mist over the sea band under it, and over Heronmere lake and the pond. The rects keep the shader to
## about a fifth of the world instead of all of it.
func _place_atmosphere() -> void:
	var ponds: Array = []
	for a: Dictionary in _data.anchors:
		if String(a.kind) == "water":
			ponds.append(Vector4(float(a.sx), float(a.sy), float(a.rx), float(a.ry)))
	_sky.ponds = ponds
	var rects: Array[Rect2] = [Rect2(world_rect.position.x - 260.0, 60.0, world_rect.size.x + 520.0, 340.0)]
	for p: Vector4 in ponds:
		rects.append(Rect2(p.x - p.z * 1.3, p.y - p.w * 1.3, p.z * 2.6, p.w * 2.6))
	_sky.haze_rects = rects
	_sky.haze_params = {
		"ground_origin": Vector2(float(_data.bleed.ground_offset[0]), float(_data.bleed.ground_offset[1])),
		"horizon_y": 92.0, "band_half": 46.0, "island_half": -600.0,   # negative: haze is full strength at every x
		"island": Vector4(705.0, 445.0, 560.0, 300.0),
	}


## Light pools: the gate and arch, the pads, the lanterns (added with the props), and a small one around the walker.
func _add_lights() -> void:
	var cfg: SkyConfig = _sky.light_config()
	for a: Dictionary in _data.anchors:
		match String(a.kind):
			"gate", "arch":
				_sky.add_light(Vector2(a.sx, a.sy), cfg.pool_gate_radius, 0.8)
			"pad":
				_sky.add_light(Vector2(a.sx, a.sy), cfg.pool_pad_radius, PAD_STRENGTH, &"pad")
				_shadows.add_pad(Vector2(a.sx, a.sy).round())   # before the casters, so their shadows get a copy above the plate
				_shadows.add_blob(Vector2(a.sx, a.sy), PAD_SHADOW.x, PAD_SHADOW.y)
	_sky.add_light(Vector2.ZERO, cfg.pool_walker_radius, 0.7, &"walker")


## The district whose centre is nearest the walker, or an empty dictionary when none is within DISTRICT_RADIUS.
## The y distance is doubled, as everywhere else, because the ground is a 2:1 view.
func district_at(p: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = DISTRICT_RADIUS
	for d: Dictionary in districts:
		var q: Vector2 = p - (d.pos as Vector2)
		var dist: float = Vector2(q.x, q.y * 2.0).length()
		if dist < best_d:
			best_d = dist
			best = d
	return best


## The flower gardens around each statistic's pads: one node draws them all (world/garden_layer.gd), above the grass and under
## the props, pads and walker, so a garden costs a single node however many flowers it holds.
func _add_gardens() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GARDEN_PATH))
	if not parsed is Dictionary:
		return
	var layer := GardenLayer.new()
	layer.name = "Gardens"
	add_child(layer)
	layer.setup((parsed as Dictionary).get("flowers", []) as Array)
	layer.pusher_group = &"walker"
	_gardens = layer


func _add_life(ground: Sprite2D) -> void:
	var life: Dictionary = MeadowLife.load_data(LIFE_PATH)
	if life.is_empty():
		return
	var lg := LifeGround.new()
	lg.name = "LifeGround"
	add_child(lg)
	lg.setup(ground, life.get("sway", []) as Array)
	var air := LifeAir.new()
	air.name = "LifeAir"
	air.z_index = 10
	add_child(air)
	air.setup(life, ground)
	react = LifeReact.new()  # bushes rustle, birds scatter, shore ripples, grass bends (world/life_react.gd)
	react.name = "LifeReact"
	react.z_index = 10
	add_child(react)
	react.setup(life, life.get("sway", []) as Array, 14)  # a bigger meadow, more birds
	lg.pusher_group = &"walker"


## Props load by chunk. The map is cut into CHUNK-texel squares. The chunks within LOAD_RING of the walker's chunk are
## spawned, and a chunk is unloaded once it is more than KEEP_RING away. Each prop is a sprite plus a shadow quad, so
## loading the whole 2x map at once would break the 1350-node ceiling (docs/perf.md). Each prop is still its own sprite
## at its foot, so the walker sorts behind or in front of it.
## Counted on placements3d.json, the worst walker spot loads 162 props at 160-texel chunks with rings 2 and 2 (about
## 1060 nodes with the lamp glows), against 299 props at the old 320 and 1 and 2 (about 1340). The walker is always at least
## 320 texels from the edge of the loaded area, the same guarantee the old settings gave.
const CHUNK: float = 160.0
const LOAD_RING: int = 2
const KEEP_RING: int = 2

var _occ_parent: Node2D = null
var _prop_index: Dictionary = {}     # Vector2i chunk -> Array of prop dictionaries (placements3d.json sprites)
var _loaded: Dictionary = {}         # Vector2i chunk -> Array of the Sprite2D props spawned for it
var _center: Vector2i = Vector2i(-99999, -99999)
var _lanterns_lit: bool = false       # lantern pools are added once per scene, not once per spawn
const LANTERN_STRENGTH: float = 1.0   # pool strength of a lantern: full, so the warm pool reads at 1x (QA: 0.9 was too faint)
const LANTERN_RADIUS_K: float = 1.0   # lantern pool radius as a share of the shrine radius (62 texels in content/config/sky.tres)
var _glows: Array = []                # lamp-head glows of the loaded lanterns (Sprite2D); faded in at night by _process
var _gardens: GardenLayer                # the flower gardens (world/garden_layer.gd); season and night are pushed in by _process
const PAD_STRENGTH: float = 0.9       # pool strength of a pad button; was 0.45, too faint to read as lit at night


## Index the props by chunk and light the lanterns. Nothing is spawned yet; the caller loads the chunks around the start.
func _begin(parent: Node2D) -> void:
	_occ_parent = parent
	_prop_index.clear()
	_loaded.clear()
	_center = Vector2i(-99999, -99999)
	# Lanterns are light data, not chunk data: every lantern gets its pool here, once, whether its chunk is loaded or not.
	var light_lanterns: bool = not _lanterns_lit and _sky != null
	_lanterns_lit = true
	for s: Dictionary in _data.sprites:
		var key: Vector2i = _chunk_of(Vector2(float(s.foot[0]), float(s.foot[1])))
		if not _prop_index.has(key):
			_prop_index[key] = []
		(_prop_index[key] as Array).append(s)
		if light_lanterns and String(s.kind) == "lantern":
			_sky.add_light(Vector2(float(s.x) + float(s.w) * 0.5, float(s.y) + float(s.h) * 0.3),
					_sky.light_config().pool_shrine_radius * LANTERN_RADIUS_K, LANTERN_STRENGTH, &"lantern")


func spawn_occluders(parent: Node2D) -> void:
	_begin(parent)
	_add_farm(parent)
	_refresh_center(_start_point())


## Same chunks as spawn_occluders, but yields to the next frame whenever `budget_ms` of a frame is used up. A zone swap
## under the transition wipe uses it, so the first load does not stall the wipe's peak.
func spawn_occluders_sliced(parent: Node2D, budget_ms: float) -> void:
	_begin(parent)
	_add_farm(parent)
	_center = _chunk_of(_start_point())
	var start_us: int = Time.get_ticks_usec()
	for key: Vector2i in _needed_keys(_center):
		if not _loaded.has(key):
			_load_chunk(key)
			if float(Time.get_ticks_usec() - start_us) / 1000.0 >= budget_ms:
				await get_tree().process_frame
				start_us = Time.get_ticks_usec()
	_rebuild_bushes()


## The Thistle Rise farm (world/farm/): always loaded, about two dozen nodes, so it is not chunked.
func _add_farm(parent: Node2D) -> void:
	FarmProps.spawn(parent, _sky, _shadows, _sky.rim_material if _sky != null else null)


## Keep the loaded chunks in step with the walker. Runs every frame, but only does work when the walker changes chunk.
func _process(_delta: float) -> void:
	if _occ_parent == null:
		return
	var w: Node2D = get_tree().get_first_node_in_group(&"walker") as Node2D
	if w != null:
		_refresh_center(w.position)
	# lamp heads glow only after dark: fade them with the night, and forget the glows of unloaded lanterns
	var night: float = _sky.night01 if _sky != null else 0.0
	_glows = _glows.filter(func(g: Variant) -> bool: return is_instance_valid(g))
	for g in _glows:
		(g as Sprite2D).modulate.a = night
	# the flowers follow the season, and shut their heads once it is dark
	if _gardens != null:
		var cal: Node = get_node_or_null(^"/root/Calendar")   # an autoload: named by path, since --script tests have no autoloads
		if cal != null:
			_gardens.season = int((cal.call(&"now") as Dictionary).get("season", GardenArt.SEASON_SUMMER))
		_gardens.closed = night > 0.6


func _exit_tree() -> void:
	for key: Vector2i in _loaded.keys():
		for sp in _loaded[key]:
			if is_instance_valid(sp):
				(sp as Sprite2D).queue_free()
	_loaded.clear()
	_glows.clear()
	_tex_cache.clear()
	_mat_cache.clear()


## Props spawned now, and every prop in the placements (tests and the bench read these).
func loaded_prop_count() -> int:
	var n: int = 0
	for key: Vector2i in _loaded.keys():
		n += (_loaded[key] as Array).size()
	return n


func prop_total() -> int:
	var n: int = 0
	for key: Vector2i in _prop_index.keys():
		n += (_prop_index[key] as Array).size()
	return n


func _chunk_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))


func _start_point() -> Vector2:
	for a: Dictionary in _data.anchors:
		if String(a.kind) == "player_spawn":
			return Vector2(float(a.sx), float(a.sy))
	return world_rect.get_center()


func _needed_keys(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy: int in range(-LOAD_RING, LOAD_RING + 1):
		for dx: int in range(-LOAD_RING, LOAD_RING + 1):
			out.append(c + Vector2i(dx, dy))
	return out


func _refresh_center(p: Vector2) -> void:
	var c: Vector2i = _chunk_of(p)
	if c == _center:
		return
	_center = c
	for key: Vector2i in _needed_keys(c):
		if not _loaded.has(key):
			_load_chunk(key)
	for key: Vector2i in _loaded.keys():
		if maxi(absi(key.x - c.x), absi(key.y - c.y)) > KEEP_RING:
			_unload_chunk(key)
	_rebuild_bushes()


func _load_chunk(key: Vector2i) -> void:
	var list: Array = []
	if _prop_index.has(key):
		for s: Dictionary in _prop_index[key]:
			list.append(_spawn_one(_occ_parent, s))
	_loaded[key] = list


func _unload_chunk(key: Vector2i) -> void:
	for sp in _loaded[key]:
		if is_instance_valid(sp):
			if _shadows != null:
				_shadows.remove_caster(sp as Sprite2D)
			(sp as Sprite2D).queue_free()
	_loaded.erase(key)


## Bushes rustle when the walker passes (LifeReact); the list follows the chunks that are loaded.
func _rebuild_bushes() -> void:
	if react == null:
		return
	var bushes: Array = []
	for key: Vector2i in _loaded.keys():
		for sp in _loaded[key]:
			if is_instance_valid(sp) and (sp as Sprite2D).has_meta(&"bush"):
				bushes.append(sp)
	react.set_bushes(bushes)


## A small dithered bloom for a lamp head: a warm disc with a Bayer-stepped falloff (the meadow's glow style), made once.
static var _glow_tex: Texture2D = null

static func _glow_texture() -> Texture2D:
	if _glow_tex == null:
		# a warm dithered bloom: a bright core that falls off over about 16 texels, six Bayer steps, no smooth edge
		var n: int = 32
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var bayer: Array = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
		for y in n:
			for x in n:
				var d: float = Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
				var fall: float = clampf(1.0 - d, 0.0, 1.0)
				fall = fall * sqrt(fall)
				var q: float = floorf(fall * 6.0 + (float(bayer[(y % 4) * 4 + x % 4]) + 0.5) / 16.0) / 6.0
				img.set_pixel(x, y, Color(1.0, 0.8, 0.42, q))
		_glow_tex = ImageTexture.create_from_image(img)
	return _glow_tex


## Textures and materials are made once per file and shared by every prop that uses it. Before, each spawn made a new
## padded copy and a new ShaderMaterial, and SkyCycle kept every one of them for its per-frame relight, so the list only grew.
var _tex_cache: Dictionary = {}      # file -> sway-padded Texture2D
var _mat_cache: Dictionary = {}      # "sway|file" or "rim|file" -> ShaderMaterial

func _padded(file: String) -> Texture2D:
	if not _tex_cache.has(file):
		_tex_cache[file] = SkyCycle.padded(load(DIR + file) as Texture2D)
	return _tex_cache[file] as Texture2D

func _prop_mat(sways: bool, nrm_file: String) -> ShaderMaterial:
	var key: String = ("sway|" if sways else "rim|") + nrm_file
	if _mat_cache.has(key):
		return _mat_cache[key] as ShaderMaterial
	var nrm: Texture2D = _padded(nrm_file) if sways else load(DIR + nrm_file) as Texture2D
	var m: ShaderMaterial = _sky.prop_material(sways, nrm)
	if m != null:   # null only before the sky is ready: try again on the next spawn rather than keep it
		_mat_cache[key] = m
	return m

func _spawn_one(parent: Node2D, s: Dictionary) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.name = "Occ_" + String(s.file).get_file().get_basename()
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.centered = false
	sp.position = Vector2(s.foot[0], s.foot[1])
	sp.offset = Vector2(float(s.x) - float(s.foot[0]), float(s.y) - float(s.foot[1]))
	if _sky != null and String(s.kind) in SWAY_KINDS:
		sp.texture = _padded(String(s.file))
		sp.offset.x -= float(SkyCycle.SWAY_PAD)
		sp.material = _sky.sway_material
		if s.has("nrm"):
			sp.material = _prop_mat(true, String(s.nrm))
	else:
		sp.texture = load(DIR + String(s.file)) as Texture2D
		if _sky != null:
			sp.material = _sky.rim_material
			if s.has("nrm"):
				sp.material = _prop_mat(false, String(s.nrm))
	parent.add_child(sp)
	if _shadows != null:
		_shadows.add_caster(sp, String(s.kind), Vector2(float(s.w), float(s.h)))
	if String(s.kind) == "bush":
		sp.set_meta(&"bush", true)
	if String(s.kind) == "lantern" and float(s.w) < 20.0 and _sky != null:   # ordinary lamps; the great lantern has its own look
		# the lamp head sits about 17 texels above the foot; z 6 puts the bloom above the night shade (z 5), so it stays bright
		var glow := Sprite2D.new()
		glow.name = "LampGlow"
		glow.texture = _glow_texture()
		glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		glow.position = Vector2(0.0, -17.0)
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = add
		glow.z_index = 6
		glow.modulate.a = _sky.night01
		sp.add_child(glow)
		_glows.append(glow)
	return sp
