extends Node
## Headless probe of tap-to-move routing in Larkmoor: the real TexelWalker is sent to every pad, from the spawn and from the
## previous pad, and must end on it. Run: godot --headless --path . tools/route_probe.tscn   Exits non-zero on a miss.

const DIR: String = "res://assets/art/zone1b/larkmoor/"
const REACH: float = 12.0


func bounds_rect() -> Rect2:
	return TexelWalker.bounds


func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "placements3d.json")) as Dictionary
	WalkMask.use(DIR + "walkable.png", Vector2i.ZERO)
	var world: Array = data.get("world", []) as Array
	TexelWalker.bounds = Rect2(float(world[0]), float(world[1]), float(world[2]), float(world[3]))
	var pads: Array[Vector2] = []
	var spawn: Vector2 = Vector2.ZERO
	for a: Dictionary in data.anchors:
		if String(a.kind) == "pad":
			pads.append(Vector2(float(a.sx), float(a.sy)))
		elif String(a.kind) == "player_spawn":
			spawn = Vector2(float(a.sx), float(a.sy))
	var parent := Node2D.new()
	add_child(parent)
	var w := TexelWalker.new()
	parent.add_child(w)
	await get_tree().process_frame
	var misses: int = 0
	var last: Vector2 = spawn
	var t0: int = Time.get_ticks_msec()
	for i in pads.size():
		for from: Vector2 in [spawn, last]:
			w.position = from
			w.go_to(pads[i])
			var frames: int = 0
			while w._has_target and frames < 30000:
				w._process(1.0 / 60.0)
				frames += 1
			var d: float = w.position.distance_to(pads[i])
			if d > REACH:
				misses += 1
				print("MISS pad %d from %s: stopped %.1f short after %d frames" % [i, str(from), d, frames])
		last = pads[i]
	# Every pad from every other pad, and from a scatter of open ground (the spots a player taps from).
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var starts: Array[Vector2] = pads.duplicate()
	var tries: int = 0
	while starts.size() < pads.size() + 12 and tries < 20000:
		tries += 1
		var q := Vector2(rng.randf_range(bounds_rect().position.x, bounds_rect().end.x), rng.randf_range(bounds_rect().position.y, bounds_rect().end.y))
		if WalkMask.walkable(q) and WalkMask.walkable(q + Vector2(0.0, 6.0)):
			starts.append(q)
	var cross: int = 0
	for i in pads.size():
		for from: Vector2 in starts:
			if from.distance_to(pads[i]) < 40.0:
				continue
			cross += 1
			w.position = from
			w.go_to(pads[i])
			var frames2: int = 0
			while w._has_target and frames2 < 30000:
				w._process(1.0 / 60.0)
				frames2 += 1
			var d2: float = w.position.distance_to(pads[i])
			if d2 > REACH:
				misses += 1
				print("MISS pad %d from %s: stopped %.1f short" % [i, str(from), d2])
	print("%d pads, %d extra routes, %d misses, %d ms" % [pads.size(), cross, misses, Time.get_ticks_msec() - t0])
	get_tree().quit(1 if misses > 0 else 0)
