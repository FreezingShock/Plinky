extends RefCounted
## The Welcome Back model: the away line, the exact-amount text, the four sections, signs, counts, the cap note and the
## relic that sets the collect sound. Builds from a faked Sim.last_offline, so no save or scene is needed.


func run(t: Object) -> void:
	t.eq(WelcomeBack.away_text(480.0), "You were away 8 min.", "8 minutes reads in whole minutes")
	t.eq(WelcomeBack.away_text(7500.0), "You were away 2 h 5 min.", "hours once there are any")
	t.eq(WelcomeBack.away_text(50.0 * 3600.0), "You were away 2 days 2 h.", "past 48 hours reads in days")

	t.eq(NumberFormat.exact(BigNum.make(1.5, 3)), "1,500", "exact groups thousands with commas")
	t.eq(NumberFormat.exact(BigNum.make(8.581, 14)), "858,100,000,000,000", "exact keeps every digit up to 10^15")
	t.eq(NumberFormat.exact(BigNum.from_float(999.0)), "999", "a three digit amount has no comma")
	t.eq(NumberFormat.exact(BigNum.zero()), "0", "zero is zero")
	t.eq(NumberFormat.exact(BigNum.make(-2.0, 4)), "-20,000", "negative amounts keep their sign")
	t.eq(NumberFormat.exact(BigNum.make(1.5, -2)), NumberFormat.format(BigNum.make(1.5, -2)), "fractions fall back to the short form")

	var sim: Sim = t.make_sim()
	var stat_a: StringName = &"sunlight"
	var stat_b: StringName = &"dewdrop"
	var tier_id: StringName = &"sprout"
	var relic_a: StringName = sim.relics.defs.keys()[0]
	var relic_b: StringName = sim.relics.defs.keys()[1]
	var gains: Dictionary = {stat_a: BigNum.make(8.581, 14), stat_b: BigNum.make(7.5, 11), &"seeds": BigNum.zero()}
	sim.last_offline = {
		"spent": {stat_a: BigNum.make(2.8, 10)},
		"tend": {tier_id: {"presses": 25, "levels": 0, "level": 0}, &"clover": {"presses": 25, "levels": 1, "level": 4}},
		"relics": [relic_a, relic_b, relic_a],
	}
	var r: Dictionary = WelcomeBack.build(sim, 480.0, gains)
	t.eq(r["away_text"], "You were away 8 min.", "the card's away line comes from the model")
	t.eq(bool(r["capped"]), false, "8 minutes is not the cap")
	var secs: Array = r["sections"]
	var titles: Array = []
	for s_v: Variant in secs:
		titles.append((s_v as Dictionary)["title"])
	t.eq(titles, ["Earned", "Spent Tending", "Pads Tended", "Found"], "four sections, in order, with no empty ones")

	var earned: Array = (secs[0] as Dictionary)["tiles"]
	t.eq(earned.size(), 2, "zero gains are left out, so Earned has the two real ones")
	var first: Dictionary = _find(earned, stat_b)
	t.eq(first["kind"], &"gain", "earned tiles are gains")
	t.eq(first["prefix"], "+", "a gain is prefixed with plus")
	t.eq(first["text"], "+" + NumberFormat.format(BigNum.make(7.5, 11)), "gain text is the short amount with its plus")
	t.ok(first["amount"] is BigNum, "a gain counts up to a BigNum")
	t.ok((first["lines"] as Array)[0] == "Exact: %s" % NumberFormat.exact(BigNum.make(7.5, 11)), "the tooltip leads with the exact amount")

	var spent: Array = (secs[1] as Dictionary)["tiles"]
	t.eq(spent.size(), 1, "one spent tile for the one currency tended")
	t.eq((spent[0] as Dictionary)["prefix"], "-", "a spend is prefixed with minus")
	t.eq((spent[0] as Dictionary)["text"], "-" + NumberFormat.format(BigNum.make(2.8, 10)), "spend text is the short amount with its minus")

	var tend: Array = (secs[2] as Dictionary)["tiles"]
	t.eq(tend.size(), 2, "one tile per tended pad row")
	var sprout: Dictionary = _find(tend, tier_id)
	t.eq(sprout["text"], "x25", "tended rows show their presses")
	t.eq(sprout["count"], 25, "presses are kept as a count")
	t.eq(sprout["amount"], null, "a tended row shows its text, not a count-up")
	t.eq(sprout["icon"], "dewdrop", "a tended row draws its own stat's icon")
	t.eq(sprout["rarity"], &"common", "the sprout row is common, as in the ladder")
	var clover: Dictionary = _find(tend, &"clover")
	t.eq(clover["levels"], 1, "mastery levels gained show on the tile")
	t.eq(clover["level"], 4, "mastery level now shows on the tile")
	t.ok((clover["lines"] as Array).has("Mastery +1, now Level 4."), "the mastery line names the new level")
	t.ok((sprout["lines"] as Array).has("Mastery Level 0."), "a row with no mastery gain says its level")

	var found: Array = (secs[3] as Dictionary)["tiles"]
	t.eq(found.size(), 2, "one tile per relic found")
	var rel_a: Dictionary = found[0]
	t.eq(rel_a["text"], "x2", "a relic found twice reads as a count")
	t.eq(rel_a["count"], 2, "the count is kept")
	var rel_b: Dictionary = found[1]
	t.eq(rel_b["text"], "", "a relic found once shows no count")
	t.eq(rel_b["count"], 1, "a single find is counted as one")
	t.eq(r["tiles"], 7, "the tile total covers every section: 2 earned, 1 spent, 2 tended, 2 found")
	t.ok(String(r["best_rarity"]) != "", "the best relic rarity is named for the collect sound")

	t.eq(WelcomeBack.build(sim, sim.offline_cap_seconds(), gains)["capped"], true, "a full cap of away time is the most you can bank")

	sim.last_offline = {}
	var none: Dictionary = WelcomeBack.build(sim, 480.0, {})
	t.eq(none["tiles"], 0, "nothing gained, nothing spent: no tiles")
	t.eq(none["best_rarity"], &"", "no relic found means no best rarity")


## The tile whose id matches, so the checks do not depend on the order the sections happen to sort in.
func _find(tiles: Array, id: StringName) -> Dictionary:
	for d_v: Variant in tiles:
		if (d_v as Dictionary)["id"] == id:
			return d_v as Dictionary
	return {}
