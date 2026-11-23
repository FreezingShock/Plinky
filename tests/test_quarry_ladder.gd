extends RefCounted
## The Ember Quarry ladder: six forge rows (Cinder to Emberheart), zone-scoped Rebirth, the flat arrival purse and the
## move from the old Forge-row quarry save.


func run(t: Object) -> void:
	var sim: Sim = t.make_sim()
	var rows: Array[TierDef] = sim.tiers_in_zone(&"zone2")
	t.eq(rows.map(func(r: TierDef) -> String: return String(r.id)), ["cinder", "ore", "slagrow", "ingot", "alloy", "emberheart"], "forge rows, bottom to top")
	t.eq(rows.map(func(r: TierDef) -> String: return String(r.rarity)), ["common", "uncommon", "rare", "epic", "legendary", "mythic"], "rarities climb with the rows")
	# each row costs the stat the row below pays, and the first row costs the passive Cash
	var prev_stat: StringName = &"cash"
	for r: TierDef in rows:
		for i in 3:
			var b: ButtonDef = sim.button_defs.get(StringName("%s_%d" % [r.id, i + 1])) as ButtonDef
			t.ok(b != null and b.cost_stat == prev_stat and b.reward_stat == r.stat, "%s pad %d costs %s and pays %s" % [r.id, i + 1, prev_stat, r.stat])
		prev_stat = r.stat
	t.ok(sim.is_tier_open(&"cinder") and not sim.is_tier_open(&"ore"), "Cinder is open, Ore is not")

	# arrival: a small flat purse, whatever the player holds from the meadow
	sim.stats[&"starbloom"] = BigNum.from_float(120.0)
	sim.gates_open[&"larkmoor"] = true
	t.ok(sim.enter_zone(&"zone2"), "enter the quarry")
	t.near(sim.get_stat(&"cash").to_float(), 200.0, 1e-9, "the arrival purse is flat: 200 Cash, not scaled by Starbloom")
	t.ok(sim.get_stat(&"mult").is_zero(), "and no free Multiplier")

	# Rebirth banks Ingots here, refuses without them, and only resets the quarry's own stats
	t.eq(sim.prestige_source(), &"ingot", "the quarry rebirths from Ingots")
	t.ok(not sim.can_rebirth(), "no Ingots, no rebirth")
	sim.stats[&"clover"] = BigNum.from_float(50.0)
	t.ok(not sim.can_rebirth(), "Clover Leaves cannot be rebirthed from the quarry")
	sim.stats[&"ingot"] = BigNum.from_float(4.0)
	sim.stats[&"mult"] = BigNum.from_float(77.0)
	t.ok(sim.try_rebirth(), "rebirth with Ingots")
	t.ok(sim.get_stat(&"ingot").is_zero() and sim.get_stat(&"mult").is_zero(), "quarry stats reset")
	t.near(sim.get_stat(&"clover").to_float(), 50.0, 1e-9, "the meadow's stock is untouched")
	t.near(sim.get_stat(&"cash").to_float(), 10.0, 1e-9, "Cash restarts at its start value")
	t.near(sim.get_stat(&"reb").to_float(), 1.0, 1e-9, "the quarry counts a Rebirth")
	t.ok(not sim.get_stat(&"prestige").is_zero(), "Prestige banked")
	t.ok(sim.can_afford(&"cinder_1"), "after a rebirth the first pad is still affordable (no soft lock)")

	# a rebirth in Larkmoor does not touch the quarry
	sim.stats[&"ingot"] = BigNum.from_float(3.0)
	sim.zone_id = &"larkmoor"
	t.eq(sim.prestige_source(), &"clover", "Larkmoor rebirths from Clover Leaves")
	t.ok(sim.try_rebirth(), "rebirth in Larkmoor")
	t.near(sim.get_stat(&"ingot").to_float(), 3.0, 1e-9, "a Larkmoor rebirth leaves quarry Ingots alone")

	# the ladder opens one row at a time and survives a save
	sim.zone_id = &"zone2"
	sim.stats[&"cash"] = BigNum.from_float(1.0e6)
	t.ok(sim.try_press(&"cinder_3"), "press the last Cinder pad")
	t.ok(sim.is_tier_open(&"ore"), "Ore opens")
	t.ok(not sim.is_tier_open(&"slagrow"), "Slag stays shut")
	var back: Sim = t.make_sim()
	t.ok(back.from_dict(sim.to_dict()), "load")
	t.ok(back.is_tier_open(&"ore"), "the open row is kept")

	# an old quarry save (Forge pads, Slag) keeps its stock, mastery and the rows it had already played
	var old: Dictionary = {"zone": "zone2", "gates": ["zone1", "larkmoor"], "zones_entered": ["zone1", "larkmoor", "zone2"], "ladder": 1,
		"stats": {"cash": 900.0, "mult": 40.0, "reb": 3.0, "slag": 6.0, "prestige": 2.0},
		"mastery": {"f1": [1, 5.0]}}
	var m: Sim = t.make_sim()
	t.ok(m.from_dict(old), "load an old quarry save")
	t.eq(m.zone_id, &"zone2", "still in the quarry")
	t.near(m.get_stat(&"slag").to_float(), 6.0, 1e-9, "Slag kept")
	t.near(m.get_stat(&"cash").to_float(), 900.0, 1e-9, "Cash kept")
	t.ok(m.is_tier_open(&"ore") and m.is_tier_open(&"slagrow"), "rows up to Slag are open")
	t.ok(not m.is_tier_open(&"ingot"), "later rows are not handed out")
	t.ok(m.mastery.level(&"slagrow_1") == 1, "Forge mastery moved to the Slag row")

	# every forge row has its pad object, three flicker frames each, and a stat colour
	for r: TierDef in rows:
		var art: String = String(TexelPad.FORGE_ART.get(r.id, ""))
		t.ok(art != "", "row %s has pad art" % r.id)
		for f in 3:
			t.ok(ResourceLoader.exists("%s%s_game_f%d.png" % [TexelPad.FORGE_DIR, art, f]), "%s frame %d exists" % [art, f])
		t.ok(TexelPad.STAT_COLORS.has(r.stat) and StatStyle.COLORS.has(r.stat), "%s has a stat colour" % r.stat)
