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
