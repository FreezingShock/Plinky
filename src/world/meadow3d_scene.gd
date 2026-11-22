extends Node2D
## Zone 1 meadow, 3D-rendered pixel art. Ground is one backdrop; trees, big rocks, crystals and bushes are
## separate sprites with a foot anchor, y-sorted under `Actors` so the player can walk behind them.
## Drop the player under `Actors` (its position must be its foot). Data: assets/art/zone1/meadow3d/placements3d.json
## Anchors (pads, gate, shrine, player_spawn) are positions only; the game draws those itself.
const DIR := "res://assets/art/zone1/meadow3d/"
@onready var actors: Node2D = $Actors

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "placements3d.json"))
	for s in data.sprites:
		var foot := Node2D.new()
		foot.position = Vector2(s.foot[0], s.foot[1])
		var sp := Sprite2D.new()
		sp.centered = false
		sp.texture = load(DIR + s.file)
		sp.position = Vector2(s.x - s.foot[0], s.y - s.foot[1])
		foot.add_child(sp)
		actors.add_child(foot)
	for a in data.anchors:
		var m := Marker2D.new()
		m.name = "%s_%d" % [a.kind, $Anchors.get_child_count()]
		m.position = Vector2(a.sx, a.sy)
		if a.has("state"): m.set_meta("state", a.state)
		$Anchors.add_child(m)
