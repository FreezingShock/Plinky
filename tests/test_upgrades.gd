extends RefCounted
## Upgrades menu: text, rebirth gates and the three Rebirth-unlocked upgrades.

func run(t: Object) -> void:
	var sim: Sim = t.make_sim()
	var press: AttributeDef = sim.attribute_defs[&"press_rate"]
	t.eq(UpgradeText.value(press, 1.2), "+120%", "press rate value reads as a percent")
	var off: AttributeDef = sim.attribute_defs[&"offline_gain"]
	t.eq(UpgradeText.value(off, 5.0), "+5 h", "offline cap reads in hours")

	# now -> next at level 0 and level 12
	var s: Dictionary = UpgradeText.state(sim, press)
	t.eq(s["now"], "+0%", "level 0 gives nothing yet")
	t.eq(s["next"], "+10%", "level 1 gives 10 percent")
	sim.attr_levels[&"press_rate"] = 12
	s = UpgradeText.state(sim, press)
	t.eq([s["now"], s["next"]], ["+120%", "+130%"], "level 12 shows +120% then +130%")
	sim.attr_levels[&"press_rate"] = press.cap
	s = UpgradeText.state(sim, press)
	t.ok(bool(s["maxed"]) and s["next"] == "", "a maxed upgrade has no next value")
	sim.attr_levels.clear()

	# order: open ones first, then by Rebirths needed
	var order: Array[AttributeDef] = UpgradeText.ordered(sim)
	t.eq(order.size(), sim.attribute_defs.size(), "every upgrade is listed")
	for i: int in range(1, order.size()):
		if order[i - 1].currency == order[i].currency:
			t.ok(order[i - 1].unlock_rebirths <= order[i].unlock_rebirths, "%s is not before a lower gate" % order[i].id)
		else:
			t.ok(UpgradeText.rank(sim, order[i - 1].currency) < UpgradeText.rank(sim, order[i].currency), "Prestige upgrades, then Rebirth Point perks, then Bloom gifts")
	t.eq(order[0].id, &"press_rate", "press rate leads")

	# gates
	var gated: Array = order.filter(func(a: AttributeDef) -> bool: return a.unlock_rebirths > 0 and a.currency == &"prestige")
	t.ok(gated.size() >= 3, "at least three upgrades unlock through Rebirths")
	for a: AttributeDef in gated:
		sim.rebirth_count = 0
		sim.stats[&"prestige"] = BigNum.from_float(1000.0)
		t.ok(not sim.attr_unlocked(a.id), "%s is locked at 0 Rebirths" % a.id)
		t.ok(not sim.buy_attribute(a.id), "%s cannot be bought while locked" % a.id)
		t.eq(String(UpgradeText.state(sim, a)["lock"]), "Unlocks at %d Rebirths" % a.unlock_rebirths, "%s lock text" % a.id)
		sim.rebirth_count = a.unlock_rebirths
		t.ok(sim.attr_unlocked(a.id), "%s unlocks at %d Rebirths" % [a.id, a.unlock_rebirths])
		t.ok(sim.buy_attribute(a.id), "%s can be bought once unlocked" % a.id)
		t.ok(ResourceLoader.exists("res://assets/icons/%s.png" % StatIndex.ATTR_ICONS.get(a.effect, "")), "%s has an icon" % a.id)
		t.ok(UpgradeText.UNITS.has(a.effect), "%s has a unit label" % a.id)

	# effects
	sim.new_game()
	sim.attr_levels[&"pad_yield"] = 10
	t.near(sim.pad_yield_mult(), 1.2, 1e-9, "pad yield 10 levels is +20 percent")
	sim.attr_levels.clear()
	var base_crit: float = sim.crit_damage()
	sim.attr_levels[&"crit_power"] = 4
	t.near(sim.crit_damage() - base_crit, 0.2, 1e-9, "crit power adds to the crit multiplier")
	sim.attr_levels.clear()

	# affordability shows in the state
	sim.new_game()
	t.ok(not bool(UpgradeText.state(sim, press)["can_afford"]), "no Prestige: cannot afford")
	sim.stats[&"prestige"] = BigNum.from_float(50.0)
	t.ok(bool(UpgradeText.state(sim, press)["can_afford"]), "with Prestige: can afford")
	t.ok(str(UpgradeText.tip(UpgradeText.state(sim, press), &"press_rate")["hint"]).begins_with("Costs"), "tooltip hint names the cost")

	# gallery: tiers, tab names and the tab that opens first
	sim.new_game()
	var pods: AttributeDef = sim.attribute_defs[&"bloom_seed_pods"]
	t.eq(UpgradeText.tier_of(pods), 1, "Seed Pods wait for one Bloom")
	t.eq(UpgradeText.tier_of(press), 0, "Press Rate is open from the start")
	t.eq(UpgradeText.tier_title(sim, &"seeds", 2), "After 2 Bloom resets", "tier heading names the reset and counts plurals")
	t.eq(UpgradeText.tier_title(sim, &"seeds", 1), "After 1 Bloom reset", "tier heading is singular at one")
	t.eq(UpgradeText.tier_title(sim, &"prestige", 0), "Open From Start", "tier 0 heading")
	t.eq(UpgradeText.tier_title(sim, &"prestige", 2), "After 2 Rebirths", "Rebirth tiers count Rebirths")
	t.eq(UpgradeText.tab_title(sim, &"seeds"), "Bloom Gifts", "Bloom tab is named from the reset")
	t.eq(UpgradeText.tab_title(sim, &"shards"), "Nucleus Gifts", "Nucleus tab is named from the reset")
	t.eq(UpgradeText.tab_title(sim, &"prestige"), "Prestige", "Prestige tab")
	t.eq(String(UpgradeText.state(sim, sim.attribute_defs[&"nucleus_veins"])["lock"]), "Unlocks after 1 Nucleus reset", "Nucleus lock text reads cleanly")
	t.eq(UpgradeText.default_tab(sim, [&"prestige", &"seeds"] as Array[StringName]), &"seeds", "the zone's tab opens first")
	t.eq(UpgradeText.default_tab(sim, [&"prestige"] as Array[StringName]), &"prestige", "with no zone tab showing, the first tab opens")
	t.eq(UpgradeText.default_tab(sim, [] as Array[StringName]), &"", "no tabs, nothing opens")
