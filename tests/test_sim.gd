extends RefCounted

func _press_all(sim: Sim, id: StringName, n: int) -> void:
	for i in n:
		sim.try_press(id)

func run(t: Object) -> void:
	var sim: Sim = t.make_sim()
	t.eq(sim.zone_id, &"zone1", "starts in zone 1")
	# income: 0.25 per second at mult 0, prestige 0
	t.near(sim.income_per_second(&"sunlight").to_float(), 0.25, 1e-9, "base income")
	for i in 400:
		sim.step(0.1)  # 40 s
	t.near(sim.get_stat(&"sunlight").to_float(), 20.0, 1e-6, "start 10 plus 40 s of income (10) is 20 cash")
	t.ok(sim.can_afford(&"sprout_1"), "m1 affordable at 10 cash")
	t.ok(not sim.can_afford(&"sprout_2"), "m2 not affordable")
	var seen: Array = []
	sim.button_pressed.connect(func(id: StringName, _p: Vector3, g: BigNum, c: bool) -> void: seen.append([id, g.to_float(), c]))
	t.ok(sim.try_press(&"sprout_1"), "press m1")
	t.eq(seen.size(), 1, "button_pressed emitted once")
	t.near(sim.get_stat(&"dewdrop").to_float(), 1.0, 1e-9, "m1 gives +1 mult")
	t.near(sim.get_stat(&"sunlight").to_float(), 10.0, 1e-6, "cost spent")
	t.near(sim.income_per_second(&"sunlight").to_float(), 0.5, 1e-9, "income doubles with 1 mult")
	var denied: Array = []
	sim.button_denied.connect(func(id: StringName) -> void: denied.append(id))
	t.ok(not sim.try_press(&"sprout_2"), "unaffordable press fails")
	t.eq(denied.size(), 1, "button_denied emitted")
	t.ok(not sim.try_press(&"nope"), "unknown button fails quietly")

	# Rebirths boost Multiplier gain only, not cash income directly
	sim.new_game()
	sim.stats[&"sunlight"] = BigNum.from_float(10.0)
	sim.stats[&"clover"] = BigNum.from_float(2.0)
	sim.try_press(&"sprout_1")
	t.near(sim.get_stat(&"dewdrop").to_float(), 3.0, 1e-9, "m1 reward x (1 + rebirths)")
	t.near(sim.income_per_second(&"sunlight").to_float(), 0.25 * 4.0, 1e-9, "income = base x (1 + mult), no direct rebirth factor")

	# Gate latches at 9 rebirths and survives rebirth
	sim.new_game()
	var gate_events: Array = []
	sim.gate_opened.connect(func(id: StringName) -> void: gate_events.append(id))
	sim.stats[&"clover"] = BigNum.from_float(8.0)
	sim.step(0.1)
	t.ok(not sim.is_gate_open(&"zone1"), "gate closed at 8")
	sim.stats[&"clover"] = BigNum.from_float(9.0)
	sim.step(0.1)
	t.ok(sim.is_gate_open(&"zone1"), "gate opens at 9")
	t.eq(gate_events.size(), 1, "gate_opened once")
	sim.step(0.1)
	t.eq(gate_events.size(), 1, "gate_opened does not repeat")
	t.ok(not sim.enter_zone(&"zone2"), "zone 2 is not behind the onboarding gate")
	t.ok(sim.enter_zone(&"larkmoor"), "the onboarding gate leads to Larkmoor")
	t.eq(sim.zone_id, &"larkmoor", "now in Larkmoor")
	t.ok(sim.enter_zone(&"zone1"), "can go back to the onboarding meadow")

	# Rebirth: resets, banks prestige, formula 1 + p^0.8
	var done: Array = []
	sim.rebirth_done.connect(func(p: BigNum) -> void: done.append(p.to_float()))
	sim.stats[&"sunlight"] = BigNum.from_float(500.0)
	sim.stats[&"dewdrop"] = BigNum.from_float(77.0)
	t.ok(sim.try_rebirth(), "rebirth at reb 9")
	t.near(sim.get_stat(&"prestige").to_float(), 9.0, 1e-9, "prestige gained = reb at reset")
	t.near(sim.get_stat(&"sunlight").to_float(), 10.0, 1e-9, "cash resets to its start of 10")
	t.near(sim.get_stat(&"dewdrop").to_float(), 0.0, 1e-9, "mult reset")
	t.near(sim.get_stat(&"clover").to_float(), 0.0, 1e-9, "reb reset")
	t.ok(sim.is_gate_open(&"zone1"), "gate stays open")
	t.near(sim.prestige_mult().to_float(), 1.0 + pow(9.0, 0.8), 1e-9, "prestige_mult")
	t.near(sim.income_per_second(&"sunlight").to_float(), 0.25 * (1.0 + pow(9.0, 0.8)), 1e-9, "income uses prestige_mult")
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
	_offline_extras(t)
	sim.config.offline_tend_fraction = 0.0   # the plain income check below is about passive cash only
	sim.config.offline_relic_roll_fraction = 0.0
	t.near(sim.apply_offline(10.0 * 3600.0), 7200.0, 1e-9, "offline capped at 2 h")
	t.near(sim.get_stat(&"sunlight").to_float(), 10.0 + 0.25 * 7200.0, 1e-6, "offline cash (10 start plus 2 h of income)")

	# Crit: with crit chance 100 percent the gain is 5x
	sim.new_game()
	sim.attr_levels[&"crit_chance"] = 25
	t.near(sim.crit_chance(), 0.25, 1e-9, "25 levels is 25 percent")
	sim.attr_levels[&"crit_chance"] = 1000  # cap check lives in from_dict; force 100 percent via effect
	sim.stats[&"sunlight"] = BigNum.from_float(10.0)
	sim.try_press(&"sprout_1")
	t.near(sim.get_stat(&"dewdrop").to_float(), 5.0, 1e-9, "guaranteed crit is x5")
	sim.attr_levels.clear()

	# Content sanity: every button points at real stats and zones
	t.eq(sim.validate().size(), 0, "content validates")

	# Relics: an equipped cash relic raises income; rebirths unlock slots; save keeps them
	sim.new_game()
	sim.relics.add_relic(&"r_cash", 3)
	t.ok(sim.relics.equip(&"r_cash"), "equip cash relic")
	var expect: float = 0.25 * (1.0 + sim.relics.total_effect(RelicDef.Effect.CASH_MULT))
	t.near(sim.income_per_second(&"sunlight").to_float(), expect, 1e-9, "cash relic multiplies income")
	t.ok(expect > 0.25, "cash relic actually adds something")
	sim.relics.unequip(&"r_cash")
	t.near(sim.income_per_second(&"sunlight").to_float(), 0.25, 1e-9, "unequipped relic does nothing")
	sim.stats[&"clover"] = BigNum.from_float(1.0)
	sim.try_rebirth()
	t.eq(sim.rebirth_count, 1, "rebirth_count increments")
	t.eq(sim.relics.rebirths, 1, "relic inventory told about the rebirth")

	# Relic drops: one roll per roll_interval, guaranteed first drop, pity timer
	sim.new_game()
	sim.rng.seed = 7
	sim.relics.config.base_drop_chance = 0.0  # only the guarantees can drop anything
	sim.stats[&"sunlight"] = BigNum.from_float(1000000.0)
	for i in 50:
		sim.try_press(&"sprout_1")  # 50 presses at play time 0: one roll at most, and it is not due yet
	t.eq(sim.relic_drops, 0, "no drop before first_drop_seconds")
	sim.play_seconds = sim.relics.config.first_drop_seconds + 1.0
	for i in 50:
		sim.try_press(&"sprout_1")
	t.eq(sim.relic_drops, 1, "first drop is guaranteed, and one roll per interval caps a press burst at one")
	sim.play_seconds += sim.relics.config.pity_seconds + 1.0
	sim.try_press(&"sprout_1")
	t.eq(sim.relic_drops, 2, "pity timer forces a drop")
	sim.relics.config.base_drop_chance = 0.015

	# Rebirth payoff grows past the push threshold: gain = reb * (reb / 9) ^ 0.5
	sim.new_game()
	sim.stats[&"clover"] = BigNum.from_float(9.0)
	t.near(sim.prestige_gain_preview().to_float(), 9.0, 1e-9, "no bonus at the threshold")
	sim.stats[&"clover"] = BigNum.from_float(36.0)
	t.near(sim.prestige_gain_preview().to_float(), 36.0 * 2.0, 1e-9, "reb 36 pays 36 x sqrt(4)")
	sim.try_rebirth()
	t.near(sim.get_stat(&"prestige").to_float(), 72.0, 1e-9, "rebirth banks the boosted gain")

	# Momentum: walking charges it, income follows, time drains it, 1.0 is the cap
	sim.new_game()
	sim.feed_momentum(100.0)
	t.near(sim.momentum, 0.55, 1e-9, "100 texels is 0.55 momentum")
	t.eq(sim.momentum_tier(), 2, "0.55 momentum is stage 2, Rhythm")
	t.near(sim.momentum_bonus(), 0.55 * 0.28 + 0.01 + 0.02, 1e-6, "bonus is the smooth part plus stage kickers")
	t.near(sim.income_per_second(&"sunlight").to_float(), 0.25 * (1.0 + sim.momentum_bonus()), 1e-9, "momentum raises income")
	sim.step(1.0)
	t.near(sim.momentum, 0.55, 1e-9, "momentum holds through the grace window")
	sim.step(1.2)
	sim.step(1.0)
	t.near(sim.momentum, 0.45, 1e-9, "after the hold it drains 0.1 per second")
	sim.feed_momentum(10000.0)
	t.near(sim.momentum, 1.0, 1e-9, "momentum caps at 1")
	t.eq(sim.momentum_tier(), 4, "full is Surge")
	t.near(sim.momentum_bonus(), 0.4, 1e-6, "a full bar is still +40%")
	sim.step(3.9)
	t.near(sim.momentum, 1.0, 1e-9, "Surge holds longer")
	sim.new_game()
	sim.feed_press_momentum(false)
	t.near(sim.momentum, 0.01, 1e-9, "a press adds a little")
	sim.feed_press_momentum(true)
	t.near(sim.momentum, 0.07, 1e-9, "a crit press adds more")

	# Pad streak: m1, m2, m3 in order pays 5 s of income, then waits out the cooldown
	sim.new_game()
	var bonuses: Array = []
	sim.bonus_gained.connect(func(k: StringName, _g: Dictionary) -> void: bonuses.append(k))
	sim.stats[&"sunlight"] = BigNum.from_float(1000000.0)
	sim.try_press(&"sprout_1")
	sim.try_press(&"sprout_2")
	t.eq(bonuses.size(), 0, "no bonus before the row is finished")
	sim.try_press(&"sprout_3")
	t.eq(bonuses, [&"streak"], "m1, m2, m3 in order pays a streak")
	sim.try_press(&"sprout_1")
	sim.try_press(&"sprout_2")
	sim.try_press(&"sprout_3")
	t.eq(bonuses.size(), 1, "cooldown blocks a second streak")
	sim.new_game()
	sim.stats[&"sunlight"] = BigNum.from_float(1000000.0)
	sim.try_press(&"sprout_1")
	sim.try_press(&"sprout_3")
	sim.try_press(&"sprout_2")
	t.eq(bonuses.size(), 1, "out of order is not a streak")

	# Golden critter: spawns on a timer, pays 30 s of income when caught
	sim.new_game()
	t.ok(not sim.catch_critter(), "nothing to catch yet")
	var spawned: Array = []
	sim.critter_spawned.connect(func() -> void: spawned.append(true))
	for i in 1600:
		sim.step(0.1)  # 160 s is past the longest spawn delay
		if sim.critter_active:
			break
	t.ok(sim.critter_active and spawned.size() == 1, "critter appears within 150 s")
	var before: float = sim.get_stat(&"sunlight").to_float()
	var inc: float = sim.income_per_second(&"sunlight").to_float()
	t.ok(sim.catch_critter(), "catch the critter")
	t.near(sim.get_stat(&"sunlight").to_float() - before, inc * 30.0, 1e-6, "critter pays 30 s of income")
	t.ok(not sim.critter_active, "critter gone after the catch")
	sim.new_game()
	for i in 3000:
		sim.step(0.1)
	t.ok(sim.critter_left <= sim.config.critter_lifetime, "an uncaught critter times out and the next one is scheduled")


## Offline catch-up v2: tending spends and earns like presses, mastery follows, relic rolls are capped.
func _offline_extras(t: Object) -> void:
	var sim: Sim = t.make_sim()
	sim.stats[&"sunlight"] = BigNum.from_float(1000.0)
	var before_dew: float = sim.get_stat(&"dewdrop").to_float()
	sim.apply_offline(3600.0)
	var tend: Dictionary = sim.last_offline["tend"]
	t.ok(tend.has(&"sprout"), "offline tends the open Sprout pad")
	t.ok(sim.get_stat(&"dewdrop").to_float() > before_dew, "tending paid Dewdrops")
	t.ok(sim.mastery.level(&"sprout_3") > 0 or sim.mastery.xp(&"sprout_3") > 0.0, "tending earned mastery XP")
	t.ok(not tend.has(&"clover"), "locked tiers are not tended")
	t.ok((sim.last_offline["relics"] as Array).size() <= sim.config.offline_relic_max_drops, "relic drops capped")
	var sim3: Sim = t.make_sim()
	sim3.attr_levels[&"bloom_dusk"] = 4
	sim3.attr_levels[&"rp_rest"] = 2
	var per_dusk: float = (sim3.attribute_defs[&"bloom_dusk"] as AttributeDef).per_level
	var per_rest: float = (sim3.attribute_defs[&"rp_rest"] as AttributeDef).per_level
	t.near(sim3.offline_cap_seconds(), (sim3.config.offline_base_cap_hours + 4.0 * per_dusk + 2.0 * per_rest) * 3600.0, 1e-6, "Long dusk and Deep sleep stack on the offline cap")
	var flat: Sim = t.make_sim()
	flat.stats[&"sunlight"] = BigNum.from_float(1000.0)
	flat.config.offline_tend_fraction = 0.0
	flat.apply_offline(3600.0)
	t.ok(sim.get_stat(&"sunlight").to_float() >= 0.0 and (sim.last_offline["tend"] as Dictionary).size() > 0, "tending ran in slices")
	t.ok(flat.get_stat(&"dewdrop").to_float() <= before_dew, "no tending, no Dewdrops")
	t.ok((sim.last_offline["spent"] as Dictionary).has(&"sunlight"), "tending records the Sunlight it spent")
	var live: Sim = t.make_sim()
	live.stats[&"dewdrop"] = BigNum.from_float(5.0)
	live.stats[&"sunlight"] = BigNum.zero()
	live.config.offline_tend_fraction = 0.0
	var live_rate: float = live.income_per_second(&"sunlight").to_float()
	live.apply_offline(3600.0)
	t.near(live.get_stat(&"sunlight").to_float() / 3600.0 / live_rate, 1.0, 1e-9, "offline Sunlight rate equals the live rate (idle factor 1, no momentum at load)")
	t.ok(live_rate > 0.25 * 5.0, "Dewdrops boost the rate offline uses")
	var sim2: Sim = t.make_sim()
	sim2.stats[&"sunlight"] = BigNum.zero()
	sim2.config.offline_tend_fraction = 0.0
	sim2.config.offline_relic_roll_fraction = 0.0
	sim2.apply_offline(3600.0)
	t.ok((sim2.last_offline["tend"] as Dictionary).is_empty() and (sim2.last_offline["relics"] as Array).is_empty(), "extras switch off")
