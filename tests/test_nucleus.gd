extends RefCounted
## The Nucleus: the Ember Quarry's own zone reset (Core Shards, forge gifts), and the move from the old quarry Rebirth.

const GIFTS: Array[StringName] = [&"nucleus_hearth", &"nucleus_furnace", &"nucleus_plates", &"nucleus_smoulder", &"nucleus_veins", &"nucleus_twin",
	&"nucleus_stride", &"nucleus_hands", &"nucleus_edge", &"nucleus_banked", &"nucleus_resonance", &"nucleus_study", &"nucleus_heartstrike"]


func run(t: Object) -> void:
	var sim: Sim = t.make_sim()
	var rid: StringName = &"nucleus"
	var rd: ZoneResetDef = sim.reset_defs.get(rid) as ZoneResetDef
	t.ok(rd != null, "the Nucleus reset is loaded")
	if rd == null:
		return
	t.eq(sim.reset_for_zone(&"zone2"), rd, "the quarry's reset is the Nucleus")
	t.eq(sim.reset_for_currency(&"shards"), rd, "Core Shards are paid by the Nucleus")
	t.ok(ResourceLoader.exists("res://assets/icons/shards.png") and ResourceLoader.exists("res://assets/icons/big/shards.png"), "Core Shards have icons")
	t.ok(StatStyle.COLORS.has(&"shards"), "Core Shards have a colour")
	t.ok(not sim.rebirth_here(), "Rebirth is retired from every zone")
	sim.zone_id = &"zone2"
	t.ok(not UpgradeText.group_shown(sim, &"prestige") and not UpgradeText.group_shown(sim, &"rp"), "no Prestige or Rebirth Point upgrades in the quarry")
	t.ok(not (sim.stat_defs[&"embers"] as StatDef).prestige_boosts_income, "Prestige no longer boosts Embers")

	# Gifts: thirteen, all paid in Core Shards, all with their own text and icon.
	t.ok(GIFTS.size() >= 13, "at least thirteen Nucleus gifts")
	for id: StringName in GIFTS:
		var a: AttributeDef = sim.attribute_defs.get(id) as AttributeDef
		t.ok(a != null and a.currency == &"shards", "%s is a Core Shards gift" % id)
		if a == null:
			continue
		t.ok(a.blurb != "" and a.unit_text != "", "%s brings its own menu text" % id)
		t.ok(ResourceLoader.exists("res://assets/icons/%s.png" % StatIndex.attr_icon(a)), "%s has an icon" % id)
		t.ok(UpgradeText.state(sim, a)["next"] != "", "%s has a next value" % id)

	# Opens with the quarry gate, pays by the same formula as Bloom, resets the forge only.
	t.ok(not sim.can_reset(rid), "no Nucleus at the start")
	sim.stats[&"emberheart"] = BigNum.from_float(sim.reset_ref(rid))
	t.ok(not sim.can_reset(rid), "the gate must be open")
	sim.gates_open[&"zone2"] = true
	t.eq(sim.reset_gain(rid), 2, "the gate's worth of Emberhearts pays 2 Core Shards")
	sim.stats[&"emberheart"] = BigNum.from_float(sim.reset_ref(rid) * 4.0)
	t.eq(sim.reset_gain(rid), 4, "four times pays double")
	for sid: String in rd.resets:
		sim.stats[StringName(sid)] = BigNum.from_float(77.0)
	sim.stats[&"emberheart"] = BigNum.from_float(sim.reset_ref(rid) * 4.0)   # the gate stat decides the payout
	sim.stats[&"clover"] = BigNum.from_float(40.0)
	sim.dev_open_tiers()
	var rebirths: int = sim.rebirth_count
	var before: float = sim.pad_yield_mult()
	var seen: Array = []
	sim.reset_done.connect(func(id: StringName, n: int) -> void: seen.append([id, n]))
	t.ok(sim.try_reset(rid), "strike a Nucleus")
	t.eq(seen, [[&"nucleus", 4]], "reset_done carries the shards paid")
	t.near(sim.get_stat(&"shards").to_float(), 4.0, 1e-9, "Core Shards paid")
	t.ok(sim.get_stat(&"cinder").is_zero() and sim.get_stat(&"emberheart").is_zero(), "the forge stats reset")
	t.near(sim.get_stat(&"embers").to_float(), (sim.stat_defs[&"embers"] as StatDef).start, 1e-9, "Embers restart at their start")
	t.near(sim.get_stat(&"clover").to_float(), 40.0, 1e-9, "the meadow is untouched")
	t.ok(sim.gates_open.get(&"zone2", false) and sim.is_tier_open(&"emberheart"), "gates and open rows kept")
	t.near(sim.pad_yield_mult(), before + rd.bonus_per_use, 1e-9, "every pad pays more for good")
	t.eq(sim.rebirth_count, rebirths + 1, "a Nucleus counts toward the relic slots")
	t.ok(not sim.try_reset(rid), "no second Nucleus straight away")

	# Gifts do what they say.
	sim.stats[&"shards"] = BigNum.from_float(500.0)
	var hearth: AttributeDef = sim.attribute_defs[&"nucleus_hearth"]
	var cost: float = sim.attribute_cost(hearth.id).to_float()
	t.ok(sim.buy_attribute(hearth.id), "buy Warm Start")
	t.near(sim.get_stat(&"shards").to_float(), 500.0 - cost, 1e-9, "Core Shards drop by the cost")
	t.near(sim.reset_start_value(rid, &"embers").to_float(), (sim.stat_defs[&"embers"] as StatDef).start + hearth.per_level, 1e-9, "Warm Start adds starting Embers")
	var base_income: float = sim.income_per_second(&"embers").to_float()
	sim.attr_levels[&"nucleus_furnace"] = 10
	t.near(sim.income_per_second(&"embers").to_float(), base_income * (1.0 + 10.0 * 0.10), 1e-6, "Stoked Fire raises Embers income")
	sim.attr_levels.clear()
	sim.stats[&"emberheart"] = BigNum.from_float(sim.reset_ref(rid) * 4.0)
	sim.attr_levels[&"nucleus_veins"] = 10
	t.eq(sim.reset_gain(rid), int(floorf(4.0 * (1.0 + 10.0 * 0.15))), "Shard Veins raise the payout")
	sim.attr_levels.clear()
	sim.attr_levels[&"nucleus_banked"] = 2
	sim.stats[&"cinder"] = BigNum.from_float(9.0)
	sim.stats[&"ironore"] = BigNum.from_float(8.0)
	sim.stats[&"slag"] = BigNum.from_float(7.0)
	sim.reset_counts[rid] = 0
	t.ok(sim.try_reset(rid), "strike with Banked Rows")
	t.near(sim.get_stat(&"cinder").to_float(), 9.0, 1e-9, "Cinder is kept")
	t.near(sim.get_stat(&"ironore").to_float(), 8.0, 1e-9, "Iron Ore is kept")
	t.ok(sim.get_stat(&"slag").is_zero(), "Slag still resets at level 2")
	sim.attr_levels.clear()

	# The animation skin is data.
	t.ok(rd.fx_rise and rd.fx_stats.size() == 7 and rd.fx_marks != "", "the Nucleus animation has its own colours, marks and rising sparks")

	# A save from the old quarry Rebirth: Prestige, RP and the Prestige-bought upgrades become Core Shards.
	var old: Dictionary = {"zone": "zone2", "gates": ["zone1", "larkmoor", "zone2"], "zones_entered": ["zone1", "larkmoor", "zone2"], "ladder": 3,
		"stats": {"embers": 500.0, "prestige": 40.0, "rp": 6.0, "reb": 3.0}, "prestige_spent": 12.0, "rebirth_count": 5,
		"attributes": {"walk_speed": 3, "pad_yield": 2, "rp_rest": 1}}
	var m: Sim = t.make_sim()
	t.ok(m.from_dict(old), "load an old quarry Rebirth save")
	t.near(m.get_stat(&"shards").to_float(), float(2 * 5 + 6), 1e-9, "2 Core Shards per old Rebirth, 1 per old upgrade level")
	t.eq(m.reset_count(rid), 5, "old Rebirths count as Nucleus uses")
	t.ok(m.get_stat(&"prestige").is_zero() and m.get_stat(&"rp").is_zero() and m.prestige_spent.is_zero(), "Prestige and Rebirth Points are cleared")
	t.eq(m.attr_level(&"walk_speed") + m.attr_level(&"pad_yield") + m.attr_level(&"rp_rest"), 0, "the old upgrade levels are cleared")
	t.eq(m.rebirth_count, 5, "relic slots are kept")
	t.near(m.get_stat(&"embers").to_float(), 500.0, 1e-9, "the run carries on")
	t.eq(int(m.to_dict().get("ladder")), 4, "saving writes the new format")
	var again: Sim = t.make_sim()
	again.from_dict(m.to_dict())
	t.near(again.get_stat(&"shards").to_float(), m.get_stat(&"shards").to_float(), 1e-9, "the migration runs once")
	# A meadow-only save keeps its old Prestige: nothing was ever spent in the quarry.
	var meadow: Sim = t.make_sim()
	meadow.from_dict({"zone": "zone1", "ladder": 3, "stats": {"prestige": 5.0}, "rebirth_count": 2})
	t.ok(not meadow.get_stat(&"prestige").is_zero() and meadow.get_stat(&"shards").is_zero(), "a save that never reached the quarry is left alone")
