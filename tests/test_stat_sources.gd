extends RefCounted
## StatSources: every stat and attribute in the index explains itself.

func run(t: Object) -> void:
	var sim: Sim = t.make_sim()
	for r: Dictionary in StatIndex.stats(sim):
		var rows: Array[Dictionary] = sim.stat_sources(r["id"])
		t.ok(not rows.is_empty(), "%s has sources" % r["id"])
		for s: Dictionary in rows:
			t.ok(String(s["source"]) != "" and String(s["amount"]) != "" and String(s["how_to"]) != "", "%s source row is filled in (%s)" % [r["id"], s["source"]])
	for aid: StringName in sim.attribute_defs:
		t.ok(not sim.stat_sources(aid, true).is_empty(), "attribute %s has sources" % aid)
	t.ok(sim.stat_sources(&"nonsense").is_empty(), "unknown id gives no sources")
	sim.attr_levels[&"crit_chance"] = 3
	var rows: Array[Dictionary] = sim.stat_sources(&"crit_chance")
	t.eq(rows[0]["amount"], "3% crit chance", "crit chance shows the attribute's contribution")
