extends Node2D
## Larkmoor, the big meadow past the onboarding gate (tools/art/gen_larkmoor.py, layout in tools/art/larkmoor_layout.py).
## Same contract as meadow3d_scene.gd: one ground backdrop, tall props as y-sorted sprites with a foot anchor, and
## Marker2D anchors for what the game draws itself. The whole world is one 1520x920 canvas at (0, 0), so texel
## coordinates are canvas pixels. Extra anchors: Arch (the way back to the onboarding meadow) and District_<id>
## markers that carry the district name for the banner.
const DIR: String = "res://assets/art/zone1b/larkmoor/"
const FAR_BACKDROP: Texture2D = preload("res://assets/art/zone1b/larkmoor/backdrop_far.png")
const GROUND_FG: Texture2D = preload("res://assets/art/zone1b/larkmoor/ground_fg.png")
const GROUND: Texture2D = preload("res://assets/art/zone1b/larkmoor/ground.png")
const LIFE_PATH: String = "res://world/larkmoor_life.json"
const DISTRICT_RADIUS: float = 110.0   # texels; the banner shows the nearest district inside this

const PAD_SHADOW: Vector2 = Vector2(22.0, 4.0)   # the slab is 3 texels thick and 28 wide

## main.gd reads these to frame the zone (camera and walker bounds, walk mask, footstep and ambience lookups).
var world_rect: Rect2 = Rect2(130.0, 20.0, 1260.0, 810.0)
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
	var rects: Array[Rect2] = [Rect2(world_rect.position.x - 130.0, 30.0, world_rect.size.x + 260.0, 170.0)]
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
				_sky.add_light(Vector2(a.sx, a.sy), cfg.pool_pad_radius, 0.45)
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


## Each tall prop is its own sprite at its foot, so the walker sorts behind or in front of it.
func spawn_occluders(parent: Node2D) -> void:
	var bush_sprites: Array = []
	for s: Dictionary in _data.sprites:
		_spawn_one(parent, s, bush_sprites)
	if react != null:
		react.set_bushes(bush_sprites)


## Same result as spawn_occluders, but yields to the next frame whenever `budget_ms` of a frame is used up. A zone swap
## under the transition wipe uses it: the 400-odd texture loads and padded copies cost about 170 ms in one go, which
## was a visible stall at the wipe's peak.
func spawn_occluders_sliced(parent: Node2D, budget_ms: float) -> void:
	var bush_sprites: Array = []
	var start: int = Time.get_ticks_usec()
	var i: int = 0
	for s: Dictionary in _data.sprites:
		i += 1
		_spawn_one(parent, s, bush_sprites)
		if float(Time.get_ticks_usec() - start) / 1000.0 >= budget_ms:
			var yielded: int = Time.get_ticks_usec()
			await get_tree().process_frame
			start = Time.get_ticks_usec()
			if PerfStats.tracing and float(start - yielded) / 1000.0 > 25.0:
				PerfStats.trace.append("slice frame gap %.1f ms (after %d props)" % [float(start - yielded) / 1000.0, i])
	if react != null:
		react.set_bushes(bush_sprites)


func _spawn_one(parent: Node2D, s: Dictionary, bush_sprites: Array) -> void:
	var sp := Sprite2D.new()
	sp.name = "Occ_" + String(s.file).get_file().get_basename()
	sp.texture = load(DIR + String(s.file)) as Texture2D
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.centered = false
	sp.position = Vector2(s.foot[0], s.foot[1])
	sp.offset = Vector2(float(s.x) - float(s.foot[0]), float(s.y) - float(s.foot[1]))
	if _sky != null and String(s.kind) in SWAY_KINDS:
		sp.texture = SkyCycle.padded(sp.texture)
		sp.offset.x -= float(SkyCycle.SWAY_PAD)
		sp.material = _sky.sway_material
		if s.has("nrm"):
			sp.material = _sky.prop_material(true, SkyCycle.padded(load(DIR + String(s.nrm)) as Texture2D))
	elif _sky != null:
		sp.material = _sky.rim_material
		if s.has("nrm"):
			sp.material = _sky.prop_material(false, load(DIR + String(s.nrm)) as Texture2D)
	parent.add_child(sp)
	if _shadows != null:
		_shadows.add_caster(sp, String(s.kind), Vector2(float(s.w), float(s.h)))
	if _sky != null and String(s.kind) == "lantern":
		_sky.add_light(Vector2(float(s.x) + float(s.w) * 0.5, float(s.y) + float(s.h) * 0.3),
				_sky.light_config().pool_shrine_radius * 0.7, 0.9)
	if String(s.kind) == "bush":
		bush_sprites.append(sp)
