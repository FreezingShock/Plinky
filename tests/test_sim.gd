extends RefCounted

func _press_all(sim: Sim, id: StringName, n: int) -> void:
	for i in n:
		sim.try_press(id)

func run(t: Object) -> void:
	var sim: Sim = t.make_sim()
	t.eq(sim.zone_id, &"zone1", "starts in zone 1")
	# income: 0.25 per second at mult 0, prestige 0
	t.near(sim.income_per_second(&"cash").to_float(), 0.25, 1e-9, "base income")
	for i in 400:
		sim.step(0.1)  # 40 s
	t.near(sim.get_stat(&"cash").to_float(), 10.0, 1e-6, "40 s of income is 10 cash")
	t.ok(sim.can_afford(&"m1"), "m1 affordable at 10 cash")
	t.ok(not sim.can_afford(&"m2"), "m2 not affordable")
	var seen: Array = []
	sim.button_pressed.connect(func(id: StringName, _p: Vector3, g: BigNum, c: bool) -> void: seen.append([id, g.to_float(), c]))
	t.ok(sim.try_press(&"m1"), "press m1")
	t.eq(seen.size(), 1, "button_pressed emitted once")
	t.near(sim.get_stat(&"mult").to_float(), 1.0, 1e-9, "m1 gives +1 mult")
	t.near(sim.get_stat(&"cash").to_float(), 0.0, 1e-6, "cost spent")
	t.near(sim.income_per_second(&"cash").to_float(), 0.5, 1e-9, "income doubles with 1 mult")
	var denied: Array = []
	sim.button_denied.connect(func(id: StringName) -> void: denied.append(id))
	t.ok(not sim.try_press(&"m2"), "unaffordable press fails")
	t.eq(denied.size(), 1, "button_denied emitted")
	t.ok(not sim.try_press(&"nope"), "unknown button fails quietly")

	# Rebirths boost Multiplier gain only, not cash income directly
	sim.new_game()
	sim.stats[&"cash"] = BigNum.from_float(10.0)
	sim.stats[&"reb"] = BigNum.from_float(2.0)
	sim.try_press(&"m1")
	t.near(sim.get_stat(&"mult").to_float(), 3.0, 1e-9, "m1 reward x (1 + rebirths)")
	t.near(sim.income_per_second(&"cash").to_float(), 0.25 * 4.0, 1e-9, "income = base x (1 + mult), no direct rebirth factor")

	# Gate latches at 9 rebirths and survives rebirth
	sim.new_game()
	var gate_events: Array = []
	sim.gate_opened.connect(func(id: StringName) -> void: gate_events.append(id))
	sim.stats[&"reb"] = BigNum.from_float(8.0)
	sim.step(0.1)
	t.ok(not sim.is_gate_open(&"zone1"), "gate closed at 8")
	sim.stats[&"reb"] = BigNum.from_float(9.0)
	sim.step(0.1)
	t.ok(sim.is_gate_open(&"zone1"), "gate opens at 9")
	t.eq(gate_events.size(), 1, "gate_opened once")
	sim.step(0.1)
	t.eq(gate_events.size(), 1, "gate_opened does not repeat")
	t.ok(sim.enter_zone(&"zone2"), "can enter zone 2 after the gate opens")
	t.eq(sim.zone_id, &"zone2", "now in zone 2")
	t.ok(sim.enter_zone(&"zone1"), "can go back to zone 1")

	# Rebirth: resets, banks prestige, formula 1 + p^0.8
	var done: Array = []
	sim.rebirth_done.connect(func(p: BigNum) -> void: done.append(p.to_float()))
	sim.stats[&"cash"] = BigNum.from_float(500.0)
	sim.stats[&"mult"] = BigNum.from_float(77.0)
	t.ok(sim.try_rebirth(), "rebirth at reb 9")
	t.near(sim.get_stat(&"prestige").to_float(), 9.0, 1e-9, "prestige gained = reb at reset")
	t.near(sim.get_stat(&"cash").to_float(), 0.0, 1e-9, "cash reset")
	t.near(sim.get_stat(&"mult").to_float(), 0.0, 1e-9, "mult reset")
	t.near(sim.get_stat(&"reb").to_float(), 0.0, 1e-9, "reb reset")
	t.ok(sim.is_gate_open(&"zone1"), "gate stays open")
	t.near(sim.prestige_mult().to_float(), 1.0 + pow(9.0, 0.8), 1e-9, "prestige_mult")
	t.near(sim.income_per_second(&"cash").to_float(), 0.25 * (1.0 + pow(9.0, 0.8)), 1e-9, "income uses prestige_mult")
	t.eq(done.size(), 1, "rebirth_done emitted")
	t.ok(not sim.try_rebirth(), "no rebirth at reb 0")

	# Attributes spend available prestige without lowering prestige_mult
	var pm_before: float = sim.prestige_mult().to_float()
	t.ok(sim.buy_attribute(&"press_rate"), "buy press rate level 1")
	t.near(sim.prestige_mult().to_float(), pm_before, 1e-12, "spending prestige keeps the multiplier")
	t.near(sim.prestige_available().to_float(), 9.0 - 3.0, 1e-9, "available prestige drops by cost")
	t.near(sim.press_interval(), 1.0 / (0.5 * 1.1), 1e-9, "press rate +10 percent")
	sim.new_game()
	t.ok(not sim.buy_attribute(&"press_rate"), "cannot buy with no prestige")

	# Offline progress is capped at 2 h
	sim.new_game()
	t.near(sim.apply_offline(10.0 * 3600.0), 7200.0, 1e-9, "offline capped at 2 h")
	t.near(sim.get_stat(&"cash").to_float(), 0.25 * 7200.0, 1e-6, "offline cash")

	# Crit: with crit chance 100 percent the gain is 5x
	sim.new_game()
	sim.attr_levels[&"crit_chance"] = 25
	t.near(sim.crit_chance(), 0.25, 1e-9, "25 levels is 25 percent")
	sim.attr_levels[&"crit_chance"] = 1000  # cap check lives in from_dict; force 100 percent via effect
	sim.stats[&"cash"] = BigNum.from_float(10.0)
	sim.try_press(&"m1")
	t.near(sim.get_stat(&"mult").to_float(), 5.0, 1e-9, "guaranteed crit is x5")
	sim.attr_levels.clear()

	# Content sanity: every button points at real stats and zones
	t.eq(sim.validate().size(), 0, "content validates")
