extends RefCounted
## Seasonal events: one light, content-driven effect per season, read off the calendar.

func run(t: Object) -> void:
	var cfg: SeasonalEventsConfig = load("res://content/config/seasonal_events.tres") as SeasonalEventsConfig
	t.ok(cfg != null, "seasonal_events.tres loads")
	if cfg == null:
		return
	for n: int in [cfg.event_names.size(), cfg.event_blurbs.size(), cfg.critter_interval_mult.size(), cfg.day_income_mult.size(),
			cfg.relic_roll_mult.size(), cfg.momentum_decay_mult.size()]:
		t.eq(n, 4, "event arrays have one entry per season")
	var ev := SeasonalEvents.new(cfg)
	t.eq(ev.name_of(0), "Petal Shower", "spring event name")
	t.eq(ev.name_of(3), "Frost Pads", "winter event name")
	t.ok(ev.critter_interval_mult(0) < 1.0 and ev.critter_interval_mult(1) == 1.0, "only spring speeds up critters")
	t.ok(ev.day_income_mult(1, true) > 1.0 and ev.day_income_mult(1, false) == 1.0, "summer income is daylight only")
	t.ok(ev.day_income_mult(0, true) == 1.0, "spring leaves income alone")
	t.ok(ev.relic_roll_mult(2) < 1.0 and ev.relic_roll_mult(3) == 1.0, "only autumn speeds up relic rolls")
	t.ok(ev.momentum_decay_mult(3) < 1.0 and ev.momentum_decay_mult(2) == 1.0, "only winter slows momentum decay")
	for s: int in 4:
		t.ok(ev.day_income_mult(s, true) <= 1.1, "no income event is above +10%")
	for s: int in 4:
		t.ok(ev.particle_boost(s) > 1.0, "every event thickens its season's air")
	var none := SeasonalEvents.new()
	t.eq(none.name_of(0), "", "no config, no event name")
	t.near(none.critter_interval_mult(2), 1.0, 1e-9, "no config, neutral multiplier")
	t.near(ev.relic_roll_mult(9), 1.0, 1e-9, "bad season index is neutral")

	# In the sim: summer daylight pays more Sunlight than summer night or spring daylight.
	var sim: Sim = t.make_sim()
	sim.new_game()
	var sun: StringName = sim.config.income_stat
	sim.calendar.elapsed_days = 0.5   # spring noon
	var spring: float = sim.income_per_second(sun).to_float()
	sim.calendar.jump_to_season(1)
	sim.calendar.elapsed_days = floorf(sim.calendar.elapsed_days) + 0.5   # summer noon
	var summer_day: float = sim.income_per_second(sun).to_float()
	sim.calendar.elapsed_days = floorf(sim.calendar.elapsed_days) + 0.02   # summer night
	var summer_night: float = sim.income_per_second(sun).to_float()
	t.ok(spring > 0.0, "income flows")
	t.near(summer_day / spring, 1.08, 1e-6, "summer noon pays 8% more than spring noon")
	t.near(summer_night / spring, 1.0, 1e-6, "summer night pays the normal rate")
