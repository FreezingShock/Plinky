extends Node2D
## Zone 1 meadow, 3D-rendered pixel art (tools/art/gen_meadow3d.py). One ground backdrop with bleed beyond the
## 640x360 frame, tall props (trees, big rocks, crystals, bushes) as separate sprites with a foot anchor, and
## Marker2D anchors for the things the game draws itself. All coordinates are in the 640x360 texel frame.
const DIR: String = "res://assets/art/zone1/meadow3d/"
const GROUND: Texture2D = preload("res://assets/art/zone1/meadow3d/ground.png")
@export_file("*.json") var placements_path: String = DIR + "placements3d.json"

var _data: Dictionary = {}


func _ready() -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string(placements_path))
	var bleed: Dictionary = _data.bleed
	var ground := Sprite2D.new()
	ground.name = "Ground"
	ground.texture = GROUND
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
	_add_life(ground)


## World life (world/meadow_life.gd): grass sway on the ground, fireflies and friends over everything.
## world/meadow_life.json is generated from this backdrop by tools/art/gen_life_anchors.py (see its usage).
func _add_life(ground: Sprite2D) -> void:
	var life: Dictionary = MeadowLife.load_data()
	if life.is_empty():
		return
	var lg := LifeGround.new()
	lg.name = "LifeGround"
	add_child(lg)  # after Ground, so the sway draws over the grass
	lg.setup(ground, life.get("sway", []) as Array)
	var air := LifeAir.new()
	air.name = "LifeAir"
	air.z_index = 10  # above the walker and pads, which sit at z 0 in World
	add_child(air)
	air.setup(life, ground)


## Adds each tall prop as its own sprite under `parent`, which must have y_sort_enabled. The sprite sits at the
## prop's foot, so anything south of the foot draws over it and anything behind it is covered by it.
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
