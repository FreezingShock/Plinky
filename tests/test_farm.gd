extends RefCounted
## The Larkmoor farm (world/farm/): the manifest and its sprites agree, every item is inside the Larkmoor canvas and the
## farm box, no two items overlap (soil is a decal under the wheat), the wheat clumps are generated, baked and drawn from their seeds, the wheat gusts on
## the life clock and holds still under Reduce Motion, the walker's push springs back, and the spawn stays inside the
## node budget. Pure functions and detached nodes: no autoloads, no scene tree.

const CANVAS: Vector2 = Vector2(3040.0, 1840.0)
const BOX_CENTRE: Vector2 = Vector2(1090.0, 520.0)     # layout texels, doubled for the canvas
const BOX_SIZE: Vector2 = Vector2(260.0, 220.0)
const SCALE: float = 2.0
const FENCE_PREFIX: String = "farm_fence"                # the fence ring's pieces (see place_farm.py)
const WHEAT_PREFIX: String = "farm_wheat"                # the wheat clumps, which overlap a little (see place_farm.py)
const SOIL_PREFIX: String = "farm_soil"                  # the tilled soil decals: ground, drawn behind everything
const NODE_BUDGET: int = 120                           # the farm's own nodes: one sprite per item, plus the driver


func run(t: Object) -> void:
	var data: Dictionary = FarmProps.load_manifest()
	t.ok(not data.is_empty(), "the farm manifest loads")
	var items: Array = data.get("items", []) as Array
	t.ok(items.size() >= 12, "the farm places at least 12 items (%d)" % items.size())
	var kinds: Dictionary = {}
	var rects: Array[Rect2] = []
	var rect_kinds: Array[String] = []
	var box := Rect2((BOX_CENTRE - BOX_SIZE * 0.5) * SCALE, BOX_SIZE * SCALE)
	var wheat: int = 0
	var soil: int = 0
	var sprouts: int = 0
	for v: Variant in items:
		var item: Dictionary = v as Dictionary
		var kind: String = str(item.get("kind", ""))
		kinds[kind] = true
		var rect := Rect2(float(item.x), float(item.y), float(item.w), float(item.h))
		if kind == "farm_fence":
			# The ring is one sprite, so overlap is checked piece by piece: each piece's own box, from the manifest.
			for v2: Variant in item.get("pieces", []) as Array:
				var piece: Dictionary = v2 as Dictionary
				rects.append(Rect2(float(piece.x), float(piece.y), float(piece.w), float(piece.h)))
				rect_kinds.append(FENCE_PREFIX + "_piece")
		else:
			rects.append(rect)
			rect_kinds.append(kind)
		t.ok(Rect2(Vector2.ZERO, CANVAS).encloses(rect), "%s at %s is inside the Larkmoor canvas" % [kind, rect.position])
		t.ok(box.encloses(rect), "%s at %s is inside the farm box" % [kind, rect.position])
		var fa: Array = item.foot as Array
		t.ok(float(fa[1]) <= rect.end.y + 0.01 and float(fa[1]) >= rect.position.y, "%s stands inside its own box" % kind)
		var tex: Texture2D = load(FarmProps.DIR + str(item.file)) as Texture2D
		t.ok(tex != null, "%s sprite %s loads" % [kind, str(item.file)])
		if tex == null:
			continue
		if FarmProps.is_field(kind):
			wheat += 1
			var w: int = int(item.w)
			var h: int = int(item.h)
			t.eq(tex.get_width(), w * WheatClump.FRAMES, "%s sheet holds %d frames" % [kind, WheatClump.FRAMES])
			t.eq(tex.get_height(), h, "%s sheet is one row of frames" % kind)
			t.ok(int(item.get("stage", -1)) in [0, 1, 2], "%s has a growth stage" % kind)
			if int(item.get("stage", -1)) == WheatClump.STAGE_SPROUT:
				sprouts += 1
		else:
			if FarmProps.is_soil(kind):
				soil += 1
			t.eq(tex.get_width(), int(rect.size.x), "%s sprite width matches its box" % kind)
			t.eq(tex.get_height(), int(rect.size.y), "%s sprite height matches its box" % kind)
	t.ok(wheat >= 10, "the farm has at least 10 wheat clumps (%d)" % wheat)
	t.ok(soil >= 3, "the farm has at least 3 soil decals, one under each field (%d)" % soil)
	t.eq(sprouts, 0, "the wheat has no green sprouts")
	t.ok(not FarmProps.casts_shadow("farm_fence"), "the fence ring casts no shadow (it is one sprite over its whole box)")
	t.ok(not FarmProps.casts_shadow("farm_soil_61"), "soil casts no shadow (it is flat on the ground)")
	t.ok(not FarmProps.is_soil("farm_barn") and FarmProps.is_soil("farm_soil_61"), "only soil kinds count as soil")
	t.ok(kinds.has("farm_fence"), "the fence ring is one batched item")
	for kind: String in ["farm_barn", "farm_scarecrow", "farm_cart"]:
		t.ok(kinds.has(kind), "the farm includes %s" % kind)
	# No two items share a texel: the placer keeps a gap, so a strict overlap is a placer bug. Two exceptions. Fence pieces
	# meet end to end at their posts, and wheat clumps overlap a little so the patches read thick. Both are by design.
	var overlaps: int = 0
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			if not rects[i].intersects(rects[j]):
				continue
			if rect_kinds[i].begins_with(FENCE_PREFIX) and rect_kinds[j].begins_with(FENCE_PREFIX):
				continue
			if rect_kinds[i].begins_with(WHEAT_PREFIX) and rect_kinds[j].begins_with(WHEAT_PREFIX):
				continue
			if rect_kinds[i].begins_with(SOIL_PREFIX) or rect_kinds[j].begins_with(SOIL_PREFIX):
				continue            # a soil decal lies under the wheat and is masked round the buildings in the sprite itself
			overlaps += 1
	t.eq(overlaps, 0, "no two farm items overlap, except fence pieces meeting, wheat clumps overlapping, and soil under all")
	# The water channel: at least a few ripples long, inside the box.
	var channels: Array = data.get("brooks", []) as Array
	t.ok(channels.size() == 1, "the farm has one water channel")
	if not channels.is_empty():
		var cpts: Array = (channels[0] as Dictionary).get("points", []) as Array
		t.ok(cpts.size() >= 8, "the channel has at least 8 points (%d)" % cpts.size())
	# Clumps are generated from a seed: the same seed gives the same clump, and another seed a different one.
	var a: Dictionary = WheatClump.generate(5001, 48, 40, WheatClump.STAGE_GOLD)
	var b: Dictionary = WheatClump.generate(5001, 48, 40, WheatClump.STAGE_GOLD)
	var c: Dictionary = WheatClump.generate(5002, 48, 40, WheatClump.STAGE_GOLD)
	t.ok((a.stalks as Array).size() > 20, "a golden clump has a full set of stalks (%d)" % (a.stalks as Array).size())
	t.eq(float((a.stalks as Array)[0].bx), float((b.stalks as Array)[0].bx), "the same seed draws the same clump")
	t.ok(float((a.stalks as Array)[0].bx) != float((c.stalks as Array)[0].bx) or (a.stalks as Array).size() != (c.stalks as Array).size(), "another seed draws a different clump")
	# Drawing: a plain frame is the same pixels as the baked sheet's frame, the walker's push moves stalks, and each
	# stalk gets its own shading (a dark root and a golden body).
	var sheet: Image = WheatClump.bake_sheet(a)
	var plain: Image = WheatClump.rasterize(a, 3, Vector2.ZERO, 0.0, 0.0)
	t.eq(sheet.get_size(), Vector2i(48 * WheatClump.FRAMES, 40), "the baked sheet is %d frames of 48 x 40" % WheatClump.FRAMES)
	t.ok(sheet.get_region(Rect2i(3 * 48, 0, 48, 40)).get_data() == plain.get_data(), "a baked frame matches a plain draw")
	var pushed: Image = WheatClump.rasterize(a, 3, Vector2(24.0, 36.0), 6.0, 26.0)
	t.ok(pushed.get_data() != plain.get_data(), "the walker's push moves the stalks")
	# The silhouette cut: wheat in front of the walker is cut below his chest, so fewer tips reach the rows he stands in.
	var near_walker: Image = WheatClump.rasterize(a, 3, Vector2(24.0, 18.0), 6.0, 26.0)
	var far_walker: Image = WheatClump.rasterize(a, 3, Vector2(-200.0, 18.0), 6.0, 26.0)
	var tips_near: int = 0
	var tips_far: int = 0
	for y: int in range(0, 8):
		for x: int in range(15, 34):
			if near_walker.get_pixel(x, y).a > 0.0:
				tips_near += 1
			if far_walker.get_pixel(x, y).a > 0.0:
				tips_far += 1
	t.ok(tips_near < tips_far, "wheat in front of the walker is cut so it does not cover him (%d tips beside him, %d away)" % [tips_near, tips_far])
	var has_root: bool = false
	var has_body: bool = false
	for y: int in range(40):
		for x: int in range(48):
			var px: Color = plain.get_pixel(x, y)
			if px.is_equal_approx(WheatClump.PAL[WheatClump.C_SHADE]):
				has_root = true
			if px.is_equal_approx(WheatClump.PAL[WheatClump.C_GOLD_HI]):
				has_body = true
	t.ok(has_root and has_body, "each stalk has a dark root and a gold head")
	# Gust: a field steps through all its frames, and holds still under Reduce Motion.
	var seen: Dictionary = {}
	for step in range(0, 64):
		seen[CozyAnimator.frame_at(step, WheatClump.FRAMES, 0, FarmWheat.FIELD_RATE, false)] = true
	t.eq(seen.size(), WheatClump.FRAMES, "a clump's gust wave visits all %d frames" % WheatClump.FRAMES)
	t.eq(CozyAnimator.frame_at(9, WheatClump.FRAMES, 0, FarmWheat.FIELD_RATE, true), 0, "a clump holds still under Reduce Motion")
	# The push point springs onto the walker, overshoots once, and rests.
	var at := Vector2(0.0, 0.0)
	var vel := Vector2.ZERO
	var target := Vector2(40.0, 0.0)
	var overshoot: bool = false
	for i in range(180):
		var st: Array = FarmWheat.spring_step(at, vel, target, 1.0 / 60.0)
		at = st[0] as Vector2
		vel = st[1] as Vector2
		if at.x > target.x + 0.5:
			overshoot = true
	t.ok(at.distance_to(target) < 0.05, "the push point settles on the walker (%.3f off)" % at.distance_to(target))
	t.ok(overshoot, "the push point overshoots once, for a soft spring-back")
	t.eq(FarmWheat.push_for(true), 0.0, "the wheat does not part under Reduce Motion")
	t.ok(FarmWheat.push_for(false) > 0.0, "the wheat parts when the walker is near")
	# The farm spawns detached: one sprite per item, one driver, the channel, and no more than the node budget.
	var parent := Node2D.new()
	FarmProps.spawn(parent, null, null, null, data)
	var sprites: int = 0
	var clumps_animated: int = 0
	var driver: int = 0
	var channel_nodes: int = 0
	for n: Node in parent.get_children():
		if n is Sprite2D:
			sprites += 1
			if (n as Sprite2D).region_enabled:
				clumps_animated += 1
		elif n is FarmWheat:
			driver += 1
		elif n is CozyBrook:
			channel_nodes += 1
	t.eq(sprites, items.size(), "the farm spawns one sprite per item")
	t.eq(clumps_animated, wheat, "every wheat clump is an animated sheet")
	t.eq(driver, 1, "one wheat driver drives the clumps")
	t.eq(channel_nodes, 1, "the channel spawns as one node")
	t.ok(parent.get_child_count() <= NODE_BUDGET, "the farm adds at most %d nodes (%d)" % [NODE_BUDGET, parent.get_child_count()])
	parent.free()
