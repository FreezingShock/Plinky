extends Node2D
## Zone 1 meadow, 3D-rendered pixel art (tools/art/gen_meadow3d.py). One ground backdrop with bleed beyond the
## 640x360 frame, tall props (trees, big rocks, crystals, bushes) as separate sprites with a foot anchor, and
## Marker2D anchors for the things the game draws itself. All coordinates are in the 640x360 texel frame.
const DIR: String = "res://assets/art/zone1/meadow3d/"
const FAR_BACKDROP: Texture2D = preload("res://assets/art/zone1/meadow3d/backdrop_far.png")
const GROUND_FG: Texture2D = preload("res://assets/art/zone1/meadow3d/ground_fg.png")
const GROUND: Texture2D = preload("res://assets/art/zone1/meadow3d/ground.png")
const CLEARING_GARDEN_PATH: String = "res://world/clearing_gardens.json"
@export_file("*.json") var placements_path: String = DIR + "placements3d.json"

## Prop kinds that sway in the wind (world/sky_cycle.gd). Rocks and crystals stay put.
## Cast shadow of a pad slab: width in texels and the height it stretches from (the slab is about 3 texels thick).
## The slab is 3 texels thick and 28 wide: its shadow is short and as wide as the slab, in the global sun direction.
const PAD_SHADOW: Vector2 = Vector2(22.0, 4.0)
const SWAY_KINDS: PackedStringArray = ["oak", "pine", "bush"]

var _data: Dictionary = {}
var react: LifeReact
var _sky: SkyCycle
var _shadows: SkyShadows
var _ground: Sprite2D
## Material for the pad plates (main.gd assigns it): they take the same cast shadows as the ground.
var pad_material: ShaderMaterial
var _garden_flowers: Array = []   # the flower list the clearing's gardens were drawn from (world/clearing_gardens.json)
var _flower_glow: FlowerGlow      # the night light on each field's flowers (world/flower_glow.gd)


func _ready() -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string(placements_path))
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
			"player_spawn":
				m.name = "Walker"
			"shrine":
				m.name = "Shrine"
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


## The Starting Clearing's flower fields: the Sprout and Clover rows each sit in a field of their own statistic's flower.
## One node draws them all (world/garden_layer.gd); tools/art/gen_clearing_gardens.py writes the flowers.
func _add_gardens() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CLEARING_GARDEN_PATH))
	if not parsed is Dictionary:
		return
	var layer := GardenLayer.new()
	layer.name = "Gardens"
	add_child(layer)
	_garden_flowers = (parsed as Dictionary).get("flowers", []) as Array
	layer.setup(_garden_flowers)
	layer.pusher_group = &"walker"


## World life (world/meadow_life.gd): grass sway on the ground, fireflies and friends over everything.
## world/meadow_life.json is generated from this backdrop by tools/art/gen_life_anchors.py (see its usage).
func _add_life(ground: Sprite2D) -> void:
	var life: Dictionary = MeadowLife.load_data()
	if life.is_empty():
		return
	# Interactive blades replace the 120 baked sway tips on this meadow: every blade bends with the wind and the walker.
	var blades := GrassBlades.new()
	blades.name = "GrassBlades"
	add_child(blades)  # after Ground, so the blades draw over the grass
	blades.setup(ground, life.get("pads", []) as Array, Palettes.colors(Palettes.MEADOW))
	var air := LifeAir.new()
	air.name = "LifeAir"
	air.z_index = 10  # above the walker and pads, which sit at z 0 in World
	add_child(air)
	air.setup(life, ground)
	blades.critter_source = air.ground_pushers
	react = LifeReact.new()
	react.name = "LifeReact"
	react.z_index = 10
	add_child(react)
	react.setup(life, life.get("sway", []) as Array)



## Day/night shade, rain and wind (world/sky_cycle.gd). Added after the life layers; its own z indices place it.
func _add_sky() -> void:
	_shadows = SkyShadows.new()
	_shadows.name = "Shadows"
	add_child(_shadows)   # at z 0, after the ground and grass: above them, below every prop and the walker
	_sky = SkyCycle.new()
	_sky.name = "Sky"
	_sky.shadows = _shadows
	_sky.ground_texture = GROUND   # haze and mist read the full picture, not the cut-out
	_ground.material = _sky.ground_material(load(DIR + "ground_n.png") as Texture2D, load(DIR + "ground_h.png") as Texture2D)
	pad_material = _sky.pad_material(load(DIR + "ground_h.png") as Texture2D, _ground.position)
	var water: Array = []
	for a: Dictionary in _data.anchors:
		if String(a.kind) == "water":
			water.append(Vector4(float(a.sx), float(a.sy), float(a.rx), float(a.ry)))
	_sky.ponds = water
	add_child(_sky)
	_add_flower_glow()
	var water_glow := WaterNightGlow.new()   # night glow on the pond and lake (world/water_night_glow.gd)
	_sky.add_child(water_glow)               # after the shade and the light grade, so it adds on top of the night
	water_glow.setup(_sky, load(DIR + "ground_n.png") as Texture2D, _ground.position)
	_add_lights()


## The night light on the clearing's flower fields (world/flower_glow.gd), built from the same flower list the
## GardenLayer draws. Sits just above the night shade (z 5 of the sky), as on Larkmoor.
func _add_flower_glow() -> void:
	if not FlowerGlow.enabled or _garden_flowers.is_empty():
		return
	_flower_glow = FlowerGlow.new()
	_flower_glow.name = "FlowerGlow"
	_flower_glow.z_index = 5
	add_child(_flower_glow)
	_flower_glow.setup(_garden_flowers, FlowerGlow.pad_centres(_data.anchors))


## The night level comes from the sky every frame; the glow only changes its alpha, so nothing is redrawn.
func _process(_delta: float) -> void:
	if _flower_glow != null and _sky != null:
		_flower_glow.set_night(_sky.night01)


## Light pools (radii and strength in content/config/sky.tres): the shrine and any lantern in the life data,
## the gate, the pads, and a small one around the walker. Pools only show against the night shade and dusk.
func _add_lights() -> void:
	var cfg: SkyConfig = _sky.light_config()
	var life: Dictionary = MeadowLife.load_data()
	for L: Variant in life.get("lights", []) as Array:
		var d: Dictionary = L as Dictionary
		# a lantern pool is kind lantern, so it stays off by day and comes up with the night, as on Larkmoor
		var kind: StringName = &"lantern" if String(d.get("kind", "")) == "lantern" else &"fixed"
		_sky.add_light(Vector2(float(d.x), float(d.y)), cfg.pool_shrine_radius, 1.0, kind)
	for a: Dictionary in _data.anchors:
		match String(a.kind):
			"gate":
				_sky.add_light(Vector2(a.sx, a.sy), cfg.pool_gate_radius, 0.8)
			"pad":
				_sky.add_light(Vector2(a.sx, a.sy), cfg.pool_pad_radius, 0.45, &"pad")
				_shadows.add_pad(Vector2(a.sx, a.sy).round())   # before the casters, so their shadows get a copy above the plate
				_shadows.add_blob(Vector2(a.sx, a.sy), PAD_SHADOW.x, PAD_SHADOW.y)
	_sky.add_light(Vector2.ZERO, cfg.pool_walker_radius, 0.7, &"walker")


## Adds each tall prop as its own sprite under `parent`, which must have y_sort_enabled. The sprite sits at the
## prop's foot, so anything south of the foot draws over it and anything behind it is covered by it.
func spawn_occluders(parent: Node2D) -> void:
	var bush_sprites: Array = []
	for s: Dictionary in _data.sprites:
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
		if String(s.kind) == "bush":
			bush_sprites.append(sp)
	if react != null:
		react.set_bushes(bush_sprites)
	# Cozy layer (world/cozy/): benches, swings, a cottage, wheat, a brook and firefly swarms, from its own manifest.
	if _sky != null and _shadows != null:
		CozyProps.spawn(parent, _sky, _shadows, _sky.rim_material, _data.anchors)
