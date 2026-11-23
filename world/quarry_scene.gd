extends Node2D
## The Ember Quarry (tools/art/gen_quarry.py). Same contract as larkmoor_scene.gd: one 1400x760 ground canvas at (0, 0)
## (texel coordinates are canvas pixels), front-facing props as y-sorted sprites, and Marker2D anchors (Pad0.., Gate,
## Arch, Walker, Vent0.., Lava0..). Heat vents are read by HeatVents; lava flows and glows through LavaFlow and the
## ember layer. main.gd reads world_rect, mask_offset and the two paths to frame the zone.
const DIR: String = "res://assets/art/zone2/quarry/"
const GROUND: Texture2D = preload("res://assets/art/zone2/quarry/ground.png")

## Read by main.gd so footsteps and ambience look up this zone's ground, not the meadow's (world/meadow_sites.gd).
var placements_path: String = DIR + "placements3d.json"
var ground_path: String = DIR + "ground.png"
var world_rect: Rect2 = Rect2(40.0, 10.0, 1320.0, 740.0)   ## the area the camera and walker stay in
var mask_offset: Vector2i = Vector2i.ZERO                  ## walkable.png and ground.png are canvas sized

var _data: Dictionary = {}


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
	var embers := LifeEmbers.new()   # embers off the vents, drifting ash (world/life_embers.gd)
	embers.name = "LifeEmbers"
	embers.z_index = 10
	embers.area = world_rect
	add_child(embers)
	embers.setup(anchors)


## Same as the meadow: each tall prop is a sprite at its foot, so the walker sorts behind or in front of it.
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
