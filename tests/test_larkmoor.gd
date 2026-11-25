extends RefCounted
## Larkmoor, the big meadow past the onboarding gate: zone chain, pads, scene anchors, walk mask, save migration.

const DIR: String = "res://assets/art/zone1b/larkmoor/"


func run(t: Object) -> void:
	var sim: Sim = t.make_sim()
	var z: ZoneDef = sim.zone_defs.get(&"larkmoor") as ZoneDef
	t.ok(z != null, "larkmoor zone exists")
	if z == null:
		return
	# view streaming: the chunks a view rect covers (pure math, so no scene is needed)
	var scene_script: Script = load("res://world/larkmoor_scene.gd") as Script
	t.eq(scene_script.call("chunk_range", Rect2(0.0, 0.0, 0.0, 0.0), 1), Rect2i(), "an empty view rect has no chunks")
	t.eq(scene_script.call("chunk_range", Rect2(170.0, 10.0, 100.0, 100.0), 0), Rect2i(1, 0, 1, 1), "a view inside one chunk covers that chunk")
	t.eq(scene_script.call("chunk_range", Rect2(170.0, 10.0, 100.0, 100.0), 1), Rect2i(0, -1, 3, 3), "the view margin adds a chunk on every side")
	t.eq(scene_script.call("chunk_range", Rect2(150.0, 0.0, 200.0, 10.0), 0), Rect2i(0, 0, 3, 1), "a view that straddles two chunk edges covers both")
	# node ceilings for chunk loads: the nearest chunks always load, the outer ring and the view stop at their ceilings
	t.ok(scene_script.call("may_load", 1, 99999) as bool, "the chunks beside the walker load whatever the node count")
	t.ok(scene_script.call("may_load", 2, 1330) as bool, "the outer walker ring loads up to 1330 nodes")
	t.ok(not (scene_script.call("may_load", 2, 1331) as bool), "the outer walker ring stops above 1330 nodes")
	t.ok(scene_script.call("may_load", 3, 1300) as bool, "the view loads up to 1300 nodes")
	t.ok(not (scene_script.call("may_load", 3, 1301) as bool), "the view stops above 1300 nodes")
	# the hard ceiling: over 1340 nodes a chunk off the screen is shed, whatever raised the count
	# spawn time per frame: the normal 2 ms, and a larger share only while a chunk on screen waits (a fast pan's pop-in)
	t.near(scene_script.call("spawn_budget_ms", false) as float, 2.0, 0.0001, "a still view spawns within 2 ms a frame")
	t.ok((scene_script.call("spawn_budget_ms", true) as float) > (scene_script.call("spawn_budget_ms", false) as float), "a waiting view on screen gets a larger spawn budget")
	t.ok((scene_script.call("spawn_budget_ms", true) as float) <= 4.0001, "the waiting-view budget stays at 4 ms or less")
	t.ok(not (scene_script.call("may_shed", 1340) as bool), "1340 nodes is still within the hard ceiling")
	t.ok(scene_script.call("may_shed", 1341) as bool, "1341 nodes sheds a chunk")
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
	# the river: one course from Heronmere into the mere. Its water is never walkable on foot, but the mask flags it, so the
	# walker can jump it. Landing in it sends the walker to the nearest bank. Both bridge decks stand on the river.
	var river := Vector2(1400.0, 927.0)   # across the river at x 1400: water from y 922 to 932, walkable banks either side
	t.ok(not WalkMask.walkable(river) and WalkMask.is_water(river), "the river is water: not walkable on foot, flagged for a jump")
	t.ok(not WalkMask.is_water(Vector2(1400.0, 900.0)) and WalkMask.walkable(Vector2(1400.0, 900.0)), "dry bank beside the river is walkable and not water")
	t.ok(WalkMask.walkable(Vector2(1400.0, 917.0)) and WalkMask.walkable(Vector2(1400.0, 935.0)), "walkable banks on both sides of the river")
	var bank: Vector2 = WalkMask.landing(river)
	t.ok(WalkMask.walkable(bank) and bank.distance_to(river) <= 8.0, "landing in the river sends the walker to the nearest bank (%s)" % str(bank))
	t.eq(WalkMask.landing(Vector2(1400.0, 900.0)), Vector2(1400.0, 900.0), "a walkable spot is where the walker lands")
	t.ok(WalkMask.walkable(Vector2(1524.0, 912.0)) and not WalkMask.is_water(Vector2(1524.0, 912.0)), "the main bridge deck is walkable over the river")
	t.ok(WalkMask.walkable(Vector2(1188.0, 974.0)), "the footbridge deck on the west trail is walkable")
	t.eq(WalkMask.landing(Vector2(1524.0, 912.0)), Vector2(1524.0, 912.0), "a bridge deck is where the walker lands, not the bank")
	# the ruins: each one blocks its own foot, the walker can still reach it on foot, and in front of it (south, the viewer's
	# side) the walker stops past the front stone, not inside it. The stop is the first walkable texel walked straight in.
	# the Ember Quarry entrance props are solid: each one's foot is blocked, and its box is kept as a no-stand area
	var ember_doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "entrance/entrance.json")) as Dictionary
	var solid_boxes: Array[Rect2] = []
	for es: Dictionary in ember_doc.get("sprites", []) as Array:
		if String(es.kind) != "ember_prop":
			continue
		var box := Rect2(float(es.x), float(es.y), float(es.w), float(es.h))
		var centre: Vector2 = box.get_center()
		t.ok(not WalkMask.walkable(centre), "the ember prop %s is solid at its centre %s" % [String(es.file).get_file(), str(centre)])
		solid_boxes.append(box)
	var ruin_n: int = 0
	var fronts: int = 0
	for ruin_sp: Dictionary in data.get("sprites", []) as Array:
		if String(ruin_sp.kind) != "ruin":
			continue
		ruin_n += 1
		var foot := Vector2(float(ruin_sp.foot[0]), float(ruin_sp.foot[1]))
		t.ok(not WalkMask.walkable(foot), "the ruin at %s blocks its own foot" % str(foot))
		var south: float = _stop_distance(foot, Vector2(0.0, 1.0), 14.0)
		if south > 0.0:
			fronts += 1
			t.ok(south > 0.0, "the ruin at %s stops the walker in front of it, to the south (%.1f texels)" % [str(foot), south])
			var stop_pt: Vector2 = foot + Vector2(0.0, south)
			var inside_prop: bool = false
			for box: Rect2 in solid_boxes:
				if box.has_point(stop_pt):
					inside_prop = true
			t.ok(not inside_prop, "the front stop of the ruin at %s is not inside a solid prop" % str(foot))
		var reach: float = -1.0
		for dir: Vector2 in [Vector2(0.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0), Vector2(-1.0, 1.0), Vector2(-1.0, 0.0), Vector2(-1.0, -1.0)]:
			var step_d: float = _stop_distance(foot, dir, 20.0)
			if step_d > 0.0 and (reach < 0.0 or step_d < reach):
				reach = step_d
		t.ok(reach > 0.0, "the ruin at %s has a walkable stop within 20 texels" % str(foot))
	t.ok(ruin_n >= 11, "the eleven Larkmoor ruins are placed (%d)" % ruin_n)
	# the gatehouse sits on a cliff with no ground to the south, and the Ember crates shield ruin 028 from the south, east and north
	t.ok(fronts >= 9, "nine ruins have a front stop to the south, the gatehouse and the crate-shielded 028 are the exceptions (%d)" % fronts)

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
	# the Ember Quarry cave entrance props live in their own file and the scene merges them into the placements
	var entrance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "entrance/entrance.json")) as Dictionary
	sprites = sprites + (entrance.get("sprites", []) as Array)
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
		t.ok(shadows._overlay != null and shadows._overlay.multimesh != null and shadows._overlay.multimesh.visible_instance_count == shadows._items.size(), "prop shadows get a clipped copy above the pads (one overlay layer, one instance per caster)")
		t.ok(shadows._caster_mm != null and shadows._caster_mm.multimesh.visible_instance_count == shadows._items.size(), "every cast shadow is one instance in the batched caster layer")
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


## Texels from foot to the first walkable texel walked straight in along dir (one texel steps), or -1 when none within max_d.
func _stop_distance(foot: Vector2, dir: Vector2, max_d: float) -> float:
	var d: float = 0.5
	while d <= max_d:
		if WalkMask.walkable(foot + dir * d):
			return d
		d += 0.5
	return -1.0
