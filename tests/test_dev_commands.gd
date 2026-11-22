extends RefCounted
## Dev console commands (core/dev_commands.gd) against a real Sim.

func run(t: Object) -> void:
	t.ok(DevCommands.parse_amount("1e12").eq(BigNum.make(1.0, 12)), "1e12 parses")
	t.ok(DevCommands.parse_amount("2.5e300").eq(BigNum.make(2.5, 300)), "beyond float range parses")
	t.ok(DevCommands.parse_amount("5k").eq(BigNum.from_float(5000.0)), "5k parses")
	t.ok(DevCommands.parse_amount("2.5M").eq(BigNum.from_float(2.5e6)), "2.5M parses")
	t.ok(DevCommands.parse_amount("750").eq(BigNum.from_float(750.0)), "plain number parses")
	t.ok(DevCommands.parse_amount("abc") == null, "words are not numbers")
	t.ok(DevCommands.parse_amount("") == null, "empty is not a number")
	t.near(DevCommands.parse_duration("90"), 90.0, 0.0001, "bare seconds")
	t.near(DevCommands.parse_duration("15m"), 900.0, 0.0001, "minutes")
	t.near(DevCommands.parse_duration("3h"), 10800.0, 0.0001, "hours")
	t.near(DevCommands.parse_duration("2d"), 172800.0, 0.0001, "days")
	t.near(DevCommands.parse_duration("soon"), -1.0, 0.0001, "unreadable duration")

	var sim: Sim = t.make_sim()
	var c := DevCommands.new(sim)
	t.ok(c.run("help").contains("give"), "help lists commands")
	t.ok(c.run("nonsense").begins_with("Unknown command"), "unknown command is reported")
	t.eq(c.run(""), "", "blank line does nothing")

	var before: BigNum = sim.get_stat(&"cash")
	c.run("give cash 1000")
	t.ok(sim.get_stat(&"cash").eq(before.add(BigNum.from_float(1000.0))), "give adds to the stat")
	c.run("set cash 5")
	t.ok(sim.get_stat(&"cash").eq(BigNum.from_float(5.0)), "set replaces the stat")
	c.run("set cash 1e400")
	t.ok(sim.get_stat(&"cash").eq(BigNum.make(1.0, 400)), "set takes big numbers")
	t.ok(c.run("give nope 5").begins_with("No stat"), "unknown stat is reported")
	t.ok(c.run("give cash lots").contains("not a number"), "bad amount is reported")

	c.run("prestige 40")
	t.ok(sim.get_stat(sim.config.prestige_stat).eq(BigNum.from_float(40.0)), "prestige sets the prestige stat")
	c.run("rebirths 25")
	t.eq(sim.rebirth_count, 25, "rebirths sets the count")
	t.ok(sim.relics.slot_count() >= 4, "rebirths unlocks relic slots")

	var first: RelicDef = sim.relics.defs.values()[0]
	c.run("relic %s 3" % first.id)
	t.eq(sim.relics.stacks_of(first.id), 3, "relic gives stacks")
	var in_tier: int = 0
	for d: RelicDef in sim.relics.defs.values():
		if d.rarity.id == first.rarity.id:
			in_tier += 1
	var owned_before: int = sim.relics.stacks_of(first.id)
	c.run("relic rarity %s" % first.rarity.id)
	t.eq(sim.relics.stacks_of(first.id), owned_before + 1, "relic rarity gives one of each in the tier (%d)" % in_tier)
	c.run("relic all 2")
	var all_owned: bool = true
	for id: StringName in sim.relics.defs:
		all_owned = all_owned and sim.relics.stacks_of(id) >= 2
	t.ok(all_owned, "relic all gives every relic")
	t.ok(c.run("relic nope").begins_with("No relic"), "unknown relic is reported")
	t.ok(c.run("relic rarity nope").begins_with("No relics"), "unknown rarity is reported")

	var other: StringName = &""
	for id: StringName in sim.zone_defs:
		if id != sim.zone_id:
			other = id
	if other != &"":
		c.run("zone %s" % other)
		t.eq(sim.zone_id, other, "zone jumps even when locked")
		t.ok(sim.is_zone_unlocked(other), "the jump opens the way there")
	t.ok(c.run("zone nope").begins_with("No zone"), "unknown zone is reported")

	sim.new_game()
	sim.dev_set_stat(&"cash", BigNum.zero())
	var pad: StringName = sim.buttons_in_zone(sim.zone_id)[0].id
	t.ok(not sim.can_afford(pad), "with no cash the first pad is out of reach")
	c.run("god on")
	t.ok(sim.can_afford(pad), "god mode makes presses affordable")
	t.ok(sim.try_press(pad), "a god mode press goes through")
	t.ok(sim.get_stat(&"cash").gte(BigNum.zero()), "and costs nothing")
	c.run("god")
	t.ok(not sim.god_mode, "god with no argument toggles")

	var t0: float = sim.play_seconds
	c.run("skip 1h")
	t.near(sim.play_seconds - t0, 3600.0, 0.001, "skip fast forwards the clock")

	t.ok(c.run("reset").contains("confirm"), "reset asks first")
	t.ok(not c.needs_reload, "reset without confirm changes nothing")
	c.run("reset confirm")
	t.ok(c.needs_reload, "reset confirm asks for a reload")
	t.eq(sim.press_count, 0, "reset confirm starts a new game")

	var hits: Array = []
	c.register("ping", "test command", func(a: PackedStringArray) -> String:
		hits.append(a.size())
		return "pong")
	t.eq(c.run("ping 1 2"), "pong", "registered commands run")
	t.eq(hits, [2], "registered commands get their arguments")
