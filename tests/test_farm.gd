extends RefCounted
## The Larkmoor farm (world/farm/): the manifest and its sprites agree, every item is inside the Larkmoor canvas and
## the farm box, no two items overlap, the fences stay in the canvas, the fields step through their gust frames (and
## hold still under Reduce Motion), and the spawn stays inside the node budget. Pure functions and detached nodes:
## no autoloads, no scene tree.

const CANVAS: Vector2 = Vector2(3040.0, 1840.0)
const BOX_CENTRE: Vector2 = Vector2(1090.0, 520.0)     # layout texels, doubled for the canvas
const BOX_SIZE: Vector2 = Vector2(260.0, 220.0)
const SCALE: float = 2.0
const NODE_BUDGET: int = 40                            # the farm's own nodes: sprites, the animator, fences


func run(t: Object) -> void:
	var data: Dictionary = FarmProps.load_manifest()
	t.ok(not data.is_empty(), "the farm manifest loads")
	var items: Array = data.get("items", []) as Array
	t.ok(items.size() >= 12, "the farm places at least 12 items (%d)" % items.size())
	var kinds: Dictionary = {}
	var rects: Array[Rect2] = []
	var box := Rect2((BOX_CENTRE - BOX_SIZE * 0.5) * SCALE, BOX_SIZE * SCALE)
	for v: Variant in items:
		var item: Dictionary = v as Dictionary
		var kind: String = str(item.get("kind", ""))
		kinds[kind] = true
		var rect := Rect2(float(item.x), float(item.y), float(item.w), float(item.h))
		rects.append(rect)
		t.ok(Rect2(Vector2.ZERO, CANVAS).encloses(rect), "%s at %s is inside the Larkmoor canvas" % [kind, rect.position])
		t.ok(box.encloses(rect), "%s at %s is inside the farm box" % [kind, rect.position])
		var fa: Array = item.foot as Array
		t.ok(float(fa[1]) <= rect.end.y + 0.01 and float(fa[1]) >= rect.position.y, "%s stands inside its own box" % kind)
		var tex: Texture2D = load(FarmProps.DIR + str(item.file)) as Texture2D
		t.ok(tex != null, "%s sprite %s loads" % [kind, str(item.file)])
		if tex == null:
			continue
		if kind.begins_with(FarmProps.FIELD_PREFIX):
			var fw: int = int(item.get("frame_w", 0))
			t.eq(tex.get_width(), fw * FarmProps.FIELD_FRAMES, "%s sheet holds %d frames" % [kind, FarmProps.FIELD_FRAMES])
			t.eq(tex.get_height(), FarmProps.FIELD_FRAME_H, "%s sheet is one row of frames" % kind)
			t.eq(int(rect.size.x), fw, "%s is one frame wide" % kind)
		else:
			t.eq(tex.get_width(), int(rect.size.x), "%s sprite width matches its box" % kind)
			t.eq(tex.get_height(), int(rect.size.y), "%s sprite height matches its box" % kind)
	for kind: String in ["farm_field_a", "farm_field_b", "farm_barn", "farm_scarecrow", "farm_plot_a"]:
		t.ok(kinds.has(kind), "the farm includes %s" % kind)
	# No two items share a texel: the placer keeps a gap, so a strict overlap is a placer bug.
	var overlaps: int = 0
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			if rects[i].intersects(rects[j]):
				overlaps += 1
	t.eq(overlaps, 0, "no two farm items overlap")
	var runs: Array = data.get("fences", []) as Array
	t.ok(runs.size() >= 2, "the farm has at least two fence runs (%d)" % runs.size())
	for r: Variant in runs:
		var pts: Array = r as Array
		t.ok(pts.size() >= 2, "a fence run has at least two points")
		for p: Variant in pts:
			var a: Array = p as Array
			var q := Vector2(float(a[0]), float(a[1]))
			t.ok(q.x >= 0.0 and q.y >= 0.0 and q.x <= CANVAS.x and q.y <= CANVAS.y, "a fence point is inside the canvas")
			t.ok(box.grow(12.0).has_point(q), "a fence point is inside the farm box (with a small margin)")
	# Phases: the two fields must not sway in step.
	var phases: Array[int] = []
	for v: Variant in items:
		var item: Dictionary = v as Dictionary
		if str(item.kind).begins_with(FarmProps.FIELD_PREFIX):
			phases.append(int(item.get("phase", 0)))
	t.ok(phases.size() >= 6, "the farm has at least six fields (%d)" % phases.size())
	# The water channel: at least a few ripples long, inside the box, and not running through any item.
	var channels: Array = data.get("brooks", []) as Array
	t.ok(channels.size() == 1, "the farm has one water channel")
	if not channels.is_empty():
		var cpts: Array = (channels[0] as Dictionary).get("points", []) as Array
		t.ok(cpts.size() >= 8, "the channel has at least 8 points (%d)" % cpts.size())
		var through: int = 0
		for p: Variant in cpts:
			var a: Array = p as Array
			var q := Vector2(float(a[0]), float(a[1]))
			t.ok(box.has_point(q), "a channel point is inside the farm box")
			for r: Rect2 in rects:
				if r.has_point(q):
					through += 1
		t.eq(through, 0, "the channel does not run through any farm item")
	t.ok(phases.size() >= 2, "the farm has at least two fields")
	if phases.size() >= 2:
		t.ok(phases[0] != phases[1], "neighbouring fields start their gust wave at different frames")

	# Spawn with no sky or shadows (a detached parent): counts, and the fields are animated sheets.
	var parent := Node2D.new()
	FarmProps.spawn(parent, null, null, null, data)
	var sprites: int = 0
	var animated: int = 0
	var fences: int = 0
	var channel_nodes: int = 0
	for c: Node in parent.get_children():
		if c is Sprite2D:
			sprites += 1
			if (c as Sprite2D).region_enabled:
				animated += 1
		elif c is FarmFences:
			fences += 1
		elif c is CozyBrook:
			channel_nodes += 1
	t.eq(sprites, items.size(), "the farm spawns one sprite per item")
	t.eq(animated, phases.size(), "every field is an animated sheet")
	t.eq(fences, 1, "the fences spawn as one node")
	t.eq(channel_nodes, 1, "the channel spawns as one node")
	t.ok(parent.get_child_count() <= NODE_BUDGET, "the farm adds at most %d nodes (%d)" % [NODE_BUDGET, parent.get_child_count()])
	parent.free()

	# Gust frames: a field steps through all its frames, and holds still under Reduce Motion.
	var seen: Dictionary = {}
	for step in range(0, 64):
		seen[CozyAnimator.frame_at(step, FarmProps.FIELD_FRAMES, 0, FarmProps.FIELD_RATE, false)] = true
	t.eq(seen.size(), FarmProps.FIELD_FRAMES, "a field's gust wave visits all %d frames" % FarmProps.FIELD_FRAMES)
	t.eq(CozyAnimator.frame_at(9, FarmProps.FIELD_FRAMES, 0, FarmProps.FIELD_RATE, true), 0, "a field holds still under Reduce Motion")
