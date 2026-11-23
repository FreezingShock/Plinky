extends RefCounted
## Relic inventory suite. Run through tests/run.gd.

func run(t: SceneTree) -> void:
	var cfg: RelicConfig = load("res://content/relics/_config.tres")
	var defs: Array[RelicDef] = []
	var dir := DirAccess.open("res://content/relics")
	for f in dir.get_files():
		if f.begins_with("_") or not f.ends_with(".tres"):
			continue
		defs.append(load("res://content/relics/" + f))
	t.ok(defs.size() == 6, "six relics load, got %d" % defs.size())
	var inv := RelicInventory.new(cfg, defs)

	# Stacking
	inv.add_relic(&"r_cash", 3)
	t.ok(inv.equip(&"r_cash"), "equip owned")
	t.ok(is_equal_approx(inv.total_effect(RelicDef.Effect.CASH_MULT), 0.3), "linear 3 stacks = 0.3")
	t.ok(not inv.equip(&"r_cash"), "no double equip")
	t.ok(not inv.equip(&"r_rate"), "cannot equip unowned")

	# Unequipped does nothing
	inv.add_relic(&"r_rate")
	t.ok(is_equal_approx(inv.total_effect(RelicDef.Effect.PRESS_RATE), 0.0), "unequipped gives 0")

	# Slots
	inv.add_relic(&"r_mult"); inv.add_relic(&"r_crit")
	t.ok(inv.equip(&"r_rate") and inv.equip(&"r_mult"), "fill slots 2 and 3")
	t.ok(not inv.equip(&"r_crit"), "full at 3 slots")
	t.ok(inv.swap(&"r_cash", &"r_crit"), "swap")
	t.ok(not inv.is_equipped(&"r_cash") and inv.is_equipped(&"r_crit"), "swap result")
	inv.set_rebirths(5)
	t.ok(inv.slot_count() == 4, "4th slot at 5 rebirths")
	inv.set_rebirths(20)
	t.ok(inv.slot_count() == 5, "5th slot at 20 rebirths")

	# Diminishing + cap
	inv.add_relic(&"r_double", 50)
	var d: RelicDef = inv.defs[&"r_double"]
	t.ok(d.value_for(50) == d.value_for(10), "cap at 10 stacks")
	t.ok(d.value_for(2) < 0.2 and d.value_for(2) > 0.18, "diminishing 2 stacks = 0.19")

	# Tooltip text
	t.ok(d.describe(2).contains("19%"), "describe fills value: " + d.describe(2))

	# Save round trip
	var snap: Dictionary = inv.to_dict()
	var inv2 := RelicInventory.new(cfg, defs)
	inv2.set_rebirths(20)
	inv2.from_dict(snap)
	t.ok(inv2.stacks_of(&"r_cash") == 3 and inv2.equipped == inv.equipped, "save round trip")

	# Drops: Special never rolls, rarity weights respected
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var counts: Dictionary = {}
	var fresh := RelicInventory.new(cfg, defs)
	var always: RelicConfig = cfg.duplicate()
	always.base_drop_chance = 1.0
	fresh.config = always
	for i in 20000:
		var id: StringName = fresh.roll_drop(rng, 0)
		counts[id] = counts.get(id, 0) + 1
	t.ok(counts.get(&"r_cash", 0) > counts.get(&"r_rate", 0), "common drops more than uncommon")
	t.ok(counts.get(&"r_rate", 0) > counts.get(&"r_pulse", 0) * 5, "uncommon far more than mythic")
	t.ok(counts.get(&"", 0) == 0, "always-drop config never misses")

	t.ok(cfg.is_flashy(inv.defs[&"r_crit"]) and not cfg.is_flashy(inv.defs[&"r_mult"]), "flash from Epic up")
	var div: RelicDef = (load("res://content/relics/r_pulse.tres") as RelicDef).duplicate()
	div.id = &"d"; div.rarity = load("res://content/rarities/divine.tres")
	t.ok(div.rarity.weight == 0.0, "Divine never random")

	t.ok(inv.rarity_of(&"r_crit") == &"epic" and inv.rarity_of(&"nope") == &"", "rarity_of")

	# Sort, filter, compare (Relics menu refresh)
	var q := RelicInventory.new(cfg, defs)
	q.add_relic(&"r_cash", 5); q.add_relic(&"r_rate", 2); q.add_relic(&"r_crit"); q.add_relic(&"r_mult", 9)
	q.equip(&"r_cash"); q.equip(&"r_crit")
	var qr := RelicQuery.new()
	var by_rarity: Array[RelicDef] = qr.apply(q)
	t.ok(by_rarity[0].id == &"r_crit" and by_rarity[by_rarity.size() - 1].id == &"r_cash", "default sort is rarity high to low")
	qr.sort = RelicQuery.Sort.STACKS
	t.ok(qr.apply(q)[0].id == &"r_mult", "stacks sort puts the biggest stack first")
	qr.sort = RelicQuery.Sort.NAME
	t.ok(qr.apply(q)[0].display_name == "Gold Purse", "name sort is alphabetical")
	qr.sort = RelicQuery.Sort.EQUIPPED
	t.ok(q.is_equipped(qr.apply(q)[0].id), "equipped sort leads with equipped relics")
	qr.reset()
	qr.scope = RelicQuery.Scope.EQUIPPED
	t.ok(qr.apply(q).size() == 2, "equipped filter keeps 2")
	qr.scope = RelicQuery.Scope.UNEQUIPPED
	t.ok(qr.apply(q).size() == 2, "unequipped filter keeps 2")
	qr.reset()
	qr.cycle_rarity(q)
	t.ok(qr.rarity_rank == 3, "first rarity step is the highest owned (Epic), got %d" % qr.rarity_rank)
	t.ok(qr.apply(q).size() == 1 and qr.rarity_name(q) == "Epic", "rarity filter shows only that tier")
	for i in RelicQuery.owned_ranks(q).size():
		qr.cycle_rarity(q)
	t.ok(qr.rarity_rank == -1, "rarity filter cycles back to All")
	t.ok(q.sorted_owned().size() == 4, "sorted_owned keeps every owned relic")

	t.ok(q.active_bonuses().size() == 2, "two active bonus kinds")
	var gain: Array[Dictionary] = q.preview_change(&"r_mult")
	t.ok(gain.size() == 1 and is_equal_approx(float(gain[0]["before"]), 0.0) and float(gain[0]["after"]) > 0.0, "equip preview shows the gain")
	t.ok(q.equipped.size() == 2 and not q.is_equipped(&"r_mult"), "preview changes nothing")
	var sw: Array[Dictionary] = q.preview_change(&"r_rate", &"r_cash")
	t.ok(sw.size() == 2, "swap preview lists both effects")
	t.ok(RelicDef.effect_name(RelicDef.Effect.CASH_MULT) == "Cash Income", "effect names are Title Case")
