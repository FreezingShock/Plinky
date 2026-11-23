extends RefCounted
## Footstep surfaces and positional ambience lookups (world/meadow_sites.gd).

func run(t: Object) -> void:
	var c: Dictionary = MeadowSites.counts()
	t.ok(bool(c["ground"]), "ground.png loads for surface lookups")
	t.ok(int(c["wood"]) >= 6 and int(c["water"]) >= 2 and int(c["trees"]) >= 10, "pads, gate, water and trees are read from placements")
	WalkMask.use("")
	t.eq(MeadowSites.surface_at(Vector2(204.0, 245.5)), MeadowSites.WOOD, "a pad is wood")
	t.eq(MeadowSites.surface_at(Vector2(204.0 + 12.0, 245.5)), MeadowSites.WOOD, "the pad's edge is still wood (TexelPad.HALF)")
	t.ok(MeadowSites.surface_at(Vector2(204.0 + 16.0, 245.5 + 8.0)) != MeadowSites.WOOD, "past the plate is not wood")
	t.eq(MeadowSites.surface_at(Vector2(330.0, 93.2)), MeadowSites.WOOD, "the gate is wood")
	t.eq(MeadowSites.surface_at(Vector2(289.0, 209.0)), MeadowSites.SAND, "the path is sand")
	t.eq(MeadowSites.surface_at(Vector2(318.0, 218.0)), MeadowSites.SAND, "path texel (318,218) is sand")
	t.eq(MeadowSites.surface_at(Vector2(241.0, 193.0)), MeadowSites.GRASS, "meadow texel (241,193) is grass")
	t.eq(MeadowSites.surface_at(Vector2(175.0, 175.0)), MeadowSites.GRASS, "open meadow is grass")
	t.ok(MeadowSites.surface_at(Vector2(-500.0, -500.0)) == MeadowSites.GRASS, "off the map falls back to grass")
	var shore: float = MeadowSites.water_proximity(Vector2(415.0, 300.0))
	t.ok(shore > 0.6, "at the lake edge the shore is loud (%.2f)" % shore)
	t.ok(MeadowSites.water_proximity(Vector2(50.0, 60.0)) < 0.05, "far from water the shore is silent")
	t.ok(MeadowSites.water_proximity(Vector2(415.0, 300.0)) > MeadowSites.water_proximity(Vector2(415.0, 345.0)), "shore fades with distance")
	t.ok(MeadowSites.tree_proximity(Vector2(191.0, 175.0)) > 0.3, "under the oaks there is birdsong")
	t.ok(MeadowSites.tree_proximity(Vector2(620.0, 20.0)) < 0.05, "far from trees there is none")
	for p: Vector2 in [Vector2(10, 10), Vector2(300, 200), Vector2(415, 258), Vector2(600, 340)]:
		var w: float = MeadowSites.water_proximity(p)
		var b: float = MeadowSites.tree_proximity(p)
		t.ok(w >= 0.0 and w <= 1.0 and b >= 0.0 and b <= 1.0, "proximities stay in 0..1 at %s" % str(p))
	for s: String in ["grass", "sand", "wood"]:
		for i in 4:
			t.ok(ResourceLoader.exists("res://assets/audio/sfx/step_%s_%d.ogg" % [s, i]), "step_%s_%d exists" % [s, i])
	for i in 5:
		t.ok(ResourceLoader.exists("res://assets/audio/sfx/bird_%d.ogg" % i), "bird_%d exists" % i)
	t.ok(ResourceLoader.exists("res://assets/audio/amb/shore_amb.ogg"), "shore loop exists")

	# Gains follow proximity. Drives the Audio autoload's own stepping, no frames needed.
	var a: Node = Engine.get_main_loop().root.get_node_or_null("Audio")
	t.ok(a != null, "Audio autoload present")
	if a != null:
		a.set_surroundings(0.9, 0.0)
		for i in 40:
			a.world_step(0.1)
		var st: Dictionary = a.world_state()
		t.ok(float(st["water"]) > 0.85, "shore gain rises to the target (%.2f)" % float(st["water"]))
		t.ok(float(st["trees"]) < 0.01, "bird gain stays down away from trees")
		t.ok(bool(st["shore_playing"]), "shore loop starts near water")
		a.set_surroundings(0.0, 0.96)
		for i in 40:
			a.world_step(0.1)
		st = a.world_state()
		t.ok(float(st["water"]) < 0.01 and float(st["trees"]) > 0.9, "gains swap when the walker moves from shore to oaks")
		t.ok(not bool(st["shore_playing"]), "shore loop stops away from water")
		a.set_surroundings(0.0, 0.0)
		for i in 40:
			a.world_step(0.1)
