extends RefCounted
## The zone currencies (Seeds, Core Shards): their tooltip, the gift counts behind it, and the tier heads of their gifts.


func run(t: Object) -> void:
	var sim: Sim = t.make_sim()
	var bloom: ZoneResetDef = sim.reset_defs[&"bloom"] as ZoneResetDef
	var nucleus: ZoneResetDef = sim.reset_defs[&"nucleus"] as ZoneResetDef

	# Tier heads: the plural of a zone's name comes from its def, so the Nucleus heads read "Nuclei", not "Nucleuss".
	var nuc_two: AttributeDef = _first_gate(sim, &"shards", 2)
	var bloom_two: AttributeDef = _first_gate(sim, &"seeds", 2)
	var bloom_three: AttributeDef = _first_gate(sim, &"seeds", 3)
	t.ok(nucleus.plural_name == "Nuclei", "Nucleus has the plural Nuclei")
	t.ok(nuc_two != null and bloom_two != null and bloom_three != null, "the gift tiers exist to check their heads")
	if nuc_two != null:
		t.eq(UpgradeText.tier_head(sim, nuc_two), "Unlocks After 2 Nuclei", "a Nucleus tier head uses the plural")
	if bloom_two != null:
		t.eq(UpgradeText.tier_head(sim, bloom_two), "Unlocks After 2 Blooms", "a Bloom tier head adds an s")
	if bloom_three != null:
		t.eq(UpgradeText.tier_head(sim, bloom_three), "Unlocks After 3 Blooms", "a Bloom tier head pluralises past one")
		# The tier rail's gate: what the tier requires, in the same plural rules.
		t.eq(UpgradeText.tier_gate(sim, bloom_three), "Requires 3 Blooms", "a rail gate pluralises Blooms past one")
	# One Bloom stays singular. No tier gates on 1 now, so check the text on a bare gift with that gate.
	var one: AttributeDef = AttributeDef.new()
	one.currency = &"seeds"
	one.unlock_resets = 1
	t.eq(UpgradeText.tier_gate(sim, one), "Requires 1 Bloom", "a rail gate reads Requires 1 Bloom")
	if bloom_two != null:
		t.eq(UpgradeText.tier_gate(sim, bloom_two), "Requires 2 Blooms", "a rail gate pluralises Blooms")
	if nuc_two != null:
		t.eq(UpgradeText.tier_gate(sim, nuc_two), "Requires 2 Nuclei", "a rail gate uses the Nucleus plural")
	var start: AttributeDef = _first_gate(sim, &"seeds", 0)
	if start != null:
		t.eq(UpgradeText.tier_gate(sim, start), "Open", "the start tier has no gate")

	# Gift counts: every Seeds gift is counted, none bought at the start, and affordable ones show once Seeds arrive.
	var seeds_total: int = 0
	for a: AttributeDef in sim.attribute_defs.values():
		if a.currency == &"seeds":
			seeds_total += 1
	var c0: Dictionary = UpgradeText.gift_counts(sim, &"seeds")
	t.eq(int(c0["total"]), seeds_total, "gift counts cover every Seeds gift")
	t.eq(int(c0["bought"]), 0, "no Bloom gift is bought at the start")
	sim.stats[&"seeds"] = BigNum.from_float(500.0)
	var c1: Dictionary = UpgradeText.gift_counts(sim, &"seeds")
	t.ok(int(c1["affordable"]) >= 1, "open Bloom gifts count as affordable with Seeds in hand")
	t.ok(int(c1["affordable"]) <= int(c1["total"]), "affordable never exceeds the total")
	t.ok(sim.buy_attribute(&"bloom_head_start"), "a Bloom gift can be bought")
	t.eq(int(UpgradeText.gift_counts(sim, &"seeds")["bought"]), 1, "one bought gift is counted")

	# The tooltip: rich lines, the zone's own copy, the yellow call to action only on a row that opens the gifts.
	var ready: Dictionary = {"can": true, "gain": 3, "need": "", "bought": 1, "total": 15, "affordable": 2}
	var spec: Dictionary = TipText.currency(&"seeds", "Seeds", "11.97K", bloom, ready, true)
	t.eq(spec["title"], "Seeds", "the currency tooltip is titled by its name")
	t.eq(spec["body"], bloom.currency_body, "the tooltip body is the zone's own currency copy")
	t.eq(spec["hint"], "Click to open!", "a row that opens the gifts ends on Click to open!")
	t.eq(str((spec["kicker"] as Array)[0]["t"]), "BLOOM CURRENCY", "the kicker tags the currency with its zone")
	t.ok(_text(spec["lines"][1]).begins_with("Next Bloom +3 Seeds"), "a ready reset says what it pays next")
	t.ok(_text(spec["lines"][2]) == "Gifts 1 of 15 bought", "the tooltip counts the bought gifts")
	t.ok(_text(spec["lines"][3]) == "Affordable 2 now", "the tooltip counts the gifts you can buy now")

	var waiting: Dictionary = {"can": false, "gain": 0, "need": "Reach 250 Starbloom.", "bought": 0, "total": 15, "affordable": 0}
	var plain: Dictionary = TipText.currency(&"shards", "Core Shards", "6.85", nucleus, waiting, false)
	t.eq(plain["hint"], "", "the header badge has no call to action, the menu is already open")
	t.eq(_text(plain["lines"][1]), "Reach 250 Starbloom.", "a reset not ready says what it needs")
	t.eq(plain["lines"].size(), 3, "no Affordable line when no gift can be bought now")
	t.eq(str((plain["kicker"] as Array)[0]["t"]), "NUCLEUS CURRENCY", "the Core Shards kicker names the Nucleus")


static func _text(line: Array) -> String:
	var out: String = ""
	for seg: Variant in line:
		if seg is String:
			out += str(seg)
		elif seg is Dictionary and (seg as Dictionary).has("t"):
			out += str((seg as Dictionary)["t"])
	return out


static func _first_gate(sim: Sim, cur: StringName, resets: int) -> AttributeDef:
	for a: AttributeDef in sim.attribute_defs.values():
		if a.currency == cur and a.unlock_resets == resets:
			return a
	return null
