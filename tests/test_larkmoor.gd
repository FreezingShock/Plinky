extends RefCounted
## Larkmoor, the big meadow past the onboarding gate: zone chain, pads, scene anchors, walk mask, save migration.

const DIR: String = "res://assets/art/zone1b/larkmoor/"


func run(t: Object) -> void:
	var sim: Sim = t.make_sim()
	var z: ZoneDef = sim.zone_defs.get(&"larkmoor") as ZoneDef
	t.ok(z != null, "larkmoor zone exists")
	if z == null:
		return
	t.eq((sim.zone_defs.get(&"zone1") as ZoneDef).next_zone, &"larkmoor", "the onboarding gate leads to Larkmoor")
	t.eq(z.next_zone, &"zone2", "Larkmoor's far gate leads to the quarry")
	t.ok((sim.zone_defs.get(&"zone1") as ZoneDef).order < z.order and z.order < (sim.zone_defs.get(&"zone2") as ZoneDef).order, "zone order is meadow, Larkmoor, quarry")
	t.eq(z.pad_buttons.size(), 10, "ten pads")
	var last: float = 0.0
	for id: String in ["g1", "g2", "h1", "h2", "t1", "t2"]:
		var b: ButtonDef = sim.button_defs.get(StringName(id)) as ButtonDef
		t.ok(b != null and b.zone == &"larkmoor" and b.row == &"multiplier", "%s is a Larkmoor multiplier pad" % id)
		t.ok(b.base_cost > last, "%s costs more than the pad before it" % id)
		last = b.base_cost
	last = 0.0
	for id: String in ["o1", "c1", "l1", "e1"]:
		var b: ButtonDef = sim.button_defs.get(StringName(id)) as ButtonDef
		t.ok(b != null and b.zone == &"larkmoor" and b.row == &"rebirth", "%s is a Larkmoor rebirth pad" % id)
		t.ok(b.base_cost > last, "%s costs more than the pad before it" % id)
		last = b.base_cost

	# the scene: one pad anchor per pad, the gates, the spawn, districts, and every one of them reachable on foot
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "placements3d.json")) as Dictionary
	t.ok(not data.is_empty(), "placements load")
	var pads: int = 0
	var kinds: Dictionary = {}
	WalkMask.use(z.walk_mask_path, Vector2i.ZERO)
	t.ok(WalkMask.available(), "walk mask loads")
	for a: Dictionary in data.anchors:
		kinds[String(a.kind)] = int(kinds.get(String(a.kind), 0)) + 1
		var p := Vector2(float(a.sx), float(a.sy))
		match String(a.kind):
			"pad":
				pads += 1
				t.ok(WalkMask.walkable(WalkMask.nearest(p, 14)) and WalkMask.nearest(p, 14).distance_to(p) < 14.0, "pad %s is within reach on foot" % str(p))
			"gate", "arch", "player_spawn":
				t.ok(WalkMask.nearest(p, 14).distance_to(p) < 14.0, "%s %s is within reach on foot" % [a.kind, str(p)])
	t.eq(pads, z.pad_buttons.size(), "pad anchors match pad_buttons")
	for k: String in ["gate", "arch", "player_spawn"]:
		t.eq(int(kinds.get(k, 0)), 1, "exactly one %s anchor" % k)
	t.ok(int(kinds.get("district", 0)) >= 6, "districts are marked")
	var world: Array = data.get("world", []) as Array
	t.ok(world.size() == 4 and float(world[2]) > 1000.0, "world rect is bigger than the 640x360 frame")
	t.ok(not WalkMask.walkable(Vector2(5.0, 5.0)), "open water at the corner is not walkable")

	# the scene node itself
	var scene: Node = (load(z.scene_path) as PackedScene).instantiate()
	var holder := Node2D.new()
	holder.add_child(scene)
	scene.call("_ready")   # the test runs inside the SceneTree's _init, before nodes are readied
	var anchors: Node = scene.get_node("Anchors")
	for i in z.pad_buttons.size():
		t.ok(anchors.get_node_or_null("Pad%d" % i) != null, "Pad%d anchor exists" % i)
	t.ok(anchors.get_node_or_null("Gate") != null and anchors.get_node_or_null("Arch") != null and anchors.get_node_or_null("Walker") != null, "Gate, Arch and Walker anchors exist")
	var d: Dictionary = scene.call("district_at", (anchors.get_node("District_heronmere") as Marker2D).position)
	t.eq(String(d.get("name", "")), "Heronmere", "district lookup names Heronmere at its centre")
	t.ok((scene.call("district_at", Vector2(20.0, 20.0)) as Dictionary).is_empty(), "no district over open water")
	# lighting: every prop casts a shadow and lanterns light the ground (same wiring as the meadow)
	var props := Node2D.new()
	scene.call("spawn_occluders", props)
	var placements: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "placements3d.json")) as Dictionary
	var sprites: Array = placements.sprites as Array
	var lanterns: int = 0
	for sp: Dictionary in sprites:
		if String(sp.kind) == "lantern":
			lanterns += 1
	var shadows: SkyShadows = scene.get_node("Shadows") as SkyShadows
	t.ok(shadows != null, "Larkmoor has a Shadows node")
	if shadows != null:
		var shadow_pads: int = 0
		for an: Dictionary in placements.anchors as Array:
			if String(an.kind) == "pad":
				shadow_pads += 1
		t.eq(shadows._items.size(), sprites.size() + shadow_pads, "Larkmoor registers a cast shadow for every prop, landmark and pad")
	var sky: SkyCycle = scene.get_node("Sky") as SkyCycle
	t.ok(sky.shadows == shadows, "Larkmoor's sky drives its shadows")
	t.ok(lanterns > 0 and sky._lights.size() >= lanterns + 1, "lanterns and the walker get light pools (%d lights)" % sky._lights.size())
	props.free()
	holder.free()
	WalkMask.use("")

	# footsteps and ambience read the right zone
	MeadowSites.use(DIR + "placements3d.json", DIR + "ground.png", Vector2i.ZERO)
	t.ok(bool(MeadowSites.counts()["ground"]), "Larkmoor ground loads for surface lookups")
	t.ok(int(MeadowSites.counts()["water"]) >= 2, "Larkmoor water is read")
	MeadowSites.use("", "", MeadowSites.MEADOW_OFFSET)
	t.ok(int(MeadowSites.counts()["water"]) >= 2, "switching back restores the meadow")

	# gate chain and save migration
	sim.new_game()
	sim.stats[&"reb"] = BigNum.from_float(9.0)
	sim.step(0.1)
	t.ok(sim.enter_zone(&"larkmoor"), "walk through the onboarding gate")
	sim.stats[&"reb"] = BigNum.from_float(z.gate_threshold)
	sim.step(0.1)
	t.ok(sim.is_gate_open(&"larkmoor"), "Larkmoor's gate opens at its threshold")
	t.ok(sim.enter_zone(&"zone2"), "and leads to the quarry")

	var old: Dictionary = {"zone": "zone2", "gates": ["zone1"], "stats": {"cash": 5.0}}
	var s2: Sim = t.make_sim()
	s2.from_dict(old)
	t.eq(s2.zone_id, &"zone2", "a save that was in zone 2 stays there")
	t.ok(s2.is_gate_open(&"larkmoor") and s2.is_zone_unlocked(&"zone2"), "and zone 2 stays unlocked")
	t.ok(s2.enter_zone(&"larkmoor"), "it can walk back into Larkmoor")
	var s3: Sim = t.make_sim()
	s3.from_dict({"zone": "zone1", "gates": ["zone1"]})
	t.eq(s3.zone_id, &"zone1", "a save in the onboarding meadow stays there")
	t.ok(not s3.is_gate_open(&"larkmoor"), "without Larkmoor's gate")
	t.ok(s3.enter_zone(&"larkmoor"), "its open gate now leads to Larkmoor")
