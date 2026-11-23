extends RefCounted
## The customizable HUD stat strip: the layout model (core/hud_layout.gd), its place in the save, the edit-mode button
## and the settings rows. The strip itself (ui/hud.gd) needs the autoloads, so the CI boot smoke test covers it.

const MEADOW: Array[StringName] = [&"sunlight", &"dewdrop", &"clover", &"prestige", &"rp"]
const QUARRY: Array[StringName] = [&"cash", &"mult", &"slag", &"prestige", &"rp"]


func run(t: Object) -> void:
	SettingsFile.persist = false
	var l := HudLayout.new()
	var no_cash: Array[StringName] = [&"sunlight", &"dewdrop", &"prestige", &"rp"]
	var cash_pool: Array[StringName] = [&"cash"]
	var clover_cash: Array[StringName] = [&"clover", &"cash"]
	var pair: Array[StringName] = [&"s0", &"s1"]
	var cash_only: Array[StringName] = [&"cash"]
	t.ok(not l.is_custom(&"zone1"), "a new layout is on Default")
	t.eq(l.rows(&"zone1", MEADOW), MEADOW, "Default shows the zone's own rows in ladder order")

	t.ok(l.hide(&"zone1", &"clover", MEADOW), "hiding a row works")
	t.ok(l.is_custom(&"zone1"), "an edit makes the zone Custom")
	t.eq(l.rows(&"zone1", MEADOW), no_cash, "the hidden row is gone, the rest keep their order")
	t.eq(l.rows(&"zone2", QUARRY), QUARRY, "another zone is untouched")
	t.eq(l.suggestions(&"zone1", MEADOW, cash_pool), clover_cash, "suggestions are the zone's hidden rows, then stats met elsewhere")

	t.ok(l.add(&"zone1", &"cash", MEADOW), "a stat from another zone can be pinned")
	t.eq(l.rows(&"zone1", MEADOW)[-1], &"cash", "an added row goes to the bottom")
	t.ok(not l.add(&"zone1", &"cash", MEADOW), "adding twice does nothing")
	t.ok(l.move(&"zone1", &"cash", -1, MEADOW), "a row moves up")
	t.eq(l.rows(&"zone1", MEADOW).find(&"cash"), 3, "and lands one place higher")
	t.ok(not l.move(&"zone1", &"sunlight", -1, MEADOW), "the top row cannot move up")
	t.ok(not l.move(&"zone1", &"rp", 1, MEADOW), "the bottom row cannot move down")

	# The cap.
	var many: Array[StringName] = []
	for i in HudLayout.MAX_ROWS:
		many.append(StringName("s%d" % i))
	var cap := HudLayout.new()
	t.eq(cap.rows(&"z", many).size(), HudLayout.MAX_ROWS, "a full Default fits the cap")
	t.ok(cap.is_full(&"z", many), "a full strip reports full")
	t.ok(not cap.add(&"z", &"extra", many), "a full strip refuses another row")
	t.ok(cap.hide(&"z", &"s0", many) and cap.add(&"z", &"extra", many), "room opens up when a row is hidden")

	# The strip is never empty.
	var one := HudLayout.new()
	t.ok(one.hide(&"z", &"s0", pair), "one of two rows can go")
	t.ok(not one.hide(&"z", &"s1", pair), "the last row stays")

	# A stat the zone gains after an edit shows up (old layouts never hide new content).
	var grown: Array[StringName] = [&"sunlight", &"dewdrop", &"clover", &"prestige", &"rp", &"newstat"]
	t.ok(l.rows(&"zone1", grown).has(&"newstat"), "a stat added to the zone later appears on a custom layout")
	t.ok(l.hide(&"zone1", &"newstat", grown) and not l.rows(&"zone1", grown).has(&"newstat"), "and can then be hidden for good")

	l.reset(&"zone1")
	t.ok(not l.is_custom(&"zone1"), "Reset puts the zone back on Default")
	t.eq(l.rows(&"zone1", MEADOW), MEADOW, "with the usual rows")

	# Save format.
	var s := HudLayout.new()
	s.hide(&"zone1", &"dewdrop", MEADOW)
	s.add(&"zone1", &"cash", MEADOW)
	var back := HudLayout.new()
	back.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())), [&"sunlight", &"clover", &"prestige", &"rp", &"cash", &"dewdrop"])
	t.eq(back.rows(&"zone1", MEADOW), s.rows(&"zone1", MEADOW), "a layout survives a JSON round trip")
	var junk := HudLayout.new()
	junk.from_dict({"zone1": {"rows": ["ghost", "ghost"]}, "zone2": "oops", "zone3": {"rows": ["cash", "cash", 7]}}, [&"cash"])
	t.ok(not junk.is_custom(&"zone1") and not junk.is_custom(&"zone2"), "unknown ids and bad shapes fall back to Default")
	t.eq(junk.rows(&"zone3", cash_only), cash_only, "duplicates and non-ids are dropped")
	junk.from_dict(null)
	t.ok(not junk.is_custom(&"zone3"), "a missing value is the Default layout")

	# In the save, and old saves.
	var sim: Sim = t.make_sim()
	sim.hud_layout.hide(&"zone1", &"clover", MEADOW)
	var d: Dictionary = SaveCodec.decode(SaveCodec.encode(sim, 1000.0))
	var sim2: Sim = t.make_sim()
	t.ok(sim2.from_dict(d["game"]), "a save with a layout loads")
	t.ok(sim2.hud_layout.is_custom(&"zone1"), "the layout is saved with the game")
	(d["game"] as Dictionary).erase("hud_layout")
	t.ok(sim2.from_dict(d["game"]), "a save from before the strip was editable loads")
	t.ok(not sim2.hud_layout.is_custom(&"zone1"), "and starts on the Default layout")
	sim.new_game()
	t.ok(not sim.hud_layout.is_custom(&"zone1"), "a new game resets the layout")

	# The edit-mode button.
	var b: StripButton = StripButton.make(StripButton.Glyph.CLOSE)
	var hits: Array = []
	b.pressed.connect(func() -> void: hits.append(1))
	b.press()
	t.eq(hits.size(), 1, "a strip button reports a press")
	b.disabled = true
	b.press()
	t.eq(hits.size(), 1, "a disabled strip button does nothing")
	b.free()

	# Settings rows.
	for id: StringName in [&"strip_edit", &"strip_reset", &"strip_rates", &"strip_empty", &"strip_rclick"]:
		t.ok(not SettingsRegistry.find(id).is_empty(), "Settings has the %s row" % id)
	t.eq(SettingsRegistry.find(&"strip_rates")["default"], true, "gain rates show by default")
	t.eq(SettingsRegistry.find(&"strip_empty")["default"], false, "unearned rows stay hidden by default")
