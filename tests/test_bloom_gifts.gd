extends RefCounted
## The Bloom gifts that change how the meadow plays, and the clock of the Bloom animation.

const GIFTS: Array[StringName] = [&"bloom_head_start", &"bloom_soil", &"bloom_wide", &"bloom_dusk", &"bloom_seed_pods", &"bloom_twin_petals",
	&"bloom_petal_burst", &"bloom_stride", &"bloom_sprites", &"bloom_bramble", &"bloom_roots", &"bloom_echo", &"bloom_study", &"bloom_wildflower"]


func run(t: Object) -> void:
	var sim: Sim = t.make_sim()
	var rd: ZoneResetDef = sim.reset_defs[&"bloom"] as ZoneResetDef
	t.ok(GIFTS.size() >= 14, "at least fourteen Bloom gifts")
	for id: StringName in GIFTS:
		var a: AttributeDef = sim.attribute_defs.get(id) as AttributeDef
		t.ok(a != null and a.currency == &"seeds", "%s is a Seeds gift" % id)
		if a == null:
			continue
		t.ok(a.blurb != "" and a.unit_text != "", "%s brings its own menu text" % id)
		t.ok(ResourceLoader.exists("res://assets/icons/%s.png" % StatIndex.attr_icon(a)), "%s has an icon" % id)
		t.ok(StatIndex.effect_text(a, a.per_level).length() > 3, "%s reads as text" % id)
		t.ok(UpgradeText.state(sim, a)["next"] != "", "%s has a next value" % id)

	# Gifts open up as you Bloom.
	var pods: AttributeDef = sim.attribute_defs[&"bloom_seed_pods"]
	var wild: AttributeDef = sim.attribute_defs[&"bloom_wildflower"]
	sim.stats[&"seeds"] = BigNum.from_float(500.0)
	t.ok(sim.attr_unlocked(&"bloom_head_start"), "the first gifts are open from the start")
	t.ok(not sim.attr_unlocked(pods.id) and not sim.buy_attribute(pods.id), "Seed Pods wait for the first Bloom")
	t.eq(String(UpgradeText.state(sim, pods)["lock"]), "Unlocks after %d Bloom reset" % pods.unlock_resets, "lock text names the reset")
	sim.reset_counts[&"bloom"] = wild.unlock_resets
	t.ok(sim.attr_unlocked(wild.id) and sim.buy_attribute(wild.id), "gifts unlock by Blooms done")
	sim.reset_counts[&"bloom"] = 0
	sim.attr_levels.clear()

	# Seed Pods pay more Seeds per Bloom.
	sim.gates_open[&"larkmoor"] = true
	sim.stats[&"starbloom"] = BigNum.from_float(sim.reset_ref(&"bloom") * 4.0)
	t.eq(sim.reset_gain(&"bloom"), 4, "four times the petals pay 4 Seeds")
	sim.attr_levels[&"bloom_seed_pods"] = 10
	t.eq(sim.reset_gain(&"bloom"), int(floorf(4.0 * (1.0 + 10.0 * pods.per_level))), "Seed Pods raise the payout")
	sim.attr_levels.clear()

	# Perennial Roots keep the lowest listed flowers through a Bloom, Starbloom never.
	sim.reset_counts[&"bloom"] = 0
	sim.dev_open_tiers()
	sim.attr_levels[&"bloom_roots"] = 2
	for sid: StringName in [&"thistle", &"heather", &"foxglove"]:
		sim.stats[sid] = BigNum.from_float(1000.0)
	sim.stats[&"starbloom"] = BigNum.from_float(sim.reset_ref(&"bloom") * 4.0)
	t.ok(sim.try_reset(&"bloom"), "Bloom with Perennial Roots")
	t.near(sim.get_stat(&"thistle").to_float(), 1000.0, 1e-9, "Thistle kept at level 1")
	t.near(sim.get_stat(&"heather").to_float(), 1000.0, 1e-9, "Heather kept at level 2")
	t.ok(sim.get_stat(&"foxglove").is_zero() and sim.get_stat(&"starbloom").is_zero(), "the rest reset")
	t.ok(sim.bloom_before.has(&"foxglove") and sim.bloom_before[&"foxglove"].to_float() == 1000.0, "the stats as they were are kept for the animation")
	sim.attr_levels.clear()

	# Bloom Echo grows every Bloom's reward bonus.
	var count: int = sim.reset_count(&"bloom")
	var base: float = sim.reset_bonus()
	sim.attr_levels[&"bloom_echo"] = 5
	t.near(sim.reset_bonus(), base + float(count) * 5.0 * (sim.attribute_defs[&"bloom_echo"] as AttributeDef).per_level, 1e-9, "Bloom Echo adds to each Bloom's bonus")
	sim.attr_levels.clear()

	# Twin Petals stack with relics.
	sim.attr_levels[&"bloom_twin_petals"] = 5
	t.near(sim._double_chance(), 5.0 * (sim.attribute_defs[&"bloom_twin_petals"] as AttributeDef).per_level, 1e-9, "Twin Petals add double-press chance")
	sim.attr_levels.clear()

	# Dew Sprites press the best affordable pad on their own and pay for it; the Wildflower presses for free.
	var s2: Sim = t.make_sim()
	s2.stats[&"sunlight"] = BigNum.from_float(1000.0)
	s2.attr_levels[&"bloom_sprites"] = 5
	var seen: Array[bool] = []
	s2.button_pressed.connect(func(_id: StringName, _p: Vector3, _g: BigNum, _c: bool) -> void: seen.append(s2.auto_press_active))
	var presses0: int = s2.press_count
	for i in 8:
		s2.step(0.25)
	t.ok(s2.press_count - presses0 >= 1, "Dew Sprites press by themselves")
	t.ok(not seen.is_empty() and not seen.has(false), "an automatic press is flagged while it runs")
	t.ok(not s2.auto_press_active, "the flag is off again after")
	t.ok(s2.get_stat(&"sunlight").to_float() < 1000.0 + 100.0, "they spend the cost like a real press")
	var s3: Sim = t.make_sim()
	s3.stats[&"sunlight"] = BigNum.zero()
	s3.attr_levels[&"bloom_wildflower"] = 8
	var before: float = s3.press_count
	for i in 8:
		s3.step(0.25)
	t.ok(float(s3.press_count) > before, "the Wildflower blooms a pad with nothing in stock")
	t.ok(s3.get_stat(&"dewdrop").to_float() > 0.0, "and it pays out")

	# Wide Bloom's second effect adds to every Bloom's bonus, on top of its pad reward.
	var wide: AttributeDef = sim.attribute_defs[&"bloom_wide"]
	sim.reset_counts[&"bloom"] = 3
	sim.attr_levels[&"bloom_wide"] = 4
	t.near(sim.effect_total(&"bloom_bonus"), 4.0 * wide.per_level2, 1e-9, "Wide Bloom's second effect reaches the Bloom bonus")
	t.near(sim.reset_bonus(), 3.0 * ((sim.reset_defs[&"bloom"] as ZoneResetDef).bonus_per_use + 4.0 * wide.per_level2), 1e-9, "each Bloom carries it")
	t.near(sim.effect_total(&"pad_yield"), 4.0 * wide.per_level, 1e-9, "and the first effect still pays on presses")
	sim.attr_levels.clear()
	sim.reset_counts[&"bloom"] = 0

	# Twin Petals can proc: a press pays out several times over, and the chance grows with each level.
	var twin: AttributeDef = sim.attribute_defs[&"bloom_twin_petals"]
	sim.attr_levels[&"bloom_twin_petals"] = 10
	t.near(sim.effect_total(&"press_proc"), 10.0 * twin.per_level2, 1e-9, "Twin Petals' proc chance")
	sim.attr_levels.clear()
	t.near(Formulas.proc_mult(0.0, 0.5, 5.0), 5.0, 1e-9, "a roll under the chance pays the proc multiple")
	t.near(Formulas.proc_mult(0.9, 0.5, 5.0), 1.0, 1e-9, "a roll over the chance pays the press as normal")
	t.near(Formulas.proc_mult(0.0, 0.0, 5.0), 1.0, 1e-9, "no chance, no proc")
	# The second effect reads on the card and in the tooltip, not only in the blurb.
	t.eq(UpgradeText.second_value(twin, 10, 5.0), "5% for 5x", "Twin Petals' card line names the proc and its payout")
	t.eq(UpgradeText.second_value(wide, 10, 5.0), "+10% a Bloom", "Wide Bloom's card line reads per Bloom")
	t.eq(UpgradeText.second_value(sim.attribute_defs[&"bloom_head_start"], 3, 5.0), "", "a gift with one effect has no second line")
	t.ok(UpgradeText.second_sentence(wide, 4, 5.0).begins_with("Also now"), "the tooltip sentence says now and next")
	t.ok(UpgradeText.state(sim, wide)["second_now"] == "+0% a Bloom", "the state carries the second effect")
	t.eq(UpgradeText.second_short(twin, 10, 5.0), "5% for 5x", "the card's second line for Twin Petals")
	t.eq(UpgradeText.second_short(wide, 10, 5.0), "+10%/Bloom", "the card's second line for Wide Bloom")
	t.ok(str(UpgradeText.tip(UpgradeText.state(sim, wide), &"pad_yield")["body"]).contains("Also now"), "the Upgrades tooltip names the second effect")


	# The pure pieces: the HUD countdown clock and the animation timeline.
	t.near(RollValue.timed_progress(0.0, 1.4), 0.0, 1e-9, "a countdown starts at the old value")
	t.near(RollValue.timed_progress(1.4, 1.4), 1.0, 1e-9, "and lands exactly at its span")
	t.ok(RollValue.timed_progress(0.7, 1.4) > 0.3 and RollValue.timed_progress(0.7, 1.4) < 0.7, "mid-way is mid-way")
	var rv := RollValue.new()
	rv.set_target(BigNum.from_float(1000.0))
	rv.countdown(BigNum.from_float(1000.0), 1.4)
	rv.set_target(BigNum.zero())
	t.ok(rv.timed() and rv.text == BigNum.from_float(1000.0).format(), "a counting row keeps its old number until it runs")
	rv.free()
	for calm: bool in [false, true]:
		var p: Dictionary = BloomTimeline.plan(calm)
		t.ok(float(p["charge"]) < float(p["burst"]) and float(p["burst"]) < float(p["up_end"]) and float(p["up_end"]) < float(p["hold_end"]) and float(p["hold_end"]) < float(p["fly_end"]) and float(p["fly_end"]) < float(p["total"]), "timeline is in order (calm %s)" % calm)
		t.ok(float(p["total"]) < 6.0, "the whole animation stays under six seconds")
		t.eq(BloomTimeline.number_at(37, 0.0, p), 0, "the number starts at 0")
		t.eq(BloomTimeline.number_at(37, float(p["up_end"]), p), 37, "and lands on the Seeds earned")
		var last: int = 0
		var monotone: bool = true
		var tt: float = 0.0
		while tt < float(p["total"]):
			var n: int = BloomTimeline.number_at(37, tt, p)
			monotone = monotone and n >= last
			last = n
			tt += 0.02
		t.ok(monotone, "the number only climbs")
		t.eq(BloomTimeline.icon_scale(float(p["burst"]) - 0.01, p), 0, "no icon before the burst")
		t.eq(BloomTimeline.icon_scale(float(p["up_end"]), p), BloomTimeline.SETTLED_SCALE, "the icon settles at a whole pixel scale")
		t.eq(BloomTimeline.icon_scale(float(p["fly_end"]) + 0.01, p), 0, "and is gone at the end of the exit")
		t.eq(BloomTimeline.icon_scale(float(p["hold_end"]) + 0.01, p), BloomTimeline.SETTLED_SCALE if calm else BloomTimeline.EXIT_SCALES[0], "the exit starts by stepping the coin down in place")
		t.near(BloomTimeline.exit_alpha(float(p["hold_end"]), p), 1.0, 1e-9, "the number is fully shown until the exit")
		t.near(BloomTimeline.exit_alpha(float(p["fly_end"]), p), 0.0, 1e-9, "and fades out by the end of it")
		var steps_down: bool = true
		var last_scale: int = 99
		var tx: float = float(p["hold_end"])
		while tx < float(p["fly_end"]):
			var sc: int = BloomTimeline.icon_scale(tx, p)
			steps_down = steps_down and sc <= last_scale
			last_scale = sc
			tx += 0.01
		t.ok(steps_down, "the exit only ever steps the coin smaller (calm %s)" % calm)
		if calm:
			var still: bool = true
			var tc: float = float(p["hold_end"])
			while tc < float(p["fly_end"]):
				still = still and BloomTimeline.icon_scale(tc, p) == BloomTimeline.SETTLED_SCALE
				tc += 0.02
			t.ok(still, "calm keeps the coin still through its fade")
		t.near(BloomTimeline.veil_at(float(p["total"]), p), 0.0, 1e-9, "the veil is gone at the end")
		t.near(BloomTimeline.flash_at(float(p["burst"]) + 1.0, p), 0.0, 1e-9, "the flash is brief")
	t.near(float(BloomTimeline.plan(false)["count"]), float(BloomTimeline.COUNT), 1e-9, "the countdown span matches the timeline")
	t.ok(rd.keep_effect == &"keep_flowers" and rd.pay_effect == &"seed_pay" and rd.bonus_effect == &"bloom_bonus", "Bloom's def names its gift effects")
