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
## Reach of a cast shadow toward a pad (SkyShadows.pad_reach). 90 keeps the shadows that fall on pads and drops the
## overlay quads for casters far from every pad: 132 overlays at the default 220, 48 at 120, 28 at 90 (node ceiling).
const SHADOW_PAD_REACH: float = 90.0
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


## Shadows and the shade (world/sky_cycle.gd). The quarry is underground, so its light does not follow the clock: the
## sky holds at midday with no rain, no wind and no day or night shade. The lava, rocks and pads light the zone instead
## (QuarryLight). The HUD clock still reads the real time.
func _add_sky(ground_size: Array) -> void:
	_shadows = SkyShadows.new()
	_shadows.name = "Shadows"
	_shadows.pad_reach = SHADOW_PAD_REACH   # set before any caster: the quarry's pads sit far enough apart for a tighter reach
	add_child(_shadows)   # z 0, after the ground and lava: above them, below every prop and the walker
	_sky = SkyCycle.new()
	_sky.name = "Sky"
	_sky.area = Rect2(0.0, 0.0, float(ground_size[0]), float(ground_size[1]))
	_sky.shadows = _shadows
	_sky.ground_texture = GROUND
	_sky.atmosphere = false   # QuarryLight draws the haze instead
	_sky.seasonal = false     # a themed zone: no season tint or season particles
	_sky.underground = true   # the light holds at midday, whatever the clock says
	add_child(_sky)
	_add_lights()


## Light pools for the shade (SkyCycle holds 24 at most). Order decides what is dropped when full: the walker, the
## gate and arch, the lava and the vents come first, then braziers and lamps take what is left.
func _add_lights() -> void:
	var cfg: SkyConfig = _sky.light_config()
	_sky.add_light(Vector2.ZERO, cfg.pool_walker_radius, 0.7, &"walker")
	for a: Dictionary in _data.anchors:
		match String(a.kind):
			"gate":
				# the forge gate's own light: ember red-orange, so it reads as the portal's glow, not the warm default
				_sky.add_light(Vector2(a.sx, a.sy), cfg.pool_gate_radius, 0.8, &"fixed", Color(1.0, 0.42, 0.2, 1.0))
			"arch":
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
## front of it. Each prop takes its normal map (gen_quarry_normals.py) and the light of the sources near it, and casts a shadow.
func spawn_occluders(parent: Node2D) -> void:
	for s: Dictionary in _data.sprites:
		_spawn_prop(parent, s)


## Same props as spawn_occluders, a slice at a time: yields to the next frame once `budget_ms` of a frame is used up.
## A zone swap under the transition wipe uses it (main.gd), so the props do not stall the wipe's peak.
func spawn_occluders_sliced(parent: Node2D, budget_ms: float) -> void:
	var start_us: int = Time.get_ticks_usec()
	var work_us: int = 0   ## CPU spent on the props themselves, not on the frames in between
	for s: Dictionary in _data.sprites:
		var t0: int = Time.get_ticks_usec()
		_spawn_prop(parent, s)
		work_us += Time.get_ticks_usec() - t0
		if float(Time.get_ticks_usec() - start_us) / 1000.0 >= budget_ms:
			await get_tree().process_frame
			start_us = Time.get_ticks_usec()
	if PerfStats.tracing:
		PerfStats.trace.append("quarry props cpu %.1f ms" % (float(work_us) / 1000.0))


func _spawn_prop(parent: Node2D, s: Dictionary) -> void:
	var sp := Sprite2D.new()
	sp.name = "Occ_" + String(s.file).get_file().get_basename()
	sp.texture = ZoneAssets.texture(DIR + String(s.file))
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.centered = false
	sp.position = Vector2(s.foot[0], s.foot[1])
	sp.offset = Vector2(float(s.x) - float(s.foot[0]), float(s.y) - float(s.foot[1]))
	parent.add_child(sp)
	var nrm: Texture2D = ZoneAssets.texture(DIR + String(s.file).get_basename() + "_n.png")
	if _light != null and nrm != null:
		sp.material = _light.prop_material(Vector2(float(s.x), float(s.y)), Vector2(float(s.w), float(s.h)), nrm)
	elif _sky != null:
		sp.material = _sky.rim_material
	if _shadows != null:
		_shadows.add_caster(sp, String(s.kind), Vector2(float(s.w), float(s.h)))
