extends RefCounted
## The flower tiers (two in the meadow, six in Larkmoor): unlock chain, zone scoping, zone arrival grants, and the move from the old Cash / Multiplier / Rebirth save.


func run(t: Object) -> void:
	var sim: Sim = t.make_sim()
	t.eq(sim.tiers_in_zone(&"zone1").size() + sim.tiers_in_zone(&"larkmoor").size(), 8, "eight flower tiers: two in the meadow, six in Larkmoor")
	t.eq(sim.tiers_in_zone(&"zone2").size(), 6, "six forge tiers")
	t.ok(sim.is_tier_open(&"sprout"), "the first tier of a zone is open from the start")
	t.ok(not sim.is_tier_open(&"clover"), "Clover starts locked")
	t.ok(sim.is_pad_locked(&"clover_1"), "its pads are locked")
	sim.stats[&"dewdrop"] = BigNum.from_float(1.0e6)
	t.ok(not sim.can_afford(&"clover_1"), "a locked pad cannot be bought even with the stock")

	# pressing the last pad of a tier once opens the next
	sim.stats[&"sunlight"] = BigNum.from_float(1.0e6)
	t.ok(sim.try_press(&"sprout_1"), "press Sprout 1")
	t.ok(not sim.is_tier_open(&"clover"), "the first pad does not open the next tier")
	t.ok(sim.try_press(&"sprout_3"), "press the last Sprout pad")
	t.ok(sim.is_tier_open(&"clover"), "the last pad opens Clover")
	t.ok(not sim.is_pad_locked(&"clover_1"), "Clover pads unlock")

	# a stat outside its zone earns nothing
	sim.stats[&"thistle"] = BigNum.from_float(5.0)
	t.ok(sim.income_per_second(&"thistle").is_zero(), "Thistle Down is not a meadow stat")

	# the save round-trips the unlocked tiers
	var sim2: Sim = t.make_sim()
	t.ok(sim2.from_dict(sim.to_dict()), "load")
	t.ok(sim2.is_tier_open(&"clover"), "tiers_open survives a save")

	# an old save (Cash / Multiplier / Rebirths) moves onto the ladder
	var old: Dictionary = sim.to_dict()
	old.erase("ladder")
	old.erase("tiers")
	old["stats"] = {"cash": 500.0, "mult": 7.0, "reb": 2.0}
	var sim3: Sim = t.make_sim()
	t.ok(sim3.from_dict(old), "load an old save")
	t.near(sim3.get_stat(&"sunlight").to_float(), 500.0, 1e-6, "old Cash becomes Sunlight")
	t.near(sim3.get_stat(&"dewdrop").to_float(), 7.0, 1e-6, "old Multiplier becomes Dewdrops")
	t.near(sim3.get_stat(&"clover").to_float(), 2.0, 1e-6, "old Rebirths become Clover Leaves")

	# higher tiers buff several lower stats at once (data: buff_stats and buff_factor)
	var sim4: Sim = t.make_sim()
	t.near(sim4.buff_factor_for(&"dewdrop"), 1.0, 1e-9, "no buff before any higher stat is held")
	sim4.stats[&"thistle"] = BigNum.from_float(1.0)
	t.near(sim4.buff_factor_for(&"dewdrop"), 1.25, 1e-9, "Thistle Down buffs Dewdrops by 1.25x")
	t.near(sim4.buff_factor_for(&"thistle"), 1.0, 1e-9, "a stat does not buff itself")
	sim4.stats[&"starbloom"] = BigNum.from_float(5.0)
	t.near(sim4.buff_factor_for(&"dewdrop"), 1.25 * 1.5, 1e-9, "buffs from different stats stack")
	NumberFormat.mult_style = NumberFormat.MultStyle.PERCENT
	t.eq(NumberFormat.mult_f(1.5), "150%", "percent display")
	NumberFormat.mult_style = NumberFormat.MultStyle.FACTOR
	t.eq(NumberFormat.mult_f(1.5), "x1.5", "factor display")
