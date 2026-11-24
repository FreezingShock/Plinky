extends RefCounted
## Title time of day: keyframes are ordered and wrap, sampling blends smoothly and hits the keyframes exactly, the
## sun and moon ride the arc, and stars and birds follow the sky.

func run(t: Object) -> void:
	var keys: Array = TitleMood.KEYS
	t.ok(keys.size() >= 6, "the title has at least six times of day")
	var last: float = -1.0
	var ordered: bool = true
	for k: Dictionary in keys:
		var p: float = float(k["phase"])
		if p <= last:
			ordered = false
		last = p
		t.ok((k["sky"] as Array).size() == 8, "%s has eight sky colours" % str(k["name"]))
		t.ok((k["ground"] as Array).size() == 4, "%s has four ground colours" % str(k["name"]))
	t.ok(ordered, "keyframes are in phase order")
	t.near(float(keys[0]["phase"]), 0.0, 1e-6, "the first keyframe is midnight")

	# Sampling at a keyframe gives that keyframe's own colours.
	var noon: Dictionary = TitleMood.sample(0.5)
	t.ok(noon["sky"][5].is_equal_approx(TitleMood._hex("fff6b8")), "noon sun colour is the noon keyframe's")
	t.ok((noon["ground"] as PackedColorArray)[3].is_equal_approx(TitleMood._hex("b7d978")), "noon grass is the meadow light")

	# Wrapping: phase 1.0 is midnight again, and a negative phase wraps back.
	var a: Dictionary = TitleMood.sample(0.0)
	var b: Dictionary = TitleMood.sample(1.0)
	t.ok((a["sky"] as PackedColorArray)[1].is_equal_approx((b["sky"] as PackedColorArray)[1]), "phase 1.0 wraps to midnight")
	t.near(TitleMood.wrap_phase(-0.25), 0.75, 1e-6, "negative phases wrap into the day")

	# Between two keyframes the colour sits between them, with no jump at the edges of the blend.
	var at_key: Color = (TitleMood.sample(0.72)["sky"] as PackedColorArray)[4]
	var between: Color = (TitleMood.sample(0.725)["sky"] as PackedColorArray)[4]
	var next_key: Color = (TitleMood.sample(0.75)["sky"] as PackedColorArray)[4]
	t.ok(between.r >= minf(at_key.r, next_key.r) - 1e-4 and between.r <= maxf(at_key.r, next_key.r) + 1e-4, "a blend sits between its two keyframes")
	t.ok(not between.is_equal_approx(at_key), "the colour moves between keyframes, it does not hold")
	t.ok(str(TitleMood.name_at(0.72)) == "Golden Hour", "phase 0.72 is named Golden Hour")
	t.ok(str(TitleMood.name_at(0.0)) == "Night", "midnight is named Night")

	# Skipping forward always moves to a later keyframe, and wraps past midnight.
	t.near(TitleMood.next_phase(0.5), 0.63, 1e-6, "noon skips to afternoon")
	t.ok(TitleMood.next_phase(0.9) > 0.9, "after dusk the next stop is past midnight")
	t.near(TitleMood.next_phase(0.9) - 1.0, 0.0, 1e-6, "after dusk the next stop is midnight")

	# The sun and moon: the sun is high at noon and off the bottom at night, the moon is up at midnight.
	var sky: SkyModel = TitleMood.make_sky()
	var noon_t: float = _t_for(sky, 0.5)
	var night_t: float = _t_for(sky, 0.0)
	var sun_noon: Vector2 = TitleMood.body(sky, noon_t)
	var moon_night: Vector2 = TitleMood.body(sky, night_t)
	t.ok(sun_noon.y < TitleMood.ARC_HORIZON_Y - 60.0, "the sun is high at noon")
	t.ok(moon_night.y < TitleMood.ARC_HORIZON_Y - 60.0, "the moon is high at midnight")
	t.ok(absf(sun_noon.x - TitleMood.ARC_CENTRE_X) < 1.0, "the sun is overhead at noon")
	var sunrise: Vector2 = TitleMood.body(sky, _t_for(sky, 0.25))
	var sunset: Vector2 = TitleMood.body(sky, _t_for(sky, 0.75))
	t.ok(sunrise.x < sun_noon.x and sun_noon.x < sunset.x, "the sun rises on the left and sets on the right")
	t.ok(sunrise.y > sun_noon.y, "the sun is lower at sunrise than at noon")

	# Stars and birds follow the sky.
	t.ok(TitleMood.stars(sky, noon_t) < 0.01, "no stars at noon")
	t.ok(TitleMood.stars(sky, night_t) > 0.9, "stars are out at midnight")
	t.ok(TitleMood.day_amount(sky, noon_t) > 0.99, "birds fly at noon")
	t.ok(TitleMood.day_amount(sky, night_t) < 0.01, "no birds at midnight")
	t.ok(TitleMood.night_amount(sky, night_t) > 0.9, "fireflies are out at midnight")
	t.ok(TitleMood.night_amount(sky, noon_t) < 0.01, "no fireflies at noon")


static func _t_for(sky: SkyModel, p: float) -> float:
	return TitleMood.seconds_for(sky, p)
