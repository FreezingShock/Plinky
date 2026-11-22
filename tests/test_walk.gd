extends RefCounted
## Walkable mask (world/walk_mask.gd) and how the walker respects it.

func run(t: Object) -> void:
	t.ok(WalkMask.available(), "walkable.png loads")
	if not WalkMask.available():
		return
	var im: Image = WalkMask.image()
	t.eq(im.get_size(), Vector2i(840, 480), "mask matches the ground frame")
	var data: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/zone1/meadow3d/placements3d.json")) as Dictionary)
	var spawn_ok: bool = false
	var water_blocked: int = 0
	for a: Variant in data.get("anchors", []):
		var d: Dictionary = a as Dictionary
		var kind: String = str(d.get("kind", ""))
		var p := Vector2(float(d.get("sx", 0)), float(d.get("sy", 0)))
		if kind == "pad" or kind == "gate" or kind == "player_spawn":
			var n: Vector2 = WalkMask.nearest(p, 12)
			t.ok(WalkMask.walkable(n) and p.distance_to(n) <= 12.0, "%s at %s is reachable within 12 texels" % [kind, str(p)])
		if kind == "player_spawn":
			spawn_ok = WalkMask.walkable(WalkMask.nearest(p, 12))
		if kind == "water":
			t.ok(not WalkMask.walkable(p), "water '%s' centre is not walkable" % str(d.get("name", "")))
			water_blocked += 1
	t.ok(spawn_ok, "spawn is walkable")
	t.ok(water_blocked >= 2, "lake and pond anchors checked")
	var open_px: int = 0
	for y in range(0, im.get_height(), 2):
		for x in range(0, im.get_width(), 2):
			if im.get_pixel(x, y).r > 0.5:
				open_px += 1
	var frac: float = float(open_px) / float(im.get_width() * im.get_height() / 4)
	t.ok(frac > 0.05 and frac < 0.4, "walkable fraction is sane (%.3f)" % frac)
	t.ok(not WalkMask.walkable(Vector2(-90, -50)), "far outside the island is blocked")
	var far: Vector2 = WalkMask.nearest(Vector2(-90, -50), 30)
	t.eq(far, Vector2(-90, -50), "nearest gives up past max_r")
	var lake: Vector2 = Vector2(412, 262)
	var snapped: Vector2 = WalkMask.nearest(lake)
	t.ok(WalkMask.walkable(snapped), "click in the lake snaps to land")
