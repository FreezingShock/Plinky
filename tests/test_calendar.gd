extends RefCounted
## Calendar: day/month/season/year math, crossfade weights, signals, save round trip and v2 migration, season look
## blending, and the sky's 3 min day / 2 min night split.

func run(t: Object) -> void:
	var cfg: CalendarConfig = load("res://content/config/calendar.tres") as CalendarConfig
	t.ok(cfg != null, "calendar.tres loads as CalendarConfig")
	if cfg == null:
		return
	var sky: SkyConfig = load("res://content/config/sky.tres") as SkyConfig
	t.near(sky.day_seconds, 300.0, 1e-6, "an in-game day is 5 real minutes")
	t.near(sky.daylight_fraction, 0.6, 1e-6, "3 of the 5 minutes are daylight")
	t.eq(cfg.season_names.size(), 4, "four named seasons")
	t.eq(cfg.month_names.size(), 8, "eight named months")
	t.eq(cfg.season_colors.size(), 4, "four season colours")
	for arr_size: int in [cfg.ground_col.size(), cfg.ground_col2.size(), cfg.prop_col.size(), cfg.prop_col2.size(),
			cfg.grade_tint.size(), cfg.haze_col.size(), cfg.ground_amt.size(), cfg.prop_amt.size(),
			cfg.ground_snow.size(), cfg.prop_snow.size(), cfg.haze_mix.size(), cfg.fog_mult.size(), cfg.particle_counts.size()]:
		t.eq(arr_size, 4, "season look arrays have one entry per season")

	var c := GameCalendar.new(cfg, 300.0)
	t.eq(c.days_per_year(), 40, "a year is 40 days")
	t.eq(c.days_per_season(), 10, "a season is 10 days")
	var n: Dictionary = c.now()
	t.eq(n["year"], 1, "starts in year 1")
	t.eq(n["day"], 1, "starts on day 1")
	t.eq(n["season"], 0, "starts in spring")
	t.eq(n["month"], 0, "starts in the first month")
	t.eq(n["clock_text"], "07:12", "starts at 07:12")
	t.ok(n["is_day"], "the first morning is daylight")
	t.eq(String(n["season_name"]), "Spring", "spring is Spring")

	# Day 5 is the last of month 1; day 6 starts month 2.
	c.elapsed_days = 4.5
	t.eq(c.now()["day"], 5, "day 5 of month")
	t.eq(c.now()["month"], 0, "still the first month")
	c.elapsed_days = 5.1
	t.eq(c.now()["day"], 1, "day wraps to 1 after 5 days")
	t.eq(c.now()["month"], 1, "second month")
	t.eq(c.now()["season"], 0, "two months share a season")
	c.elapsed_days = 10.2
	t.eq(c.now()["season"], 1, "season changes after 10 days")
	c.elapsed_days = 39.9
	t.eq(c.now()["season"], 3, "winter is the last season")
	c.elapsed_days = 40.1
	t.eq(c.now()["year"], 2, "year rolls after 40 days")
	t.eq(c.now()["season"], 0, "and spring returns")

	# Signals fire once per boundary.
	var c2 := GameCalendar.new(cfg, 300.0)
	var counts: Dictionary = {"day": 0, "month": 0, "season": 0, "year": 0}
	c2.day_changed.connect(func(_d: int) -> void: counts["day"] += 1)
	c2.month_changed.connect(func(_m: int) -> void: counts["month"] += 1)
	c2.season_changed.connect(func(_s: int) -> void: counts["season"] += 1)
	c2.year_changed.connect(func(_y: int) -> void: counts["year"] += 1)
	c2.advance(300.0 * 0.5)
	t.eq(counts["day"], 0, "no signal inside a day")
	c2.advance(300.0 * 0.3)
	t.eq(counts["day"], 1, "one day signal at midnight")
	c2.skip_days(4.0)
	t.eq(counts["month"], 1, "month signal after 5 days")
	c2.skip_days(5.0)
	t.eq(counts["season"], 1, "season signal after 10 days")
	c2.skip_days(30.0)
	t.eq(counts["year"], 1, "year signal after 40 days")
	t.eq(counts["season"], 2, "and a season change with it")
	c2.advance(1.0)
	t.eq(counts["season"], 2, "no repeat signal")

	# Crossfade weights: sum to 1, no pop, pure at the start of a season.
	var sums_ok: bool = true
	var smooth: bool = true
	var prev: Array[float] = c.season_weights()
	var d: float = 0.0
	while d < 41.0:
		c.elapsed_days = d
		var w: Array[float] = c.season_weights()
		if absf(w[0] + w[1] + w[2] + w[3] - 1.0) > 1e-5:
			sums_ok = false
		for i in 4:
			if absf(w[i] - prev[i]) > 0.06:
				smooth = false
		prev = w
		d += 0.01
	t.ok(sums_ok, "season weights always sum to 1")
	t.ok(smooth, "season weights move in small steps across a whole year")
	c.elapsed_days = 10.0
	t.near(c.season_weights()[1], 1.0, 1e-6, "summer's first day is pure summer")
	c.elapsed_days = 9.7
	var wb: Array[float] = c.season_weights()
	t.ok(wb[0] > 0.0 and wb[1] > 0.0, "the last day of spring blends into summer")

	# Save: elapsed_days round trips, old saves get the default start.
	var sim: Sim = t.make_sim()
	sim.calendar.elapsed_days = 23.45
	var text: String = SaveCodec.encode(sim, 5.0)
	var dd: Dictionary = SaveCodec.decode(text)
	var sim2: Sim = t.make_sim()
	sim2.from_dict(dd["game"])
	t.near(sim2.calendar.elapsed_days, 23.45, 1e-6, "calendar survives a save")
	var old: String = '{"version": 2, "saved_at": 1.0, "game": {"zone": "zone1"}}'
	var od: Dictionary = SaveCodec.decode(old)
	t.ok(not od.is_empty(), "a v2 save still loads")
	t.eq(int(od["version"]), SaveCodec.CURRENT_VERSION, "and is migrated to the current version")
	t.ok((od["game"] as Dictionary).has("calendar"), "migration adds the calendar")
	var sim3: Sim = t.make_sim()
	sim3.from_dict(od["game"])
	t.near(sim3.calendar.elapsed_days, cfg.start_elapsed_days, 1e-6, "an old save starts on the first morning")
	sim3.from_dict({"calendar": {"elapsed_days": -5}})
	t.near(sim3.calendar.elapsed_days, cfg.start_elapsed_days, 1e-6, "a bad calendar value falls back")
	var before: float = sim3.calendar.elapsed_days
	sim3.step(0.1)
	t.ok(sim3.calendar.elapsed_days > before, "the sim ticks the calendar")

	# Season look: blends without washing out, winter has snow, spring does not.
	var spring: SeasonLook = SeasonLook.blend(cfg, [1.0, 0.0, 0.0, 0.0] as Array[float])
	var winter: SeasonLook = SeasonLook.blend(cfg, [0.0, 0.0, 0.0, 1.0] as Array[float])
	var autumn: SeasonLook = SeasonLook.blend(cfg, [0.0, 0.0, 1.0, 0.0] as Array[float])
	t.near(spring.ground_snow, 0.0, 1e-6, "no snow in spring")
	t.ok(winter.ground_snow > 0.5 and winter.prop_snow > 0.5, "winter lays snow")
	t.ok(autumn.prop_amt > 0.5, "autumn recolours most foliage")
	t.ok(winter.fog_mult > spring.fog_mult, "winter is foggier than spring")
	var mid: SeasonLook = SeasonLook.blend(cfg, [0.0, 0.0, 0.5, 0.5] as Array[float])
	t.ok(mid.ground_snow > 0.0 and mid.ground_snow < winter.ground_snow, "the autumn to winter blend has less snow")
	t.ok(mid.prop_col.r > 0.0 and mid.prop_col.r <= 1.0, "blended colours stay in range")

	# Sky: 60 percent daylight on the linear clock, and the clock helpers invert each other.
	var m := SkyModel.new()
	m.day_seconds = 300.0
	m.daylight_fraction = 0.6
	m.start_phase = 0.0
	var day_secs: int = 0
	for s in 300:
		if SkyModel.sun_of(m.phase(float(s) + 0.5)) > 0.0:
			day_secs += 1
	t.ok(absi(day_secs - 180) <= 1, "180 of 300 seconds have the sun up")
	var inv_ok: bool = true
	for k in 50:
		var p: float = float(k) / 50.0
		if absf(fposmod(m.phase_of_clock(m.clock_of_phase(p)) - p + 0.5, 1.0) - 0.5) > 1e-5:
			inv_ok = false
	t.ok(inv_ok, "clock_of_phase and phase_of_clock are inverses")
	t.near(m.phase(0.0), 0.0, 1e-6, "midnight on the clock is midnight in the sky")
	t.near(m.phase(150.0), 0.5, 1e-6, "noon on the clock is noon in the sky")

	# Dev commands.
	var cmds := DevCommands.new(sim)
	t.ok(cmds.run("season winter").contains("Winter"), "season winter jumps to winter")
	t.eq(sim.calendar.now()["season"], 3, "the calendar is in winter")
	t.ok(cmds.run("season").contains("Winter"), "season alone reports the calendar")
	t.ok(cmds.run("season nonsense").begins_with("Unknown season"), "a bad season is refused")
	var d0: int = sim.calendar.day_index()
	cmds.run("day 3")
	t.eq(sim.calendar.day_index(), d0 + 3, "day 3 advances three days")
	t.ok(cmds.run("day -1").begins_with("Usage"), "a bad day count is refused")
