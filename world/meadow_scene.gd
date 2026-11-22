extends Node2D
## Zone 1 meadow. Backdrop is the baked, y-sorted, off-grid composition from tools/art/gen_meadow.py
## (640x360 texels, nearest filter). Pads and gate come from meadow_placements.json as Marker2D
## anchors in texel space so gameplay nodes can attach without touching the art.
@export_file("*.json") var placements_path := "res://world/meadow_placements.json"

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(placements_path))
	var anchors := $Anchors
	var i := 0
	for p in data.pads:
		var m := Marker2D.new()
		m.name = "Pad%d" % i
		m.position = Vector2(p.x, p.y)
		m.set_meta("state", p.state)
		anchors.add_child(m)
		i += 1
	for p in data.props:
		if p.name == "gate" or p.name == "shrine" or p.name == "walker":
			var m := Marker2D.new()
			m.name = String(p.name).capitalize()
			m.position = Vector2(p.x, p.y)
			anchors.add_child(m)
	_add_life()


@export_file("*.json") var occluders_path := "res://world/meadow_occluders.json"
const OCCLUDER_TEXTURE: Texture2D = preload("res://assets/art/zone1/meadow_occluders.png")

## Adds each tall prop (trees, big rocks) as its own sprite under `parent`, which must have y_sort_enabled.
## The sprite sits at the prop's foot, so anything standing south of the foot draws over it and anything
## north of the foot (behind the prop) is covered by it. Pixels match the baked backdrop, so they are
## invisible until something walks behind them.
func spawn_occluders(parent: Node2D) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(occluders_path))
	for o in data.occluders:
		var rect: Array = o.rect
		var foot: Array = o.foot
		var sp := Sprite2D.new()
		sp.name = "Occ_" + String(o.name)
		sp.texture = OCCLUDER_TEXTURE
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.centered = false
		sp.region_enabled = true
		sp.region_rect = Rect2(rect[0], rect[1], rect[2], rect[3])
		sp.position = Vector2(foot[0], foot[1])
		sp.offset = Vector2(rect[0] - foot[0], rect[1] - foot[1])
		parent.add_child(sp)


## World life (see world/meadow_life.gd): grass sway on the ground, fireflies and friends over everything.
func _add_life() -> void:
	var life: Dictionary = MeadowLife.load_data()
	if life.is_empty():
		return
	var ground := LifeGround.new()
	ground.name = "LifeGround"
	add_child(ground)  # after Backdrop, so the sway draws over the baked grass
	ground.setup($Backdrop, life.get("sway", []) as Array)
	var air := LifeAir.new()
	air.name = "LifeAir"
	air.z_index = 10  # above the walker and pads, which sit at z 0 in World
	add_child(air)
	air.setup(life, $Backdrop)
