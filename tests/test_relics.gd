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
	t.ok(defs.size() == 33, "33 relics load (6 original, 27 expansion), got %d" % defs.size())
	var inv := RelicInventory.new(cfg, defs)

	# Stacking
	inv.add_relic(&"r_cash", 3)
	t.ok(inv.equip(&"r_cash"), "equip owned")
	t.ok(is_equal_approx(inv.total_effect(RelicDef.Effect.CASH_MULT), 1.0 - 0.94 * 0.94 * 0.94), "diminishing 3 stacks = 0.164")
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

	# Long play stays bounded: the four stacking relics diminish, so drops keep coming without the bonus running away
	for id: StringName in [&"r_cash", &"r_rate", &"r_mult", &"r_crit"]:
		var rd: RelicDef = inv.defs[id]
		t.ok(rd.stacking == RelicDef.Stacking.DIMINISHING, "%s diminishes" % id)
		t.ok(is_equal_approx(rd.value_for(1), rd.per_stack), "%s first stack is its full step" % id)
		t.ok(rd.value_for(1000) <= 1.0, "%s stays at or under 100%% after 1000 stacks" % id)

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
	t.ok(RelicDef.effect_name(RelicDef.Effect.CASH_MULT) == "Passive Income", "effect names are Title Case")

	# Expansion: every relic is complete, ids are unique, and each rarity has a full set
	var seen: Dictionary = {}
	var per_rarity: Dictionary = {}
	var complete: bool = true
	for ed: RelicDef in defs:
		seen[ed.id] = int(seen.get(ed.id, 0)) + 1
		per_rarity[ed.rarity.id] = int(per_rarity.get(ed.rarity.id, 0)) + 1
		if ed.display_name.is_empty() or ed.description.is_empty() or ed.icon == null or ed.rarity == null:
			complete = false
		if ed.effect == RelicDef.Effect.SURGE and ed.period < 2:
			complete = false
		if ed.effect == RelicDef.Effect.ZONE_GAIN and not [&"zone1", &"zone2", &"larkmoor"].has(ed.zone):
			complete = false
	t.ok(complete, "every relic has a name, text, icon, rarity, and a period or zone where it needs one")
	t.ok(seen.values().all(func(n: int) -> bool: return n == 1), "relic ids are unique")
	for r: StringName in [&"common", &"uncommon", &"rare", &"epic", &"legendary", &"mythic"]:
		t.ok(int(per_rarity.get(r, 0)) >= 5, "%s has at least 5 relics, has %d" % [r, int(per_rarity.get(r, 0))])
	for e: int in RelicDef.Effect.values():
		t.ok(RelicDef.effect_name(e as RelicDef.Effect) != "Bonus", "effect %d has a name" % e)

	# Surge: every period-th press of the run, one stack of Surge Drum is +50%
	var sg := RelicInventory.new(cfg, defs)
	sg.add_relic(&"r_surge_drum")
	sg.equip(&"r_surge_drum")
	t.near(sg.surge_mult(9), 1.0, 1e-9, "no surge on press 9")
	t.near(sg.surge_mult(10), 1.5, 1e-9, "surge on press 10")
	t.near(sg.surge_mult(20), 1.5, 1e-9, "surge on press 20")
	t.near(sg.surge_average(), 1.05, 1e-9, "average surge is value over period")
	sg.unequip(&"r_surge_drum")
	t.near(sg.surge_mult(10), 1.0, 1e-9, "unequipped surge does nothing")

	# Zone gain: only in its zone
	var zg := RelicInventory.new(cfg, defs)
	zg.add_relic(&"r_meadow_honey")
	zg.equip(&"r_meadow_honey")
	t.near(zg.zone_mult(&"zone1"), 1.12, 1e-9, "Meadow Honey helps the Meadow")
	t.near(zg.zone_mult(&"zone2"), 1.0, 1e-9, "Meadow Honey does nothing in the Quarry")

	# Pity speed: shortens the pity timer, never the first drop, never below a tenth
	var pz := RelicInventory.new(cfg, defs)
	pz.add_relic(&"r_hourglass_ages", 50)
	pz.equip(&"r_hourglass_ages")
	t.near(pz.pity_due(true), cfg.first_drop_seconds, 1e-9, "first drop timer untouched")
	t.ok(pz.pity_due(false) < cfg.pity_seconds and pz.pity_due(false) >= cfg.pity_seconds * 0.1, "pity timer shorter, floored at a tenth")

	# Drop chance: Lucky Penny at 4 stacks is +60% on the drop roll (base 0.5 -> 0.8)
	var lpc: RelicConfig = cfg.duplicate()
	lpc.base_drop_chance = 0.5
	var lp := RelicInventory.new(lpc, defs)
	lp.add_relic(&"r_lucky_penny", 4)
	lp.equip(&"r_lucky_penny")
	var lrng := RandomNumberGenerator.new()
	lrng.seed = 11
	var hits: int = 0
	for i in 20000:
		if lp.roll_drop(lrng, 0) != &"":
			hits += 1
	t.ok(absf(hits / 20000.0 - 0.8) < 0.02, "Lucky Penny lifts drop chance to about 80%%, got %.3f" % (hits / 20000.0))

	# Capped chances never pass 100%
	var cap := RelicInventory.new(cfg, defs)
	cap.add_relic(&"r_wardens_eye", 200)
	cap.equip(&"r_wardens_eye")
	t.ok(cap.total_effect(RelicDef.Effect.CRIT_CHANCE) <= 1.0, "crit chance from relics stays at or under 100%")

	# Gallery: tiers, per-tier lists, and how each relic is found
	var gal := RelicInventory.new(cfg, defs)
	t.eq(gal.tier_ranks(), [0, 1, 2, 3, 4, 5] as Array[int], "tabs: one per rarity that has relics")
	t.eq(gal.defs_of_rank(0).size(), 6, "Common has six relics")
	t.eq(gal.defs_of_rank(5).size(), 5, "Mythic has five relics")
	t.ok(gal.acquire_text(&"r_cash").contains("1 in 10"), "Common find text gives 1 in 10 drops, got: " + gal.acquire_text(&"r_cash"))
	t.ok(gal.acquire_text(&"r_pulse").begins_with("Drops from presses"), "Mythic find text names the drop source")
	var rebirth_only := (load("res://content/relics/r_pulse.tres") as RelicDef).duplicate()
	rebirth_only.id = &"r_rebirth_only"
	rebirth_only.rarity = load("res://content/rarities/divine.tres")
	gal.defs[&"r_rebirth_only"] = rebirth_only
	t.ok(gal.acquire_text(&"r_rebirth_only").contains("rebirths"), "zero-weight tiers say they come from rebirths or achievements")
	# Walker aura: the highest equipped rarity sets the pool colour and whether Epic and up sparkle
	var aura := RelicInventory.new(cfg, defs)
	t.eq(aura.top_equipped_rank(), -1, "no equipped relics means no aura rank")
	aura.add_relic(&"r_cash")
	aura.add_relic(&"r_crit")
	aura.equip(&"r_cash")
	t.eq(aura.top_equipped_rank(), 0, "common only: rank 0")
	aura.equip(&"r_crit")
	t.eq(aura.top_equipped_rank(), 3, "Epic equipped: rank 3")

