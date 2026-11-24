extends RefCounted
## Tap-to-move routing (WalkMask.route): a tap on any Larkmoor pad has a route from the spawn that is clear step by step,
## and a clear straight walk is not detoured. (tools/route_probe.tscn drives the real walker over the same pads.)

const DIR: String = "res://assets/art/zone1b/larkmoor/"


func run(t: Object) -> void:
	WalkMask.use(DIR + "walkable.png", Vector2i.ZERO)
	t.ok(WalkMask.available(), "larkmoor walk mask loads")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "placements3d.json")) as Dictionary
	var spawn: Vector2 = Vector2.ZERO
	var pads: Array[Vector2] = []
	for a: Dictionary in data.anchors:
		if String(a.kind) == "pad":
			pads.append(Vector2(float(a.sx), float(a.sy)))
		elif String(a.kind) == "player_spawn":
			spawn = Vector2(float(a.sx), float(a.sy))
	t.ok(pads.size() > 0 and spawn != Vector2.ZERO, "pads and spawn found")
	var routed: int = 0
	var clear: int = 0
	var detours: int = 0
	for pad: Vector2 in pads:
		var goal: Vector2 = WalkMask.nearest_inset(pad)
		var r: PackedVector2Array = WalkMask.route(spawn, goal)
		if r.is_empty():
			continue
		routed += 1
		var prev: Vector2 = spawn
		var all_clear: bool = r[r.size() - 1] == goal
		for p: Vector2 in r:
			all_clear = all_clear and WalkMask.line_clear(prev, p)
			prev = p
		if all_clear:
			clear += 1
		if WalkMask.line_clear(spawn, goal) and r.size() != 1:
			detours += 1
	t.eq(routed, pads.size(), "every pad has a route from the spawn")
	t.eq(clear, pads.size(), "every route ends on its pad and is clear step by step")
	t.eq(detours, 0, "a clear straight walk is not detoured")
	# somewhere unreachable has no route (the open water in the corner), so the walker falls back to walking straight
	t.ok(WalkMask.route(spawn, Vector2(5.0, 5.0)).is_empty() or not WalkMask.walkable(Vector2(5.0, 5.0)), "open water gives no walkable route")
