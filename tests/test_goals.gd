extends RefCounted
## Mid-game goals: content, the chain, reached goals and their press bonus, the zone_resets counter, saves (including
## saves from before goals existed), and the pure parts of the Next Goal card.

func run(t: Object) -> void:
	var sim: Sim = t.make_sim()
	var g: Goals = sim.goals
	t.ok(g.total() >= 10 and g.total() <= 16, "there are 10 to 16 goals (%d)" % g.total())
	t.eq(sim.validate().size(), 0, "goal content validates against counters and targets")
	var seen: Dictionary = {}
	var last_order: int = -1
	var chain_ok: bool = true
	for d: GoalDef in g.sorted:
		t.ok(d.display_name != "" and d.description != "" and not d.display_name.to_lower().contains("plinko"), "%s has a name and a description" % d.id)
		t.ok(d.reward > 0.0 and d.reward <= 0.05, "%s pays a small bonus (%.2f)" % [d.id, d.reward])
		t.ok(not seen.has(d.id), "%s is unique" % d.id)
		seen[d.id] = true
		if d.order <= last_order:
			chain_ok = false
		last_order = d.order
	t.ok(chain_ok, "goals sit in a strict chain by order")

	# A new game: nothing reached, no bonus, the first goal is next.
	t.eq(g.reached_count(), 0, "a new game has no goals reached")
	t.near(g.mult(), 1.0, 1e-9, "and no press bonus")
	t.eq(g.next_goal().id, g.sorted[0].id, "the first goal is next")

	# Reaching one: signal, log, bonus.
	var got: Array[StringName] = []
	sim.goal_reached.connect(func(id: StringName) -> void: got.append(id))
	sim.check_achievements()
	t.eq(got.size(), 0, "nothing is reached before it is earned")
	sim.press_count = 999
	sim.check_achievements()
	t.eq(got.size(), 0, "999 presses is one short of the first goal")
	sim.press_count = 1000
	sim.check_achievements()
	t.eq(got, [&"goal_presses_1k"] as Array[StringName], "1,000 presses reaches the first goal, once")
	t.ok(g.is_reached(&"goal_presses_1k"), "and it is in the log")
	t.near(g.mult(), 1.0 + g.defs[&"goal_presses_1k"].reward, 1e-9, "its reward is the press bonus")
	t.eq(g.next_goal().id, g.sorted[1].id, "the next goal moves on")
	sim.check_achievements()
	t.eq(got.size(), 1, "a reached goal does not fire again")

	# The bonus reaches press gain on the pad itself.
	var button_id: StringName = sim.button_defs.keys()[0]
	sim.goals.clear()
	var base: float = sim.press_gain(button_id).to_float()
	sim.goals.from_dict({"log": ["goal_presses_1k"]})
	var boosted: float = sim.press_gain(button_id).to_float()
	t.ok(base > 0.0, "a press pays something before any goal")
	t.near(boosted / base, 1.0 + g.defs[&"goal_presses_1k"].reward, 1e-6, "a reached goal scales press gain by its bonus")

	# Reached goals stay reached when the counters fall back (a reset does not take them away).
	sim.press_count = 0
	sim.check_achievements()
	t.ok(g.is_reached(&"goal_presses_1k"), "a goal stays reached after its counter falls")
	t.eq(got.size(), 1, "and falling back fires nothing")

	# Zone resets count every use of every zone's reset.
	sim.reset_counts[&"bloom"] = 1
	t.near(sim.achievement_counters()[&"zone_resets"], 1.0, 1e-9, "zone_resets counts the uses of a reset")
	sim.check_achievements()
	t.ok(g.is_reached(&"goal_resets_1"), "the first zone reset reaches its goal")
	sim.reset_counts[&"bloom"] = 3
	sim.check_achievements()
	t.ok(g.is_reached(&"goal_resets_3"), "three resets reach the third")

	# Save round trip: same log, same bonus, and loading announces nothing.
	var data: Dictionary = SaveCodec.decode(SaveCodec.encode(sim, 1.0))["game"]
	var sim2: Sim = t.make_sim()
	var got2: Array[StringName] = []
	sim2.goal_reached.connect(func(id: StringName) -> void: got2.append(id))
	t.ok(sim2.from_dict(data), "a save with goals loads")
	t.eq(sim2.goals.log, g.log, "reached goals survive a save in order")
	t.near(sim2.goals.mult(), g.mult(), 1e-9, "and keep their bonus")
	t.eq(got2.size(), 0, "loading announces no goals")

	# A save from before goals existed: what it has already earned counts, silently.
	var old: Dictionary = data.duplicate(true)
	old.erase("goals")
	old["press_count"] = 10000
	var sim3: Sim = t.make_sim()
	var got3: Array[StringName] = []
	sim3.goal_reached.connect(func(id: StringName) -> void: got3.append(id))
	t.ok(sim3.from_dict(old), "a save with no goals key loads")
	t.ok(sim3.goals.is_reached(&"goal_presses_1k") and sim3.goals.is_reached(&"goal_presses_10k"), "earlier presses credit the goals they cover")
	t.eq(got3.size(), 0, "with no pop-ups")

	# Bad saved ids are dropped, repeats ignored.
	var junk: Goals = Goals.new(sim.goals.sorted)
	junk.from_dict({"log": ["nope", "goal_presses_1k", "goal_presses_1k"]})
	t.eq(junk.reached_count(), 1, "unknown and repeated goal ids are dropped")
	junk.from_dict("not a dict")
	t.eq(junk.reached_count(), 0, "a malformed goals value never throws")

	# Validation catches a bad goal.
	var bad_def := GoalDef.new()
	bad_def.id = &"goal_bad"
	bad_def.display_name = "Bad"
	bad_def.counter = &"no_such_counter"
	bad_def.target = 1.0
	var sim4: Sim = t.make_sim()
	sim4.goals = Goals.new([bad_def])
	var errs: PackedStringArray = sim4.validate()
	t.ok(errs.size() > 0 and str(errs).contains("goal goal_bad"), "an unknown goal counter fails validation")

	# The Next Goal card's pure view.
	var fresh := Goals.new(sim.goals.sorted)
	var empty_counters: Dictionary = {&"presses": 500.0}
	var v: Dictionary = NextGoalCard.view_for(fresh, empty_counters)
	t.eq(v["name"], "Steady Hands", "the card names the first goal")
	t.near(float(v["progress"]), 0.5, 1e-9, "its progress is the share of the target")
	t.eq(v["detail"], "500 / 1K  +2%", "its detail reads progress and the bonus")
	t.eq(bool(v["done"]), false, "not done while goals remain")
	fresh.check({&"presses": 1000.0, &"play_hours": 1.0, &"crits": 250.0, &"mastery_best": 5.0, &"zone_resets": 1.0,
		&"gates_open": 2.0, &"attributes_bought": 10.0, &"relic_kinds": 6.0})
	fresh.check({&"presses": 1.0e9, &"play_hours": 99.0, &"crits": 1.0e6, &"mastery_best": 99.0, &"zone_resets": 99.0,
		&"gates_open": 9.0, &"attributes_bought": 99.0, &"relic_kinds": 9.0})
	var done_v: Dictionary = NextGoalCard.view_for(fresh, {})
	t.eq(bool(done_v["done"]), true, "the card reads done once the chain is finished")
	t.near(float(done_v["bonus"]), fresh.mult() - 1.0, 1e-9, "and shows the total bonus")
	var ann: Dictionary = NextGoalCard.announcement(sim.goals.sorted[0])
	t.eq(ann["title"], "Goal Reached", "the banner is titled Goal Reached")
	t.ok(str(ann["key"]).begins_with("goal_"), "with a key per goal, so it never repeats")
