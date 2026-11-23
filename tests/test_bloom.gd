extends RefCounted
## Bloom: the meadow's reset. Opens with the Larkmoor gate, pays Seeds, resets the flower stats, keeps everything else.


func run(t: Object) -> void:
	var sim: Sim = t.make_sim()
	var rd: ZoneResetDef = sim.reset_defs[&"bloom"] as ZoneResetDef
	var rid: StringName = &"bloom"
	t.ok(sim.stat_defs.has(&"seeds"), "seeds stat is loaded")
	t.ok(ResourceLoader.exists("res://assets/icons/seeds.png") and ResourceLoader.exists("res://assets/icons/big/seeds.png"), "Seeds icons exist")
	t.ok(not sim.can_reset(rid), "no Bloom at the start")
	t.eq(sim.reset_gain(rid), 0, "no preview before the gate")

	# Needs the gate and the first payout of the source stat.
	sim.stats[&"starbloom"] = BigNum.from_float(sim.reset_ref(rid))
	t.ok(not sim.can_reset(rid), "Starbloom alone is not enough, the gate must be open")
	sim.gates_open[&"larkmoor"] = true
	t.eq(sim.reset_gain(rid), 2, "the gate's worth of Starbloom Petals pays 2 Seeds")
	sim.stats[&"starbloom"] = BigNum.from_float(sim.reset_ref(rid) * 4.0)
	t.eq(sim.reset_gain(rid), 4, "four times the petals pay double")
	sim.stats[&"starbloom"] = BigNum.from_float(sim.reset_ref(rid) * 0.5)
	t.ok(not sim.can_reset(rid), "too few petals pay nothing")

	# A Bloom resets the flowers and keeps the rest.
	sim.stats[&"starbloom"] = BigNum.from_float(sim.reset_ref(rid))
	sim.stats[&"clover"] = BigNum.from_float(40.0)
	sim.stats[&"rp"] = BigNum.from_float(3.0)
	sim.stats[&"prestige"] = BigNum.from_float(12.0)
	sim.dev_open_tiers()
	var reward_before: float = sim.pad_yield_mult()
	var done: Array = []
	sim.reset_done.connect(func(id: StringName, n: int) -> void: done.append([id, n]))
	t.ok(sim.try_reset(rid), "Bloom")
	t.eq(done, [[&"bloom", 2]], "bloom_done carries the Seeds paid")
	t.near(sim.get_stat(&"seeds").to_float(), 2.0, 1e-9, "Seeds paid")
	t.ok(sim.get_stat(&"starbloom").is_zero(), "Larkmoor flowers reset")
	t.ok(not sim.get_stat(&"clover").is_zero(), "Clover Leaves are kept")
	t.near(sim.get_stat(&"sunlight").to_float(), (sim.stat_defs[&"sunlight"] as StatDef).start, 1e-9, "Sunlight back to its start")
	t.near(sim.get_stat(&"rp").to_float(), 3.0, 1e-9, "Rebirth Points kept")
	t.near(sim.get_stat(&"prestige").to_float(), 12.0, 1e-9, "old Prestige kept")
	t.ok(sim.gates_open.get(&"larkmoor", false) and sim.is_tier_open(&"starbloom"), "gates and open tiers kept")
	t.eq(sim.reset_count(rid), 1, "Bloom counted")
	t.near(sim.pad_yield_mult(), reward_before + rd.bonus_per_use, 1e-9, "each Bloom adds to every pad's reward")
	t.ok(not sim.try_reset(rid), "no second Bloom straight away")

	# Later uses come sooner: the payout reference shrinks per use, down to a floor.
	var base_ref: float = (sim.zone_defs[rd.gate_zone] as ZoneDef).gate_threshold
	sim.reset_counts[rid] = 1
	t.near(sim.reset_ref(rid), base_ref * rd.ref_shrink_per_use, 1e-9, "the second Bloom asks for less")
	sim.reset_counts[rid] = 99
	t.near(sim.reset_ref(rid), base_ref * rd.ref_floor, 1e-9, "the requirement never drops below the floor")
	sim.reset_counts[rid] = 1

	# The framework is data: a second zone reset plugs in with no script change.
	var gz: ZoneDef = sim.zone_defs[&"zone1"] as ZoneDef
	var forge := ZoneResetDef.new()
	forge.id = &"forge"
	forge.display_name = "Forge"
	forge.zones = PackedStringArray(["zone2"])
	forge.order = 2
	forge.currency = &"slag"
	forge.source_stat = gz.gate_stat
	forge.gate_zone = &"zone1"
	forge.resets = PackedStringArray(["ironore"])
	forge.menu_title = "Forge Gifts"
	sim.reset_defs[&"forge"] = forge
	t.ok(sim.reset_for_zone(&"zone2") == forge and sim.reset_for_zone(&"larkmoor") == rd, "each zone has its own reset")
	t.ok(sim.reset_for_currency(&"slag") == forge, "a reset is found by its currency")
	t.ok(UpgradeText.rank(sim, &"slag") > UpgradeText.rank(sim, &"seeds"), "gifts group in reset order")
	t.eq(UpgradeText.group_head(sim, &"slag"), "FORGE GIFTS", "the heading comes from the def")
	sim.gates_open[&"zone1"] = true
	sim.stats[gz.gate_stat] = BigNum.from_float(sim.reset_ref(&"forge") * 4.0)
	sim.stats[&"ironore"] = BigNum.from_float(500.0)
	t.eq(sim.reset_gain(&"forge"), 4, "the new reset pays by its own formula")
	t.ok(sim.try_reset(&"forge"), "the new reset runs")
	t.near(sim.get_stat(&"ironore").to_float(), (sim.stat_defs[&"ironore"] as StatDef).start, 1e-9, "it resets only what its def lists")
	t.near(sim.get_stat(&"slag").to_float(), 4.0, 1e-9, "and pays its own currency")
	t.eq(sim.reset_count(rid), 1, "the other reset's count is untouched")
	sim.reset_defs.erase(&"forge")
	sim.reset_counts.erase(&"forge")
	sim.stats[&"slag"] = BigNum.zero()

	# Rebirth is for the zones that run it.
	sim.zone_id = &"zone1"
	t.ok(not sim.rebirth_here(), "the meadow does not show Rebirth")
	t.ok(not UpgradeText.group_shown(sim, &"prestige"), "Prestige upgrades hide in the meadow")
	t.ok(UpgradeText.group_shown(sim, &"seeds"), "Bloom gifts show after a Bloom")
	sim.zone_id = &"zone2"
	t.ok(not sim.rebirth_here(), "no zone runs the old Rebirth any more: the quarry has the Nucleus")

	# Gifts cost Seeds, not Prestige, and do what they say.
	var gift: AttributeDef = sim.attribute_defs[&"bloom_head_start"]
	t.eq(gift.currency, &"seeds", "gifts are paid in Seeds")
	sim.stats[&"seeds"] = BigNum.from_float(10.0)
	var prestige_before: float = sim.prestige_available().to_float()
	var cost: float = sim.attribute_cost(&"bloom_head_start").to_float()
	t.ok(sim.buy_attribute(&"bloom_head_start"), "buy Head start")
	t.near(sim.get_stat(&"seeds").to_float(), 10.0 - cost, 1e-9, "Seeds drop by the cost")
	t.near(sim.prestige_available().to_float(), prestige_before, 1e-9, "Prestige untouched")
	t.near(sim.reset_start_value(rid, &"sunlight").to_float(), (sim.stat_defs[&"sunlight"] as StatDef).start + gift.per_level, 1e-9, "Head start adds Sunlight")
	sim.stats[&"seeds"] = BigNum.zero()
	t.ok(not sim.buy_attribute(&"bloom_soil"), "no Seeds, no gift")
	t.eq(UpgradeText.ordered(sim).back().currency, &"shards", "the newest reset's gifts list last")

	var soil: AttributeDef = sim.attribute_defs[&"bloom_soil"]
	sim.zone_id = &"zone1"
	var base_inc: float = sim.income_per_second(&"sunlight").to_float()
	sim.attr_levels[&"bloom_soil"] = 2
	t.near(sim.income_per_second(&"sunlight").to_float(), base_inc * (1.0 + 2.0 * soil.per_level), base_inc * 1e-6, "Deep soil boosts Sunlight income")

	# Save round trip.
	sim.stats[&"seeds"] = BigNum.from_float(5.0)
	var back: Sim = t.make_sim()
	back.from_dict(SaveCodec.decode(SaveCodec.encode(sim, 0.0))["game"])
	t.eq(back.reset_count(rid), 1, "Bloom count survives save and load")
	t.near(back.get_stat(&"seeds").to_float(), 5.0, 1e-9, "Seeds survive save and load")
	var old: Dictionary = sim.to_dict()
	old.erase("reset_counts")
	back.from_dict(old)
	t.eq(back.reset_count(rid), 0, "a save from before Bloom starts at 0")
	old["bloom_count"] = 3
	back.from_dict(old)
	t.eq(back.reset_count(rid), 3, "a 0.31 save's bloom_count carries over")

	# UI text knows Seeds.
	t.ok(not sim.stat_sources(&"seeds").is_empty(), "Seeds has a sources list")
	var ids: Array = StatIndex.stats(sim).map(func(r: Dictionary) -> Variant: return r["id"])
	t.ok(ids.has(&"seeds"), "the stats gallery lists Seeds after a Bloom")
