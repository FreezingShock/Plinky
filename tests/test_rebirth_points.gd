extends RefCounted
## Rebirth Points (RP): paid on rebirth, spent on the Rebirth perks, backfilled on old saves. Also HoldRepeat timing.

func run(t: Object) -> void:
	var sim: Sim = t.make_sim()
	t.ok(sim.stat_defs.has(&"rp"), "rp stat is loaded")
	t.eq(sim.rp_for_rebirth(0), 1, "first rebirth pays 1 RP")
	t.eq(sim.rp_for_rebirth(10), 2, "RP per rebirth grows with the rebirth count")
	t.ok(sim.rp_for_rebirth(40) > sim.rp_for_rebirth(10), "later rebirths pay more")
	t.eq(sim.rp_total_for(3), 3, "three early rebirths paid 3 RP")

	# A rebirth pays RP and Prestige; rebirths still only boost Multiplier gain.
	sim.stats[&"clover"] = BigNum.from_float(9.0)
	t.eq(sim.rp_gain_preview(), 1, "preview shows the next payout")
	t.ok(sim.try_rebirth(), "rebirth")
	t.near(sim.rp_available().to_float(), 1.0, 1e-9, "rebirth paid 1 RP")
	t.near(sim.get_stat(&"prestige").to_float(), 9.0, 1e-9, "prestige payout unchanged")
	sim.stats[&"clover"] = BigNum.from_float(9.0)
	t.ok(sim.try_rebirth(), "second rebirth")
	t.near(sim.rp_available().to_float(), 2.0, 1e-9, "RP stack across rebirths (not reset)")

	# Perks cost RP, not Prestige.
	var perk: AttributeDef = sim.attribute_defs[&"rp_lore"]
	t.eq(perk.currency, &"rp", "Pad lore is an RP perk")
	var prestige_before: float = sim.prestige_available().to_float()
	var cost: float = sim.attribute_cost(&"rp_lore").to_float()
	t.ok(sim.buy_attribute(&"rp_lore"), "buy an RP perk with 2 RP")
	t.near(sim.rp_available().to_float(), 2.0 - cost, 1e-9, "RP drops by the cost")
	t.near(sim.prestige_available().to_float(), prestige_before, 1e-9, "Prestige untouched by an RP perk")
	t.near(sim.effect_total(&"mastery_xp"), perk.per_level, 1e-9, "perk adds its effect")
	sim.stats[&"rp"] = BigNum.zero()
	t.ok(not sim.buy_attribute(&"rp_lore"), "cannot buy an RP perk with no RP, even with Prestige")
	var st: Dictionary = UpgradeText.state(sim, perk)
	t.ok(not bool(st["can_afford"]) and st["currency_name"] == "Rebirth Points", "row state names the currency")
	t.ok(str(UpgradeText.tip(st, &"mastery_xp")["hint"]).contains("Rebirth Points"), "tooltip names RP")

	# Save v4: RP survives a round trip; a v3 save is paid for its rebirths.
	sim.stats[&"rp"] = BigNum.from_float(7.0)
	var back: Sim = t.make_sim()
	back.from_dict(SaveCodec.decode(SaveCodec.encode(sim, 0.0))["game"])
	t.near(back.rp_available().to_float(), 7.0, 1e-9, "RP survives save and load")
	var old: Dictionary = sim.to_dict()
	old["stats"].erase("rp")
	old["rebirth_count"] = 12
	var d: Dictionary = SaveCodec.decode(JSON.stringify({"version": 3, "saved_at": 0, "game": old}))
	t.eq(d["version"], SaveCodec.CURRENT_VERSION, "v3 save migrates to current")
	back.from_dict(d["game"])
	t.near(back.rp_available().to_float(), float(back.rp_total_for(12)), 1e-9, "v3 save is backfilled with RP for its rebirths")
	t.ok(back.rp_total_for(12) > 12, "backfill counts the growth")

	# Stats index and sources know RP.
	var ids: Array = StatIndex.stats(sim).map(func(r: Dictionary) -> Variant: return r["id"])
	t.ok(ids.has(&"rp"), "stats gallery lists Rebirth Points")
	t.ok(not sim.stat_sources(&"rp").is_empty(), "RP has a sources list")
	t.ok(ResourceLoader.exists("res://assets/icons/rp.png"), "RP icon exists")

	# Hold-to-repeat timing.
	var h := HoldRepeat.new()
	t.eq(h.step(1.0), 0, "idle: no repeats")
	h.begin()
	t.eq(h.step(HoldRepeat.DELAY - 0.01), 0, "no repeat before the delay")
	t.ok(h.step(0.02) >= 1, "first repeat after the delay")
	var first_gap: float = h.gap()
	for i: int in 100:
		h.step(0.05)
	t.ok(h.gap() < first_gap, "repeats speed up while held")
	t.near(h.gap(), HoldRepeat.MIN_GAP, 1e-9, "speed-up stops at the minimum gap")
	t.ok(h.step(5.0) <= 3, "a long frame cannot burst-spend")
	h.end()
	t.eq(h.step(1.0), 0, "released: no repeats")
