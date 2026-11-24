extends Node2D
## The Ember Quarry (tools/art/gen_quarry.py). Same contract as larkmoor_scene.gd: one 1400x760 ground canvas at (0, 0)
## (texel coordinates are canvas pixels), front-facing props as y-sorted sprites, and Marker2D anchors (Pad0.., Gate,
## Arch, Walker, Vent0.., Lava0..). Heat vents are read by HeatVents; lava flows through LavaFlow and the ember layer.
## Lighting: SkyCycle and SkyShadows give the time of day, the cast shadows and the light pools (as in Larkmoor), and
## QuarryLight adds the lava and brazier glow, the haze with light shafts and the heat shimmer (world/quarry_light.gd).
## main.gd reads world_rect, mask_offset and the two paths to frame the zone.
const DIR: String = "res://assets/art/zone2/quarry/"
const GROUND: Texture2D = preload("res://assets/art/zone2/quarry/ground.png")

const PAD_SHADOW: Vector2 = Vector2(22.0, 4.0)   ## the pad slab is 3 texels thick and 28 wide, as in Larkmoor

## Read by main.gd so footsteps and ambience look up this zone's ground, not the meadow's (world/meadow_sites.gd).
var placements_path: String = DIR + "placements3d.json"
var ground_path: String = DIR + "ground.png"
var world_rect: Rect2 = Rect2(40.0, 10.0, 1320.0, 740.0)   ## the area the camera and walker stay in
var mask_offset: Vector2i = Vector2i.ZERO                  ## walkable.png and ground.png are canvas sized

var _data: Dictionary = {}
var _sky: SkyCycle
var _shadows: SkyShadows
var _light: QuarryLight


func _ready() -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string(DIR + "placements3d.json"))
	var wr: Array = _data.get("world", []) as Array
	if wr.size() == 4:
		world_rect = Rect2(float(wr[0]), float(wr[1]), float(wr[2]), float(wr[3]))
	var bleed: Dictionary = _data.bleed
	var ground := Sprite2D.new()
	ground.name = "Ground"
	ground.texture = GROUND
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground.centered = false
	ground.position = Vector2(bleed.ground_offset[0], bleed.ground_offset[1])
	add_child(ground)
	var flow := LavaFlow.new()   # the lava's 6 frame loop, drawn over the baked first frame
	flow.name = "LavaFlow"
	add_child(flow)
	flow.setup(DIR, _data.get("lava", []) as Array)
	_add_sky(bleed.ground_size)
	var anchors := Node2D.new()
	anchors.name = "Anchors"
	add_child(anchors)
	var pad_i: int = 0
	var vent_i: int = 0
	var lava_i: int = 0
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
			"vent":
				m.name = "Vent%d" % vent_i
				m.set_meta("radius", float(a.radius))
				vent_i += 1
			"lava":
				m.name = "Lava%d" % lava_i
				lava_i += 1
			_:
				continue
		anchors.add_child(m)
	_light = QuarryLight.new()   # haze, lava glow and heat shimmer, over the props and under the embers
	_light.name = "QuarryLight"
	add_child(_light)
	var cols: PackedColorArray = Palettes.colors(Palettes.for_zone(&"zone2"))
	_light.setup(_data, Rect2(Vector2.ZERO, Vector2(float(bleed.ground_size[0]), float(bleed.ground_size[1]))),
			_sky, _sky.light_config(), cols)
	var embers := LifeEmbers.new()   # embers off the vents, drifting ash (world/life_embers.gd)
	embers.name = "LifeEmbers"
	embers.z_index = 10
	embers.area = world_rect
	add_child(embers)
	embers.setup(anchors)


## Shadows and the day and night shade (world/sky_cycle.gd). The quarry has no seasons and no mountain haze: the
## shade, the god rays at dawn and dusk, rain and the sun's cast shadows still follow the clock.
func _add_sky(ground_size: Array) -> void:
	_shadows = SkyShadows.new()
	_shadows.name = "Shadows"
	add_child(_shadows)   # z 0, after the ground and lava: above them, below every prop and the walker
	_sky = SkyCycle.new()
	_sky.name = "Sky"
	_sky.area = Rect2(0.0, 0.0, float(ground_size[0]), float(ground_size[1]))
	_sky.shadows = _shadows
	_sky.ground_texture = GROUND
	_sky.atmosphere = false   # QuarryLight draws the haze instead
	_sky.seasonal = false     # a themed zone: no season tint or season particles
	add_child(_sky)
	_add_lights()


## Light pools for the shade (SkyCycle holds 24 at most). Order decides what is dropped when full: the walker, the
## gate and arch, the lava and the vents come first, then braziers and lamps take what is left.
func _add_lights() -> void:
	var cfg: SkyConfig = _sky.light_config()
	_sky.add_light(Vector2.ZERO, cfg.pool_walker_radius, 0.7, &"walker")
	for a: Dictionary in _data.anchors:
		match String(a.kind):
			"gate", "arch":
				_sky.add_light(Vector2(a.sx, a.sy), cfg.pool_gate_radius, 0.8)
			"lava":
				_sky.add_light(Vector2(a.sx, a.sy), cfg.lava_pool_radius, 1.0)
			"vent":
				_sky.add_light(Vector2(a.sx, a.sy), cfg.lava_pool_radius * 0.6, 0.6)
			"pad":
				_shadows.add_pad(Vector2(a.sx, a.sy).round())   # before the casters, so their shadows get a copy above the plate
				_shadows.add_blob(Vector2(a.sx, a.sy), PAD_SHADOW.x, PAD_SHADOW.y)
	for s: Dictionary in _data.sprites:
		if String(s.kind) == "brazier" or String(s.kind) == "iron_lamp":
			_sky.add_light(Vector2(float(s.x) + float(s.w) * 0.5, float(s.y) + float(s.h) * 0.4),
					cfg.pool_shrine_radius * 0.7, 0.9)


## Spawns each tall prop as its own sprite under `parent`, which must be y-sorted, so the walker sorts behind or in
## front of it. Props have no normal map yet, so they take the rim material (sun rim only) and cast shadows.
func spawn_occluders(parent: Node2D) -> void:
	for s: Dictionary in _data.sprites:
		var sp := Sprite2D.new()
		sp.name = "Occ_" + String(s.file).get_file().get_basename()
		sp.texture = load(DIR + String(s.file)) as Texture2D
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.centered = false
		sp.position = Vector2(s.foot[0], s.foot[1])
		sp.offset = Vector2(float(s.x) - float(s.foot[0]), float(s.y) - float(s.foot[1]))
		parent.add_child(sp)
		if _sky != null:
			sp.material = _sky.rim_material
			_shadows.add_caster(sp, String(s.kind), Vector2(float(s.w), float(s.h)))
