extends RefCounted
## Bloom: the meadow's reset. Opens with the Larkmoor gate, pays Seeds, resets the flower stats, keeps everything else.


func run(t: Object) -> void:
	var sim: Sim = t.make_sim()
	var cfg: GameConfig = sim.config
	t.ok(sim.stat_defs.has(&"seeds"), "seeds stat is loaded")
	t.ok(ResourceLoader.exists("res://assets/icons/seeds.png") and ResourceLoader.exists("res://assets/icons/big/seeds.png"), "Seeds icons exist")
	t.ok(not sim.can_bloom(), "no Bloom at the start")
	t.eq(sim.bloom_gain_preview(), 0, "no preview before the gate")

	# Needs the gate and the first payout of the source stat.
	sim.stats[&"starbloom"] = BigNum.from_float(sim.bloom_ref())
	t.ok(not sim.can_bloom(), "Starbloom alone is not enough, the gate must be open")
	sim.gates_open[&"larkmoor"] = true
	t.eq(sim.bloom_gain_preview(), 2, "the gate's worth of Starbloom Petals pays 2 Seeds")
	sim.stats[&"starbloom"] = BigNum.from_float(sim.bloom_ref() * 4.0)
	t.eq(sim.bloom_gain_preview(), 4, "four times the petals pay double")
	sim.stats[&"starbloom"] = BigNum.from_float(sim.bloom_ref() * 0.5)
	t.ok(not sim.can_bloom(), "too few petals pay nothing")

	# A Bloom resets the flowers and keeps the rest.
	sim.stats[&"starbloom"] = BigNum.from_float(sim.bloom_ref())
	sim.stats[&"clover"] = BigNum.from_float(40.0)
	sim.stats[&"rp"] = BigNum.from_float(3.0)
	sim.stats[&"prestige"] = BigNum.from_float(12.0)
	sim.dev_open_tiers()
	var reward_before: float = sim.pad_yield_mult()
	var done: Array = []
	sim.bloom_done.connect(func(n: int) -> void: done.append(n))
	t.ok(sim.try_bloom(), "Bloom")
	t.eq(done, [2], "bloom_done carries the Seeds paid")
	t.near(sim.get_stat(&"seeds").to_float(), 2.0, 1e-9, "Seeds paid")
	t.ok(sim.get_stat(&"starbloom").is_zero() and sim.get_stat(&"clover").is_zero(), "flower stats reset")
	t.near(sim.get_stat(&"sunlight").to_float(), (sim.stat_defs[&"sunlight"] as StatDef).start, 1e-9, "Sunlight back to its start")
	t.near(sim.get_stat(&"rp").to_float(), 3.0, 1e-9, "Rebirth Points kept")
	t.near(sim.get_stat(&"prestige").to_float(), 12.0, 1e-9, "old Prestige kept")
	t.ok(sim.gates_open.get(&"larkmoor", false) and sim.is_tier_open(&"starbloom"), "gates and open tiers kept")
	t.eq(sim.bloom_count, 1, "Bloom counted")
	t.near(sim.pad_yield_mult(), reward_before + cfg.bloom_reward_per_bloom, 1e-9, "each Bloom adds to every pad's reward")
	t.ok(not sim.try_bloom(), "no second Bloom straight away")

	# Rebirth is for the zones that run it.
	sim.zone_id = &"zone1"
	t.ok(not sim.rebirth_here(), "the meadow does not show Rebirth")
	t.ok(not UpgradeText.group_shown(sim, &"prestige"), "Prestige upgrades hide in the meadow")
	t.ok(UpgradeText.group_shown(sim, &"seeds"), "Bloom gifts show after a Bloom")
	sim.zone_id = &"zone2"
	t.ok(sim.rebirth_here(), "Zone 2 runs Rebirth")

	# Gifts cost Seeds, not Prestige, and do what they say.
	var gift: AttributeDef = sim.attribute_defs[&"bloom_head_start"]
	t.eq(gift.currency, &"seeds", "gifts are paid in Seeds")
	sim.stats[&"seeds"] = BigNum.from_float(10.0)
	var prestige_before: float = sim.prestige_available().to_float()
	var cost: float = sim.attribute_cost(&"bloom_head_start").to_float()
	t.ok(sim.buy_attribute(&"bloom_head_start"), "buy Head start")
	t.near(sim.get_stat(&"seeds").to_float(), 10.0 - cost, 1e-9, "Seeds drop by the cost")
	t.near(sim.prestige_available().to_float(), prestige_before, 1e-9, "Prestige untouched")
	t.near(sim.bloom_start_sunlight().to_float(), (sim.stat_defs[&"sunlight"] as StatDef).start + gift.per_level, 1e-9, "Head start adds Sunlight")
	sim.stats[&"seeds"] = BigNum.zero()
	t.ok(not sim.buy_attribute(&"bloom_soil"), "no Seeds, no gift")
	t.eq(UpgradeText.ordered(sim).back().currency, &"seeds", "Bloom gifts list last")

	var soil: AttributeDef = sim.attribute_defs[&"bloom_soil"]
	sim.zone_id = &"zone1"
	var base_inc: float = sim.income_per_second(&"sunlight").to_float()
	sim.attr_levels[&"bloom_soil"] = 2
	t.near(sim.income_per_second(&"sunlight").to_float(), base_inc * (1.0 + 2.0 * soil.per_level), base_inc * 1e-6, "Deep soil boosts Sunlight income")

	# Save round trip.
	sim.stats[&"seeds"] = BigNum.from_float(5.0)
	var back: Sim = t.make_sim()
	back.from_dict(SaveCodec.decode(SaveCodec.encode(sim, 0.0))["game"])
	t.eq(back.bloom_count, 1, "Bloom count survives save and load")
	t.near(back.get_stat(&"seeds").to_float(), 5.0, 1e-9, "Seeds survive save and load")
	var old: Dictionary = sim.to_dict()
	old.erase("bloom_count")
	back.from_dict(old)
	t.eq(back.bloom_count, 0, "a save from before Bloom starts at 0")

	# UI text knows Seeds.
	t.ok(not sim.stat_sources(&"seeds").is_empty(), "Seeds has a sources list")
	var ids: Array = StatIndex.stats(sim).map(func(r: Dictionary) -> Variant: return r["id"])
	t.ok(ids.has(&"seeds"), "the stats gallery lists Seeds after a Bloom")
