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
