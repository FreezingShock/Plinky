extends RefCounted
## Zone 2 Ember Quarry blockout: Slag, Heat, the Forge row, the zone's scene and walk mask.

const DIR: String = "res://assets/art/zone2/quarry/"


func run(t: Object) -> void:
	var sim: Sim = t.make_sim()
	var z2: ZoneDef = sim.zone_defs.get(&"zone2") as ZoneDef
	t.ok(z2 != null and z2.heat_cap > 0.0, "zone 2 has Heat")
	t.eq(Array(z2.pad_buttons), ["f1", "f2", "f3"], "zone 2 pads are the Forge row")
	for id: StringName in [&"f1", &"f2", &"f3"]:
		t.ok(sim.button_defs.has(id), "button %s exists" % id)

	# Slag multiplies cash income as its own factor and stacks with Multiplier
	sim.stats[&"mult"] = BigNum.from_float(3.0)
	var base: float = sim.income_per_second(&"cash").to_float()
	sim.stats[&"slag"] = BigNum.from_float(4.0)
	t.near(sim.income_per_second(&"cash").to_float(), base * (1.0 + 4.0 * 0.5), 1e-9, "slag adds a (1 + slag / 2) factor")

	# Heat only exists in zone 2
	sim.stats[&"reb"] = BigNum.from_float(9.0)
	sim.step(0.1)
	sim.feed_heat(5.0)
	t.near(sim.heat, 0.0, 1e-9, "no Heat in zone 1")
	t.ok(not sim.is_hot(), "zone 1 is never Hot")
	t.ok(not sim.enter_zone(&"zone2"), "zone 2 is locked until Larkmoor's far gate opens")
	sim.gates_open[&"larkmoor"] = true
	t.ok(sim.enter_zone(&"zone2"), "enter zone 2")
	t.near(sim.heat, 0.0, 1e-9, "Heat starts at 0")
	var hot_events: Array = []
	sim.heat_hot_changed.connect(func(h: bool) -> void: hot_events.append(h))

	# charging, the cap, the hot line and decay (all values come from the ZoneDef)
	sim.feed_heat(0.5)
	t.near(sim.heat, 0.5 * z2.heat_charge_per_second, 1e-9, "standing on a vent charges Heat")
	sim.feed_heat(100.0)
	t.near(sim.heat, z2.heat_cap, 1e-9, "Heat caps")
	t.ok(sim.is_hot(), "full Heat is Hot")
	t.eq(hot_events, [true], "heat_hot_changed fired once on the way up")
	sim.step(1.0)
	t.near(sim.heat, z2.heat_cap - z2.heat_decay_per_second, 1e-9, "Heat decays while away from vents")

	# a Hot press pays heat_hot_mult times as much as a cold one
	sim.stats[&"cash"] = BigNum.from_float(1.0e7)
	var cold: BigNum = sim.press_gain_preview(&"f1")
	var before: float = sim.get_stat(&"slag").to_float()
	t.ok(sim.try_press(&"f1"), "press f1 while Hot")
	t.near(sim.get_stat(&"slag").to_float() - before, cold.to_float() * z2.heat_hot_mult, 1e-9, "Hot press pays double")
	sim.heat = 0.0
	before = sim.get_stat(&"slag").to_float()
	t.ok(sim.try_press(&"f1"), "press f1 while cold")
	t.near(sim.get_stat(&"slag").to_float() - before, cold.to_float(), 1e-9, "cold press pays the base reward")

	# decay runs out, hot flips back off, rebirth and zone entry clear Heat
	sim.feed_heat(100.0)
	for i in 100:
		sim.step(0.1)
	t.ok(not sim.is_hot(), "Heat falls below the hot line")
	t.eq(hot_events.back(), false, "heat_hot_changed fired on the way down")
	sim.feed_heat(100.0)
	sim.stats[&"clover"] = BigNum.from_float(2.0)
	t.ok(sim.try_rebirth(), "rebirth in zone 2")
	t.near(sim.heat, 0.0, 1e-9, "rebirth clears Heat")
	sim.feed_heat(100.0)
	sim.enter_zone(&"zone1")
	t.near(sim.heat, 0.0, 1e-9, "zone entry clears Heat")

	# Gate: Slag 9 opens it
	sim.enter_zone(&"zone2")
	sim.stats[&"slag"] = BigNum.from_float(8.0)
	sim.step(0.1)
	t.ok(not sim.is_gate_open(&"zone2"), "zone 2 gate closed at 8 slag")
	sim.stats[&"slag"] = BigNum.from_float(9.0)
	sim.step(0.1)
	t.ok(sim.is_gate_open(&"zone2"), "zone 2 gate opens at 9 slag")

	# A save made in zone 2 loads back into zone 2 with its scene, mask and pads resolvable
	var saved: Dictionary = sim.to_dict()
	var fresh: Sim = t.make_sim()
	t.ok(fresh.from_dict(saved), "zone 2 save loads")
	t.eq(fresh.zone_id, &"zone2", "loaded save is in zone 2")
	t.ok(fresh.is_gate_open(&"zone2"), "zone 2 gate stays latched across a save")
	var lz: ZoneDef = fresh.current_zone()
	t.ok(lz != null and lz.scene_path != "" and lz.pad_buttons.size() == 3, "loaded zone has its scene and Forge pads")
	fresh.heat = 0.0
	t.ok(not fresh.is_hot(), "Heat is not saved")

	# Scene, mask and anchors
	t.ok(ResourceLoader.exists(z2.scene_path), "zone 2 scene exists")
	WalkMask.use(z2.walk_mask_path)
	t.ok(WalkMask.available(), "quarry walkable.png loads")
	var im: Image = WalkMask.image()
	if im != null:
		t.eq(im.get_size(), Vector2i(840, 480), "quarry mask matches the ground frame")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "placements3d.json")) as Dictionary
	var pads: int = 0
	var vents: int = 0
	var has_gate: bool = false
	var has_spawn: bool = false
	for a: Variant in data.get("anchors", []):
		var d: Dictionary = a as Dictionary
		var kind: String = str(d.get("kind", ""))
		var p := Vector2(float(d.get("sx", 0)), float(d.get("sy", 0)))
		var reach: int = 28 if kind == "player_spawn" else 14
		if kind == "pad":
			pads += 1
		elif kind == "vent":
			vents += 1
			t.ok(float(d.get("radius", 0)) >= 8.0, "vent has a usable radius")
		elif kind == "gate":
			has_gate = true
		elif kind == "player_spawn":
			has_spawn = true
		if kind in ["pad", "vent", "gate", "player_spawn"]:
			var n: Vector2 = WalkMask.nearest(p, reach)
			t.ok(WalkMask.walkable(n) and p.distance_to(n) <= float(reach), "%s at %s is reachable within %d texels" % [kind, str(p), reach])
	t.eq(pads, z2.pad_buttons.size(), "one pad anchor per Forge button")
	t.ok(vents >= 2, "at least two vents")
	t.ok(has_gate and has_spawn, "gate and spawn anchors exist")
	t.ok(not WalkMask.walkable(Vector2(-90, -50)), "outside the quarry is blocked")
	for s: Variant in data.get("sprites", []):
		t.ok(ResourceLoader.exists(DIR + str((s as Dictionary).get("file", ""))), "sprite %s exists" % str((s as Dictionary).get("file", "")))
	# the walker can get from the spawn to every pad, vent and the gate (flood fill over the mask)
	if im != null:
		var targets: Array[Vector2] = []
		var start: Vector2 = Vector2.ZERO
		for a: Variant in data.get("anchors", []):
			var d: Dictionary = a as Dictionary
			var p := Vector2(float(d.get("sx", 0)), float(d.get("sy", 0)))
			if str(d.get("kind", "")) == "player_spawn":
				start = WalkMask.nearest(p, 28)
			elif str(d.get("kind", "")) in ["pad", "vent", "gate"]:
				targets.append(WalkMask.nearest(p, 14))
		var reached: Dictionary = _flood(im, start)
		for tp: Vector2 in targets:
			var px: Vector2i = Vector2i(int(floorf(tp.x)) + WalkMask.OFFSET.x, int(floorf(tp.y)) + WalkMask.OFFSET.y)
			t.ok(reached.has(px), "spawn connects to %s" % str(tp))
	WalkMask.use("")   # back to the meadow mask for any later suite


## Pixels of the mask reachable from `start` (a texel in the 640x360 frame) by 4-neighbour steps.
func _flood(im: Image, start: Vector2) -> Dictionary:
	var seen: Dictionary = {}
	var first: Vector2i = Vector2i(int(floorf(start.x)) + WalkMask.OFFSET.x, int(floorf(start.y)) + WalkMask.OFFSET.y)
	var queue: Array[Vector2i] = [first]
	seen[first] = true
	var head: int = 0
	var w: int = im.get_width()
	var h: int = im.get_height()
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for off: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + off
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or seen.has(n):
				continue
			if im.get_pixel(n.x, n.y).r > 0.5:
				seen[n] = true
				queue.append(n)
	return seen
