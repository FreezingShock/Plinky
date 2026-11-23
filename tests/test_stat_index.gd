extends RefCounted
## StatIndex builds the rows for the Stats and Attributes index.

func run(t: Object) -> void:
	var sim: Sim = t.make_sim()
	var rows: Array[Dictionary] = StatIndex.stats(sim)
	var ids: Array = rows.map(func(r: Dictionary) -> Variant: return r["id"])
	for want: StringName in [&"sunlight", &"dewdrop", &"clover", &"crit_chance", &"crit_damage", &"press_rate", &"luck", &"walk_speed", &"mastery", &"presses", &"play_time"]:
		t.ok(ids.has(want), "stats index lists %s" % want)
	for r: Dictionary in rows:
		t.ok(String(r["name"]) != "" and String(r["tip"]) != "", "%s has a name and a tooltip" % r["id"])
		t.ok(ResourceLoader.exists("res://assets/icons/%s.png" % r["icon"]), "%s icon exists (%s)" % [r["id"], r["icon"]])
	var attrs: Array[Dictionary] = StatIndex.attributes(sim)
	t.ok(attrs.size() >= sim.attribute_defs.size(), "attributes index lists every attribute")
	for r: Dictionary in attrs:
		t.ok(ResourceLoader.exists("res://assets/icons/%s.png" % r["icon"]), "attribute icon %s exists" % r["icon"])
	for r: Dictionary in rows + attrs:
		t.ok(String(r["short"]).length() <= StatIndex.MAX_LABEL, "%s fits its card (%s)" % [r["id"], r["short"]])
		t.eq(StatIndex.title_case(String(r["name"])), String(r["name"]), "%s name is Title Case" % r["id"])
	var perk_icons: Array = []
	for r: Dictionary in attrs:
		if String(r["group"]) == "Rebirth Perks":
			perk_icons.append(r["icon"])
	t.ok(perk_icons.size() == 3 and perk_icons.size() == perk_icons.duplicate().filter(func(i: Variant) -> bool: return perk_icons.count(i) == 1).size(), "the three RP perks each have their own icon")
	t.eq(StatIndex.title_case("quick study"), "Quick Study", "title case")
	t.eq(StatIndex.clock_text(75.0), "1:15", "clock under an hour")
	t.eq(StatIndex.clock_text(3725.0), "1:02:05", "clock over an hour")
	t.eq(StatIndex._trim(2.0), "2", "whole numbers drop the decimal")
	t.eq(StatIndex._trim(2.5), "2.5", "one decimal kept")
