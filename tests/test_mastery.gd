extends RefCounted
## Pad mastery: XP, levels, yield and crit bonuses, area rollup, save round trip and the v1 -> v2 migration.

func run(t: Object) -> void:
	var sim: Sim = t.make_sim()
	var cfg: MasteryConfig = sim.mastery.config
	t.ok(cfg.max_level > 0 and cfg.first_level_xp > 0.0, "mastery config loads from content")
	t.eq(sim.mastery.level(&"m1"), 0, "new pad starts at level 0")
	t.near(sim.mastery.yield_mult(&"m1"), 1.0, 1e-9, "level 0 has no yield bonus")

	# XP and levelling
	var changed: Array = []
	var leveled: Array = []
	sim.mastery_changed.connect(func(id: StringName, lv: int, xp: float) -> void: changed.append([id, lv, xp]))
	sim.mastery_leveled.connect(func(id: StringName, lv: int) -> void: leveled.append([id, lv]))
	sim.god_mode = true
	var need: int = ceili(cfg.first_level_xp / cfg.xp_per_press)
	for i in need - 1:
		sim.try_press(&"m1")
	t.eq(sim.mastery.level(&"m1"), 0, "one press short of level 1")
	t.eq(leveled.size(), 0, "no level-up signal yet")
	sim.try_press(&"m1")
	t.eq(sim.mastery.level(&"m1"), 1, "enough presses reach level 1")
	t.eq(leveled.size(), 1, "mastery_leveled fires once")
	t.eq(leveled[0][1], 1, "signal carries the new level")
	t.eq(changed.size(), need, "mastery_changed fires on every press")
	t.near(sim.mastery.yield_mult(&"m1"), 1.0 + cfg.yield_per_level, 1e-9, "level 1 yield")
	t.ok(sim.mastery.xp_for_next(1) > sim.mastery.xp_for_next(0), "each level costs more XP than the last")
	t.eq(sim.mastery.level(&"m2"), 0, "other pads are untouched")

	# Yield shows up in the press gain
	sim.new_game()
	sim.god_mode = true
	var base: float = sim.press_gain_preview(&"m1").to_float()
	sim.mastery.add_xp(&"m1", 1.0e9)
	t.eq(sim.mastery.level(&"m1"), cfg.max_level, "huge XP caps at max level")
	t.near(sim.mastery.progress(&"m1"), 1.0, 1e-9, "progress is full at the cap")
	t.near(sim.mastery.xp_for_next(cfg.max_level), 0.0, 1e-9, "no XP needed past the cap")
	t.near(sim.press_gain_preview(&"m1").to_float(), base * (1.0 + cfg.max_level * cfg.yield_per_level), 1e-9, "max mastery pays the full yield bonus")
	t.ok(sim.mastery.yield_mult(&"m1") <= 2.0, "mastery yield stays a modest bonus")
	var before: float = sim.get_stat(&"mult").to_float()
	var last_crit: Array[bool] = []
	sim.button_pressed.connect(func(_id: StringName, _p: Vector3, _g: BigNum, crit: bool) -> void: last_crit.append(crit))
	sim.try_press(&"m1")
	# Max mastery adds crit chance, so the press may crit; the pay is the boosted gain times the crit multiplier then.
	var mult: float = sim.crit_damage(&"m1") if (last_crit.size() > 0 and last_crit[0]) else 1.0
	t.near(sim.get_stat(&"mult").to_float() - before, base * sim.mastery.yield_mult(&"m1") * mult, 1e-9, "a press at max mastery pays the boosted gain")

	# Crit stats
	t.near(sim.crit_chance(), sim.effect_total(&"crit_chance"), 1e-9, "global crit chance ignores pad mastery")
	t.near(sim.crit_chance(&"m1"), cfg.max_level * cfg.crit_chance_per_level + sim.effect_total(&"crit_chance"), 1e-9, "pad crit chance adds mastery")
	t.near(sim.crit_damage(&"m1"), sim.crit_damage() + cfg.max_level * cfg.crit_damage_per_level, 1e-9, "pad crit damage adds mastery")
	t.near(sim.crit_damage(), sim.config.crit_multiplier, 1e-9, "crit damage is the config multiplier with no relics")
	var crits: Array = []
	sim.button_pressed.connect(func(_id: StringName, _p: Vector3, g: BigNum, c: bool) -> void: crits.append([g.to_float(), c]))
	sim.attr_levels[&"crit_chance"] = 25
	sim.mastery.add_xp(&"m2", 1.0e9)
	var crit_gain: float = 0.0
	for i in 400:
		sim.try_press(&"m2")
	for e: Array in crits:
		if e[1]:
			crit_gain = e[0]
			break
	t.ok(crit_gain > 0.0, "crits happen with crit chance (25 attribute levels plus mastery)")
	t.near(crit_gain, sim.press_gain_preview(&"m2").to_float() * sim.crit_damage(&"m2"), 1e-9, "a crit pays reward x crit damage, mastery included")

	# Area rollup
	sim.new_game()
	var empty: Dictionary = sim.area_mastery(&"zone1")
	t.eq(empty["level_sum"], 0, "fresh area has no mastery levels")
	t.near(empty["fraction"], 0.0, 1e-9, "fresh area fraction is 0")
	t.eq(empty["pads"], sim.buttons_in_zone(&"zone1").size(), "area counts its pads")
	sim.mastery.add_xp(&"m1", 1.0e9)
	var a1: Dictionary = sim.area_mastery(&"zone1")
	t.eq(a1["level_sum"], cfg.max_level, "area sums pad levels")
	t.eq(a1["maxed"], 1, "area counts maxed pads")
	t.near(a1["fraction"], float(cfg.max_level) / float(a1["pads"] * cfg.max_level), 1e-9, "area fraction")
	t.eq(sim.area_mastery(&"larkmoor")["level_sum"], 0, "other areas do not roll up this pad")

	# Save round trip, rebirth keeps mastery, new game clears it
	sim.mastery.add_xp(&"m2", 30.0)
	var lv2: int = sim.mastery.level(&"m2")
	var xp2: float = sim.mastery.xp(&"m2")
	var d: Dictionary = SaveCodec.decode(SaveCodec.encode(sim, 1000.0))
	var sim2: Sim = t.make_sim()
	sim2.from_dict(d["game"])
	t.eq(sim2.mastery.level(&"m1"), cfg.max_level, "max level survives a save")
	t.eq(sim2.mastery.level(&"m2"), lv2, "level survives a save")
	t.near(sim2.mastery.xp(&"m2"), xp2, 1e-9, "XP inside the level survives a save")
	sim.stats[&"reb"] = BigNum.from_float(5.0)
	t.ok(sim.try_rebirth(), "rebirth")
	t.eq(sim.mastery.level(&"m1"), cfg.max_level, "rebirth keeps mastery")
	sim.new_game()
	t.eq(sim.mastery.level(&"m1"), 0, "new game clears mastery")

	# Bad data never throws, unknown ids and big levels are tamed
	sim2.from_dict({"mastery": {"m1": [9999, 5.0], "ghost": [3, 1.0], "m2": "oops", "m3": [-4, -2.0]}})
	t.eq(sim2.mastery.level(&"m1"), cfg.max_level, "saved level clamps to the cap")
	t.eq(sim2.mastery.level(&"m2"), 0, "malformed entry is ignored")
	t.eq(sim2.mastery.level(&"m3"), 0, "negative level clamps to 0")
	t.near(sim2.mastery.xp(&"m3"), 0.0, 1e-9, "negative XP clamps to 0")
	t.eq(sim2.mastery.level(&"ghost"), 0, "unknown pad id is dropped")
	sim2.from_dict({"mastery": 7})
	t.eq(sim2.mastery.level(&"m1"), 0, "non-dictionary mastery is ignored")

	# Migration: a version 1 save has no mastery and loads with every pad at 0
	var old: Dictionary = SaveCodec.decode('{"version": 1, "saved_at": 5, "game": {"zone": "zone1", "press_count": 3}}')
	t.ok(not old.is_empty(), "version 1 save still decodes")
	t.eq(old["version"], SaveCodec.CURRENT_VERSION, "migrated to the current version")
	t.ok((old["game"] as Dictionary).has("mastery"), "migration adds the mastery key")
	var sim3: Sim = t.make_sim()
	t.ok(sim3.from_dict(old["game"]), "migrated save loads")
	t.eq(sim3.press_count, 3, "migration keeps existing fields")
	t.eq(sim3.mastery.level(&"m1"), 0, "migrated save starts at level 0")
	t.ok(SaveCodec.CURRENT_VERSION >= 2, "save version includes mastery (v2 and later)")
