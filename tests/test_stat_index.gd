extends RefCounted
## StatIndex builds the rows for the Stats and Attributes index.

func run(t: Object) -> void:
	var sim: Sim = t.make_sim()
	var rows: Array[Dictionary] = StatIndex.stats(sim)
	var ids: Array = rows.map(func(r: Dictionary) -> Variant: return r["id"])
	for want: StringName in [&"cash", &"mult", &"reb", &"crit_chance", &"crit_damage", &"press_rate", &"luck", &"walk_speed", &"mastery", &"presses", &"play_time"]:
		t.ok(ids.has(want), "stats index lists %s" % want)
	for r: Dictionary in rows:
		t.ok(String(r["name"]) != "" and String(r["tip"]) != "", "%s has a name and a tooltip" % r["id"])
		t.ok(ResourceLoader.exists("res://assets/icons/%s.png" % r["icon"]), "%s icon exists (%s)" % [r["id"], r["icon"]])
	var attrs: Array[Dictionary] = StatIndex.attributes(sim)
	t.ok(attrs.size() >= sim.attribute_defs.size(), "attributes index lists every attribute")
	for r: Dictionary in attrs:
		t.ok(ResourceLoader.exists("res://assets/icons/%s.png" % r["icon"]), "attribute icon %s exists" % r["icon"])
	t.eq(StatIndex.clock_text(75.0), "1:15", "clock under an hour")
	t.eq(StatIndex.clock_text(3725.0), "1:02:05", "clock over an hour")
	t.eq(StatIndex._trim(2.0), "2", "whole numbers drop the decimal")
	t.eq(StatIndex._trim(2.5), "2.5", "one decimal kept")
