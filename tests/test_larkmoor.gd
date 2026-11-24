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
	t.eq(z.pad_buttons.size(), 31, "thirty-one pads: five rows of five, and the Starbloom row of six (its last three on the west bank)")
	var rows: Dictionary = {&"lark_sprout": &"sunlight", &"lark_clover": &"dewdrop", &"thistle": &"sunlight", &"heather": &"thistle", &"foxglove": &"heather", &"starbloom": &"foxglove"}
	for row: StringName in rows:
		var last: float = 0.0
		var per_row: int = 6 if row == &"starbloom" else 5
		for i in per_row:
			var id: StringName = StringName("%s_%d" % [row, i + 1])
			var b: ButtonDef = sim.button_defs.get(id) as ButtonDef
			t.ok(b != null and b.zone == &"larkmoor" and b.row == row and b.row_index == i, "%s is pad %d of the Larkmoor %s row" % [id, i + 1, row])
			t.ok(b.cost_stat == rows[row], "%s is paid in %s" % [id, rows[row]])
			t.ok(b.reward_stat == (sim.tier_defs[row] as TierDef).stat, "%s pays its row's stat" % id)
			t.ok(b.base_cost > last, "%s costs more than the pad before it" % id)
			last = b.base_cost
	t.eq(z.gate_stat, &"starbloom", "the far gate opens on Starbloom Petals")
	# the Sprout and Clover rows open the district before Thistle (common, then uncommon, then rare), and they stand on the meadow flowers
	t.ok(sim.is_tier_open(&"lark_sprout") and not sim.is_tier_open(&"lark_clover") and not sim.is_tier_open(&"thistle"), "Larkmoor opens on the Sprout row, then Clover, then Thistle")
	t.eq(sim.next_tier(&"lark_sprout").id, &"lark_clover", "the Sprout row opens Clover")
	t.eq(sim.next_tier(&"lark_clover").id, &"thistle", "the Clover row opens Thistle")
	t.eq(TexelPad.FLOWER_OF.get(&"lark_clover"), &"clover", "the Larkmoor Clover row draws the meadow Clover flower")
	t.eq(TexelPad.FLOWER_OF.get(&"lark_sprout"), &"sprout", "the Larkmoor Sprout row draws the meadow Sprout flower")

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
	for pair: Array in [["reedgate", "Reedgate"], ["cairnfold", "Cairnfold"]]:
		var dd: Dictionary = scene.call("district_at", (anchors.get_node("District_" + String(pair[0])) as Marker2D).position)
		t.eq(String(dd.get("name", "")), String(pair[1]), "district lookup names %s at its centre" % pair[1])
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
		# The farm (world/farm/) is always loaded; its buildings and props cast shadows, its fields and plots do not.
		var farm_casters: int = 0
		for fi: Variant in (FarmProps.load_manifest().get("items", []) as Array):
			if FarmProps.casts_shadow(String((fi as Dictionary).kind)):
				farm_casters += 1
		t.eq(shadows._items.size(), scene.call("loaded_prop_count") + shadow_pads + farm_casters, "Larkmoor registers a cast shadow for every loaded prop, landmark, pad and farm building")
		t.eq(scene.call("prop_total"), sprites.size(), "every prop in the placements is indexed to a chunk")
		t.ok(int(scene.call("loaded_prop_count")) < sprites.size(), "only the chunks near the start are loaded (%d of %d)" % [scene.call("loaded_prop_count"), sprites.size()])
		t.eq(shadows._pads.size(), shadow_pads, "Larkmoor tells its shadows where every pad is")
		t.ok(shadows._overlay != null and shadows._overlay.get_child_count() > 0, "prop shadows get a clipped copy above the pads")
	var sky: SkyCycle = scene.get_node("Sky") as SkyCycle
	t.ok(sky.shadows == shadows, "Larkmoor's sky drives its shadows")
	t.ok(lanterns > 0 and sky._lights.size() >= lanterns, "every lantern gets a light pool, none dropped at the cap (%d lights, %d lanterns)" % [sky._lights.size(), lanterns])
	# lamps: off by day and fully lit at night, with a smooth step between (dusk and dawn)
	t.ok(is_equal_approx(SkyCycle.lamp_light_k(0.0), 0.0) and is_equal_approx(SkyCycle.lamp_light_k(1.0), 1.0), "lamps are off in full day and fully lit at night")
	t.ok(SkyCycle.lamp_light_k(0.3) > 0.0 and SkyCycle.lamp_light_k(0.3) < 1.0, "lamps fade in through dusk")
	# the lamps are spread evenly: no two ordinary lamps stand closer than the generator's spacing floor
	var feet: Array = []
	for sp: Dictionary in sprites:
		if String(sp.kind) == "lantern" and float(sp.w) < 20.0:
			feet.append(Vector2(float(sp.foot[0]), float(sp.foot[1])))
	var closest: float = INF
	for i in feet.size():
		for j in range(i + 1, feet.size()):
			closest = minf(closest, (feet[i] as Vector2).distance_to(feet[j] as Vector2))
	t.ok(feet.size() >= 20 and closest >= 75.0, "ordinary lamps are spread evenly, none closer than 75 texels (%d lamps, closest %.0f)" % [feet.size(), closest])
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
	sim.stats[&"clover"] = BigNum.from_float(9.0)
	sim.step(0.1)
	t.ok(sim.enter_zone(&"larkmoor"), "walk through the onboarding gate")
	sim.stats[&"starbloom"] = BigNum.from_float(z.gate_threshold)
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
