extends RefCounted
## Cozy props (world/cozy/): the manifest and its sprites agree, every prop is on the island and in the frame, the
## wheat and the water wheel step through their frames, a swing hangs still under Reduce Motion, and the firefly
## swarms follow the dark and the season. Pure functions only: no autoloads, no scene tree.


func run(t: Object) -> void:
	var data: Dictionary = CozyLayout.load_manifest()
	t.ok(not data.is_empty(), "the cozy manifest loads")
	var items: Array = CozyLayout.items(data)
	t.ok(items.size() >= 15, "the manifest places at least 15 cozy props (%d)" % items.size())
	var seen: Dictionary = {}
	for v: Variant in items:
		var item: Dictionary = v as Dictionary
		var kind: String = str(item.get("kind", ""))
		var file: String = str(item.get("file", ""))
		var rect: Rect2 = CozyLayout.rect_of(item)
		seen[kind] = true
		t.ok(CozyLayout.is_known(kind), "%s is a known cozy kind" % kind)
		t.ok(CozyLayout.in_frame(rect), "%s at %s is inside the 640x360 frame" % [kind, rect.position])
		t.ok(CozyLayout.foot_of(item).y <= rect.end.y + 0.01, "%s stands inside its own box" % kind)
		var tex: Texture2D = load(CozyLayout.DIR + file) as Texture2D
		t.ok(tex != null, "%s sprite %s loads" % [kind, file])
		if tex == null:
			continue
		if kind == CozyLayout.WHEAT_KIND:
			t.eq(tex.get_width(), CozyLayout.WHEAT_FRAME_W * CozyLayout.WHEAT_FRAMES, "wheat sheet holds %d frames" % CozyLayout.WHEAT_FRAMES)
			t.eq(tex.get_height(), CozyLayout.WHEAT_FRAME_H, "wheat sheet is one row of frames")
		elif kind == CozyLayout.WHEEL_KIND:
			t.eq(tex.get_width(), CozyLayout.WHEEL_FRAME_W * CozyLayout.WHEEL_FRAMES, "wheel sheet holds %d frames" % CozyLayout.WHEEL_FRAMES)
		else:
			t.eq(tex.get_width(), int(item.get("w", -1)), "%s width matches its sprite" % kind)
			t.eq(tex.get_height(), int(item.get("h", -1)), "%s height matches its sprite" % kind)
	for k: String in ["cozy_cottage", "cozy_campfire_ring", "cozy_fountain_basin", "cozy_swing_frame", "cozy_wheat"]:
		t.ok(seen.has(k), "the layout places a %s" % k)
	var brooks: Array = CozyLayout.brooks(data)
	t.ok(not brooks.is_empty(), "the layout has a brook")
	for b: Variant in brooks:
		var pts: Array = (b as Dictionary).get("points", []) as Array
		var inside: bool = true
		for p: Variant in pts:
			var a: Array = p as Array
			inside = inside and float(a[0]) >= 0.0 and float(a[0]) < 640.0 and float(a[1]) >= 0.0 and float(a[1]) < 360.0
		t.ok(pts.size() >= 12 and inside, "a brook of %d points stays in the frame" % pts.size())

	# Frames: a sheet walks through every frame once per cycle, and neighbours are offset so a wave rolls.
	var seen_frames: Dictionary = {}
	for s: int in range(CozyLayout.WHEAT_FRAMES):
		seen_frames[CozyAnimator.frame_at(s, CozyLayout.WHEAT_FRAMES, 0, 1.0, false)] = true
	t.eq(seen_frames.size(), CozyLayout.WHEAT_FRAMES, "wheat steps through all %d frames" % CozyLayout.WHEAT_FRAMES)
	t.eq(CozyAnimator.frame_at(0, 8, 3, 1.0, false), 3, "a phase of 3 starts the sheet on frame 3")
	t.eq(CozyAnimator.frame_at(5, 8, 0, 1.0, true), 0, "Reduce Motion holds a sheet on its first frame")
	t.eq(CozyAnimator.frame_at(9, 1, 0, 1.0, false), 0, "a single frame never moves")
	t.eq(CozyAnimator.swing_angle(1.0, 0.0, 0.5, true), 0.0, "Reduce Motion hangs a swing still")
	var quarter: float = CozyAnimator.swing_angle(CozyAnimator.SWING_PERIOD * 0.25, 0.0, 1.0, false)
	t.near(quarter, CozyAnimator.SWING_AMP, 1e-4, "a swing reaches its full amplitude at full wind")
	var calm: float = CozyAnimator.swing_angle(CozyAnimator.SWING_PERIOD * 0.25, 0.0, 0.0, false)
	t.ok(calm > 0.0 and calm < quarter, "a calm day still swings, a little less (%.3f)" % calm)

	# Fireflies: out at dusk and in summer, none by day, in the rain or in winter.
	var summer: Array[float] = [0.0, 1.0, 0.0, 0.0]
	var winter: Array[float] = [0.0, 0.0, 0.0, 1.0]
	t.near(CozySwarm.share_for(1.0, 0.0, 0.0, summer), 1.0, 1e-6, "summer midnight: every swarm firefly is out")
	t.eq(CozySwarm.share_for(0.0, 0.0, 0.0, summer), 0.0, "noon: no swarm fireflies")
	t.eq(CozySwarm.share_for(1.0, 0.0, 1.0, summer), 0.0, "heavy rain: no swarm fireflies")
	t.eq(CozySwarm.share_for(1.0, 0.0, 0.0, winter), 0.0, "winter: no swarm fireflies")
	var dusk: float = CozySwarm.share_for(0.0, 1.0, 0.0, summer)
	t.ok(dusk > 0.0 and dusk < 1.0, "golden hour brings some of them out (%.2f)" % dusk)
	t.ok(CozySwarm.count_for(1.0) <= CozySwarm.TOTAL, "the swarm never draws more than its total")
	t.eq(CozySwarm.count_for(0.0), 0, "no swarm fireflies by day")
	var centres: PackedVector2Array = CozySwarm.centres_for([{"sx": 415.0, "sy": 258.0, "rx": 66.0, "ry": 44.0}, {"sx": 197.0, "sy": 202.5, "rx": 24.0, "ry": 16.0}], [Vector2(100.0, 100.0)])
	t.eq(centres.size(), 6 + 4 + 1, "swarms gather at the lake (6 shore spots), the pond (4) and each wheat patch")
