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

	var before: BigNum = sim.get_stat(&"sunlight")
	c.run("give sunlight 1000")
	t.ok(sim.get_stat(&"sunlight").eq(before.add(BigNum.from_float(1000.0))), "give adds to the stat")
	c.run("set sunlight 5")
	t.ok(sim.get_stat(&"sunlight").eq(BigNum.from_float(5.0)), "set replaces the stat")
	c.run("set sunlight 1e400")
	t.ok(sim.get_stat(&"sunlight").eq(BigNum.make(1.0, 400)), "set takes big numbers")
	t.ok(c.run("give nope 5").begins_with("No stat"), "unknown stat is reported")
	t.ok(c.run("give sunlight lots").contains("not a number"), "bad amount is reported")

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
	sim.dev_set_stat(&"sunlight", BigNum.zero())
	var pad: StringName = &"sprout_1" if sim.zone_id == &"zone1" else sim.buttons_in_zone(sim.zone_id)[0].id
	t.ok(not sim.can_afford(pad), "with no cash the first pad is out of reach")
	c.run("god on")
	t.ok(sim.can_afford(pad), "god mode makes presses affordable")
	t.ok(sim.try_press(pad), "a god mode press goes through")
	t.ok(sim.get_stat(&"sunlight").gte(BigNum.zero()), "and costs nothing")
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

	# Short names, two-word commands and help.
	t.eq(DevCommands.resolve("g"), "give", "g is give")
	t.eq(DevCommands.resolve("Sea"), "season", "aliases ignore case")
	var hits2: Array = []
	c.register("probe lap", "test two-word command", func(a: PackedStringArray) -> String:
		hits2.append(a.size())
		return "lap")
	t.eq(c.run("probe lap 1 2"), "lap", "a two-word command runs")
	t.eq(hits2, [2], "a two-word command gets the rest of the line")
	t.ok(c.run("help time").contains("dawn"), "help time names the time words")
	t.ok(c.run("help nope").begins_with("No command"), "help for an unknown command is reported")
	t.ok(c.run("help").contains("g = give"), "help lists the short names")
	t.eq(c.usage_of("t"), "time [set <time> | add <amount>]", "usage_of resolves aliases")

	# Time of day, Minecraft-style. The calendar keeps its day; only the clock moves.
	var cal: GameCalendar = sim.calendar
	var day_before: int = cal.now()["total_day"]
	t.ok(c.run("time set noon").begins_with("Time is now"), "time set noon is accepted")
	t.eq(cal.now()["clock_text"], "12:00", "time set noon is 12:00")
	t.eq(cal.now()["total_day"], day_before, "time set keeps the day")
	c.run("time set 18:30")
	t.eq(cal.now()["clock_text"], "18:30", "time set takes hh:mm")
	c.run("time set midnight")
	t.eq(cal.now()["clock_text"], "00:00", "time set midnight is 00:00")
	c.run("time set night")
	t.ok(not cal.is_day(), "time set night is after sunset")
	c.run("time set day")
	t.ok(cal.is_day(), "time set day is in daylight")
	c.run("t noon")
	t.eq(cal.now()["clock_text"], "12:00", "t is the time alias and takes a bare word")
	t.ok(c.run("time set nope").contains("not a time"), "a bad time is reported")
	t.ok(c.run("time set").begins_with("Usage"), "time set needs a time")
	t.ok(c.run("time").contains("It is"), "time alone reads the clock")
	c.run("time set noon")
	var e0: float = cal.elapsed_days
	c.run("time add 2h")
	t.near(cal.elapsed_days - e0, 120.0 / 1440.0, 0.0001, "time add 2h moves two in-game hours")
	t.ok(c.run("time add nope").contains("not an amount"), "a bad time amount is reported")
	cal.set_day_fraction(0.25)
	t.eq(cal.now()["hour"], 6, "set_day_fraction moves the clock to 06:00")
	t.eq(cal.now()["total_day"], day_before, "set_day_fraction keeps the day")
	c.run("season set summer")
	t.eq(cal.season_index(), 1, "season set summer jumps to summer")

	t.near(DevCommands.time_fraction("dawn", 0.5), 0.25, 1e-9, "dawn is sunrise")
	t.near(DevCommands.time_fraction("dusk", 0.5), 0.75, 1e-9, "dusk is sunset")
	t.near(DevCommands.time_fraction("night", 0.5), 0.875, 1e-9, "night is between sunset and midnight")
	t.near(DevCommands.time_fraction("18:30"), 1110.0 / 1440.0, 1e-9, "hh:mm is minutes into the day")
	t.near(DevCommands.time_fraction("25:00"), -1.0, 1e-9, "hours past 23 are not a time")
	t.near(DevCommands.parse_game_minutes("2h"), 120.0, 1e-9, "2h is 120 in-game minutes")
	t.near(DevCommands.parse_game_minutes("1d"), 1440.0, 1e-9, "1d is a day")
	t.near(DevCommands.parse_game_minutes("45"), 45.0, 1e-9, "a bare number is minutes")
	t.near(DevCommands.parse_game_minutes("soon"), -1.0, 1e-9, "a word is not an amount")
	t.near(DevCommands.weather_level("rain"), 1.0, 1e-9, "rain forces rain")
	t.near(DevCommands.weather_level("auto"), -1.0, 1e-9, "auto gives the weather back to the sky")
	t.near(DevCommands.weather_level("snow"), -2.0, 1e-9, "unknown weather is reported")

	# Tab completion and suggestions.
	t.ok(c.complete("gi").has("give"), "tab completes a command from its first letters")
	t.ok(c.complete("give ").has("sunlight"), "tab suggests stat ids after give")
	t.ok(c.complete("give su").has("sunlight"), "and filters them by what is typed")
	t.eq(c.complete("time s"), PackedStringArray(["set"]), "time offers set")
	t.ok(c.complete("time set n").has("night") and c.complete("time set n").has("noon"), "time set offers the time words")
	t.ok(c.complete("").has("help"), "an empty line offers every command")
	t.ok(c.complete("help ").has("time"), "help offers command names")
	t.ok(c.complete("nonsense x").is_empty(), "an unknown command has no suggestions")

	# Reply colours.
	t.eq(DevCommands.reply_kind("Usage: give <stat>"), &"usage", "usage lines are usage")
	t.eq(DevCommands.reply_kind("No stat 'x'."), &"error", "a missing stat is an error")
	t.eq(DevCommands.reply_kind("'x' is not a number."), &"error", "a bad number is an error")
	t.eq(DevCommands.reply_kind("Gave 1 stack(s) each of 1 relic(s)."), &"ok", "success is ok")
	t.eq(DevCommands.reply_kind("This wipes your save. Type 'reset confirm'."), &"warn", "reset asks first")
