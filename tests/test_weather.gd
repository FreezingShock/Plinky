extends RefCounted
## Wet ground: SkyModel.wetness follows the rain, rises in a shower, and drains slowly after it stops.

func run(t: Object) -> void:
	var m := SkyModel.new()
	m.rain_period_a = 173.0
	m.rain_period_b = 271.0
	m.rain_phase_a = 4.0
	m.rain_phase_b = 0.5
	m.rain_threshold = 0.55
	m.rain_max = 0.6

	var in_range: bool = true
	var wet_seen: bool = false
	var dry_seen: bool = false
	var end_t: float = -1.0
	var prev_rain: float = 0.0
	for i in 2000:
		var now: float = float(i) * 3.0
		var w: float = m.wetness(now)
		if w < 0.0 or w > 1.0:
			in_range = false
		if w > 0.05:
			wet_seen = true
		if w < 0.001 and now > 100.0:
			dry_seen = true
		var r: float = m.rain(now)
		# the first moment a shower ends (rain stops after having fallen)
		if prev_rain > 0.05 and r <= 0.001 and end_t < 0.0:
			end_t = now
		prev_rain = r
	t.ok(in_range, "wetness stays within 0..1")
	t.ok(wet_seen, "the ground gets wet during rain")
	t.ok(dry_seen, "the ground dries out in dry weather")
	t.ok(m.wetness(0.0) >= 0.0, "wetness is defined at t = 0")

	# After a shower the ground is still wet for a while, then dries.
	t.ok(end_t > 0.0, "found a shower to test (rain stopped after falling)")
	if end_t > 0.0:
		var just: float = m.wetness(end_t)
		var later: float = m.wetness(end_t + 20.0)
		t.ok(just > 0.1, "the ground is still wet just after the rain stops (%.2f)" % just)
		t.ok(later < just or later < 0.01, "the ground dries after the rain stops (%.2f then %.2f)" % [just, later])

	# The clock tooltip's weather line.
	t.ok(SkyModel.weather_words(0.0, 0.0, 0.0) == "Clear skies.", "clear weather reads as clear skies")
	t.ok(SkyModel.weather_words(0.5, 0.0, 0.5).begins_with("Rain"), "rain reads as rain")
	t.ok(SkyModel.weather_words(0.5, 1.0, 0.5).begins_with("Snow"), "winter rain reads as snow")
	t.ok(SkyModel.weather_words(0.0, 0.0, 0.6).contains("drying"), "clear with wet ground says it is drying")

	# No rain configured: nothing gets wet.
	m.rain_max = 0.0
	t.ok(m.wetness(500.0) == 0.0, "no rain at all means dry ground")

	# Low quality drops the splash rings and dawn mist; Medium and High keep them.
	var before: int = GraphicsQuality.level
	GraphicsQuality.set_level(GraphicsQuality.Level.LOW, false)
	t.ok(not GraphicsQuality.rain_rings_and_mist(), "Low quality drops rain rings and dawn mist")
	GraphicsQuality.set_level(GraphicsQuality.Level.HIGH, false)
	t.ok(GraphicsQuality.rain_rings_and_mist(), "High quality keeps rain rings and dawn mist")
	GraphicsQuality.set_level(before, false)

	# Lightning: only in heavy rain, never more than full, and it does strike sometimes in a long downpour.
	t.ok(SkyModel.lightning_flash(100.0, 0.0) == 0.0, "no lightning in clear weather")
	t.ok(SkyModel.lightning_flash(100.0, 0.5) == 0.0, "no lightning in light rain")
	var struck: bool = false
	var in_range_l: bool = true
	for i in 4000:
		var f: float = SkyModel.lightning_flash(float(i) * 0.1, 1.0)
		if f < 0.0 or f > 1.0:
			in_range_l = false
		if f > 0.2:
			struck = true
	t.ok(in_range_l, "lightning stays within 0..1")
	t.ok(struck, "a long heavy downpour has at least one strike")

	# Season pin: a pinned season moves the calendar, so the clock, the flowers and the sky all read the same season.
	t.ok(SkyCycle.pin_jump_needed(3, 0), "a winter pin jumps a spring calendar to winter")
	t.ok(not SkyCycle.pin_jump_needed(3, 3), "no jump once the calendar is in the pinned season")
	t.ok(not SkyCycle.pin_jump_needed(-1, 0), "no pin means no jump")
	t.ok(not SkyCycle.pin_jump_needed(3, -1), "no calendar yet means no jump")
	var pin_cal := GameCalendar.new(load("res://content/config/calendar.tres") as CalendarConfig, 300.0)
	pin_cal.jump_to_season(3)
	t.eq(pin_cal.season_index(), 3, "the pinned winter reads as winter in the calendar")
	t.ok(String(pin_cal.now()["month_name"]).begins_with("Early Winter") or String(pin_cal.now()["month_name"]).begins_with("Late Winter"), "the clock names a winter month")
	t.near(pin_cal.season_weights()[3], 1.0, 0.001, "and the sky weights are all winter")

	# Time pin: the pinned sun phase drives the calendar clock, so the HUD and the sky agree.
	var pin_m := SkyModel.new()
	pin_m.daylight_fraction = 0.6
	var phases: Array[float] = [0.0, 0.1, 0.25, 0.4, 0.5, 0.66, 0.73, 0.9]
	var round_trip: bool = true
	for p in phases:
		var back: float = pin_m.phase_of_clock(pin_m.clock_of_phase(p))
		if absf(fposmod(back - p + 0.5, 1.0) - 0.5) > 0.00001:
			round_trip = false
	t.ok(round_trip, "a sun phase maps to a clock time and back to the same phase")
	var time_cal := GameCalendar.new(load("res://content/config/calendar.tres") as CalendarConfig, 300.0)
	time_cal.daylight_fraction = 0.6
	time_cal.set_day_fraction(pin_m.clock_of_phase(0.73))
	var sky_phase: float = pin_m.phase_of_clock(time_cal.day_fraction())
	t.ok(absf(fposmod(sky_phase - 0.73 + 0.5, 1.0) - 0.5) < 0.00001, "a dusk pin set on the calendar reads as dusk in the sky (%.4f)" % sky_phase)
	t.ok(not SkyCycle.clock_pin_needed(0.5, 0.5), "no clock change when the calendar already shows the pin")
	t.ok(SkyCycle.clock_pin_needed(0.5, 0.2), "a calendar far from the pin is moved")
	t.ok(not SkyCycle.clock_pin_needed(0.999, 0.001), "times either side of midnight count as close")
	t.ok(not SkyCycle.clock_pin_needed(0.5, 0.5015), "a tiny drift inside a frame does not reset the clock")

	# Rain bloom: dry leaves the lamps alone, full rain swells them, and the multipliers stay monotone
	var dry: Vector2 = SkyModel.lamp_bloom(0.0)
	var wet: Vector2 = SkyModel.lamp_bloom(1.0)
	t.ok(dry == Vector2(1.0, 1.0), "lamps are unchanged in dry weather")
	t.ok(wet.x > 1.0 and wet.y > 1.0, "lamps swell and brighten in full rain (%.2f, %.2f)" % [wet.x, wet.y])
	t.ok(SkyModel.lamp_bloom(0.5).y > dry.y and SkyModel.lamp_bloom(0.5).y < wet.y, "the bloom grows with the rain")
	t.ok(SkyModel.lamp_bloom(3.0) == wet, "the bloom caps at full rain")

	# Thunder follows the strike: the flash is on at the strike time, and the rumble trails it by 1.5 to 4.5 s
	var strikes: int = 0
	var agree: bool = true
	for w in 200:
		var st: float = SkyModel.strike_time(w)
		if st < 0.0:
			continue
		strikes += 1
		if SkyModel.lightning_flash(st + 0.01, 1.0) < 0.5:
			agree = false
		var dl: float = SkyModel.thunder_delay(w)
		if dl < 1.5 or dl > 4.5:
			agree = false
	t.ok(strikes > 50, "about half the windows have a strike (%d of 200)" % strikes)
	t.ok(agree, "every strike flashes at its time and its thunder trails by 1.5 to 4.5 s")

	# The rumble is a made stream of the set length, not a file: it must build with no audio driver and stop at its end
	var scape := AmbientScape.new()
	var rumble: AudioStreamWAV = scape._thunder()
	var want: int = int(AmbientScape.THUNDER_RATE * AmbientScape.THUNDER_SECONDS) * 2
	t.ok(rumble != null and rumble.data.size() == want, "the thunder rumble is made at its set length")
	t.ok(rumble.loop_mode == AudioStreamWAV.LOOP_DISABLED, "the rumble plays once, not on a loop")
	scape.free()
