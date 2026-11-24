extends RefCounted
## Footstep surfaces and positional ambience lookups (world/meadow_sites.gd).

func run(t: Object) -> void:
	var c: Dictionary = MeadowSites.counts()
	t.ok(bool(c["ground"]), "ground.png loads for surface lookups")
	t.ok(int(c["wood"]) >= 6 and int(c["water"]) >= 2 and int(c["trees"]) >= 10, "pads, gate, water and trees are read from placements")
	MeadowSites.use("", "", MeadowSites.MEADOW_OFFSET)
	# the first Sprout pad sits beside the path now (tools/art/gen_meadow3d.py beside_path), at (194, 230)
	t.eq(MeadowSites.surface_at(Vector2(194.0, 227.5)), MeadowSites.WOOD, "a pad is wood")
	t.eq(MeadowSites.surface_at(Vector2(194.0 + 12.0, 227.5)), MeadowSites.WOOD, "the pad's edge is still wood (TexelPad.HALF)")
	t.ok(MeadowSites.surface_at(Vector2(194.0 + 16.0, 227.5 + 8.0)) != MeadowSites.WOOD, "past the plate is not wood")
	t.eq(MeadowSites.surface_at(Vector2(330.0, 93.2)), MeadowSites.WOOD, "the gate is wood")
	t.eq(MeadowSites.surface_at(Vector2(289.0, 209.0)), MeadowSites.SAND, "the path is sand")
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
	# Farm surfaces: the Larkmoor ground turns on the farm frames. Centres of soil item 67 and wheat item 10 (farm.json).
	MeadowSites.use("res://assets/art/zone1b/larkmoor/placements3d.json", "res://assets/art/zone1b/larkmoor/ground.png", Vector2i(0, 0))
	t.ok(int(MeadowSites.counts()["soil"]) >= 5 and int(MeadowSites.counts()["wheat"]) >= 50, "farm soil and wheat frames load from farm.json")
	t.eq(MeadowSites.surface_at(Vector2(2019.0, 1062.0)), MeadowSites.WHEAT, "inside a wheat frame is wheat")
	t.eq(MeadowSites.surface_at(Vector2(2060.0, 1130.0)), MeadowSites.DIRT, "tilled soil outside the wheat is dirt")
	t.ok(MeadowSites.surface_at(Vector2(1000.0, 100.0)) != MeadowSites.DIRT, "away from the farm there is no dirt")
	MeadowSites.use("", "", MeadowSites.MEADOW_OFFSET)
	t.ok(int(MeadowSites.counts()["wheat"]) == 0, "the meadow has no farm frames")
	for s: String in ["grass", "sand", "wood", "dirt", "wheat"]:
		for i in 4:
			t.ok(ResourceLoader.exists("res://assets/audio/sfx/step_%s_%d.ogg" % [s, i]), "step_%s_%d exists" % [s, i])
	t.ok(ResourceLoader.exists("res://assets/audio/sfx/purchase.ogg"), "purchase chime exists")
	t.ok(ResourceLoader.exists("res://assets/audio/amb/lava.ogg"), "lava loop exists")
	for i in 5:
		t.ok(ResourceLoader.exists("res://assets/audio/sfx/bird_%d.ogg" % i), "bird_%d exists" % i)
	t.ok(ResourceLoader.exists("res://assets/audio/amb/shore_amb.ogg"), "shore loop exists")

	# Gains follow proximity. Drives the Audio autoload's own stepping, no frames needed.
	# Autoloads are not instanced under --script, so build a private Audio and put it in the tree for _ready.
	var a: Node = (load("res://audio/audio.gd") as GDScript).new() as Node
	a.name = "AudioUnderTest"
	(t as SceneTree).root.add_child(a)
	if a.get("_shore") == null:
		a.call("_ready")   # tests run inside _init, before the tree has readied its nodes
	t.ok(a != null, "Audio instance built")
	if a != null:
		a.set_surroundings(0.9, 0.0)
		for i in 40:
			a.world_step(0.1)
		var st: Dictionary = a.world_state()
		t.ok(float(st["water"]) > 0.85, "shore gain rises to the target (%.2f)" % float(st["water"]))
		t.ok(float(st["trees"]) < 0.01, "bird gain stays down away from trees")
		a.set_surroundings(0.0, 0.96)
		for i in 40:
			a.world_step(0.1)
		st = a.world_state()
		t.ok(float(st["water"]) < 0.01 and float(st["trees"]) > 0.9, "gains swap when the walker moves from shore to oaks")
		a.set_surroundings(0.0, 0.0)
		for i in 40:
			a.world_step(0.1)
		a.free()
