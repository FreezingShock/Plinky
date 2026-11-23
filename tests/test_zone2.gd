extends RefCounted
## Zone 2 Ember Quarry blockout: Slag, Heat, the Forge row, the zone's scene and walk mask.

const DIR: String = "res://assets/art/zone2/quarry/"


func run(t: Object) -> void:
	var sim: Sim = t.make_sim()
	var z2: ZoneDef = sim.zone_defs.get(&"zone2") as ZoneDef
	t.ok(z2 != null and z2.heat_cap > 0.0, "zone 2 has Heat")
	t.eq(z2.pad_buttons.size(), 18, "zone 2 has six rows of three pads")
	for id: String in z2.pad_buttons:
		t.ok(sim.button_defs.has(StringName(id)), "button %s exists" % id)

	# Slag multiplies Embers income as its own factor and stacks with Cinder
	sim.stats[&"cinder"] = BigNum.from_float(3.0)
	var base: float = sim.income_per_second(&"embers").to_float()
	sim.stats[&"slag"] = BigNum.from_float(4.0)
	t.near(sim.income_per_second(&"embers").to_float(), base * (1.0 + 4.0 * 0.5), 1e-9, "slag adds a (1 + slag / 2) factor")

	# Heat only exists in zone 2
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
	sim.stats[&"embers"] = BigNum.from_float(1.0e7)
	var hot_gain: BigNum = sim.press_gain_preview(&"cinder_1")   # the preview includes Heat
	var before: float = sim.get_stat(&"cinder").to_float()
	t.ok(sim.try_press(&"cinder_1"), "press cinder_1 while Hot")
	t.near(sim.get_stat(&"cinder").to_float() - before, hot_gain.to_float(), 1e-9, "Hot press pays what the tooltip preview says")
	sim.heat = 0.0
	var cold: BigNum = sim.press_gain_preview(&"cinder_1")
	t.near(hot_gain.to_float(), cold.to_float() * z2.heat_hot_mult, 1e-9, "Hot preview is heat_hot_mult times the cold one")
	before = sim.get_stat(&"cinder").to_float()
	t.ok(sim.try_press(&"cinder_1"), "press cinder_1 while cold")
	t.near(sim.get_stat(&"cinder").to_float() - before, cold.to_float(), 1e-9, "cold press pays the base reward")

	# decay runs out, hot flips back off, rebirth and zone entry clear Heat
	sim.feed_heat(100.0)
	for i in 100:
		sim.step(0.1)
	t.ok(not sim.is_hot(), "Heat falls below the hot line")
	t.eq(hot_events.back(), false, "heat_hot_changed fired on the way down")
	sim.feed_heat(100.0)
	sim.stats[&"ingot"] = BigNum.from_float(2.0)
	t.ok(sim.try_rebirth(), "rebirth in zone 2")
	t.near(sim.heat, 0.0, 1e-9, "rebirth clears Heat")
	sim.feed_heat(100.0)
	sim.enter_zone(&"zone1")
	t.near(sim.heat, 0.0, 1e-9, "zone entry clears Heat")

	# Gate: the top row's stat opens it
	sim.enter_zone(&"zone2")
	var gate_at: float = z2.gate_threshold
	sim.stats[&"emberheart"] = BigNum.from_float(gate_at - 1.0)
	sim.step(0.1)
	t.ok(not sim.is_gate_open(&"zone2"), "zone 2 gate closed one Emberheart short")
	sim.stats[&"emberheart"] = BigNum.from_float(gate_at)
	sim.step(0.1)
	t.ok(sim.is_gate_open(&"zone2"), "zone 2 gate opens at its Emberheart threshold")

	# A save made in zone 2 loads back into zone 2 with its scene, mask and pads resolvable
	var saved: Dictionary = sim.to_dict()
	var fresh: Sim = t.make_sim()
	t.ok(fresh.from_dict(saved), "zone 2 save loads")
	t.eq(fresh.zone_id, &"zone2", "loaded save is in zone 2")
	t.ok(fresh.is_gate_open(&"zone2"), "zone 2 gate stays latched across a save")
	var lz: ZoneDef = fresh.current_zone()
	t.ok(lz != null and lz.scene_path != "" and lz.pad_buttons.size() == 18, "loaded zone has its scene and forge pads")
	fresh.heat = 0.0
	t.ok(not fresh.is_hot(), "Heat is not saved")

	# Scene, mask and anchors
	t.ok(ResourceLoader.exists(z2.scene_path), "zone 2 scene exists")
	var qscene: Node = (load(z2.scene_path) as PackedScene).instantiate()
	var qoff: Vector2i = qscene.get("mask_offset") as Vector2i
	qscene.free()
	WalkMask.use(z2.walk_mask_path, qoff)
	t.ok(WalkMask.available(), "quarry walkable.png loads")
	var im: Image = WalkMask.image()
	if im != null:
		t.eq(im.get_size(), Vector2i(1400, 760), "quarry mask matches the ground canvas")
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
	var pad_pts: Array[Vector2] = []
	for a2: Variant in data.get("anchors", []):
		var d2: Dictionary = a2 as Dictionary
		if str(d2.get("kind", "")) == "pad":
			pad_pts.append(Vector2(float(d2.get("sx", 0)), float(d2.get("sy", 0))))
	var entries: Array = data.get("row_entry", []) as Array
	t.eq(entries.size() * 3, pad_pts.size(), "one road entry per pad row")
	for r in entries.size():
		var e: Array = entries[r] as Array
		var ep := Vector2(float(e[0]), float(e[1]))
		t.ok(pad_pts[r * 3].distance_to(ep) < pad_pts[r * 3 + 1].distance_to(ep) and pad_pts[r * 3 + 1].distance_to(ep) < pad_pts[r * 3 + 2].distance_to(ep), "row %d pads are numbered 1, 2, 3 from where the road meets the row" % (r + 1))
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
		var reached: PackedByteArray = _flood(im, start, qoff)
		for tp: Vector2 in targets:
			var px: Vector2i = Vector2i(int(floorf(tp.x)) + qoff.x, int(floorf(tp.y)) + qoff.y)
			t.ok(reached[px.y * im.get_width() + px.x] == 1, "spawn connects to %s" % str(tp))
	WalkMask.use("")   # back to the meadow mask for any later suite


## Pixels of the mask reachable from `start` (a world texel) by 4-neighbour steps: 1 per reachable pixel, row by row.
func _flood(im: Image, start: Vector2, off: Vector2i) -> PackedByteArray:
	var w: int = im.get_width()
	var h: int = im.get_height()
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(w * h)
	var open: PackedByteArray = PackedByteArray()
	open.resize(w * h)
	for y in h:
		for x in w:
			open[y * w + x] = 1 if im.get_pixel(x, y).r > 0.5 else 0
	var first: Vector2i = Vector2i(int(floorf(start.x)) + off.x, int(floorf(start.y)) + off.y)
	var queue: PackedInt32Array = PackedInt32Array([first.y * w + first.x])
	seen[first.y * w + first.x] = 1
	var head: int = 0
	while head < queue.size():
		var c: int = queue[head]
		head += 1
		var cx: int = c % w
		var cy: int = c / w
		for k in 4:
			var nx: int = cx + (1 if k == 0 else (-1 if k == 1 else 0))
			var ny: int = cy + (1 if k == 2 else (-1 if k == 3 else 0))
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var n: int = ny * w + nx
			if seen[n] == 0 and open[n] == 1:
				seen[n] = 1
				queue.append(n)
	return seen
