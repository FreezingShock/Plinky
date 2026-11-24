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

	# Grab and drag: every x on the arc is one time of day (sun) or night (moon), and the arc is the same curve the sky draws.
	for u: float in [0.25, 0.3, 0.42, 0.5, 0.61, 0.75]:
		var x: float = TitleMood.arc_at(u, true).x
		t.near(TitleMood.phase_for_x(x, true), u, 1e-4, "sun x %.2f maps back to phase %.2f" % [x, u])
	for u: float in [0.75, 0.9, 1.0, 1.1, 1.25]:
		var x: float = TitleMood.arc_at(u, false).x
		t.near(TitleMood.phase_for_x(x, false), u, 1e-4, "moon x %.2f maps back to phase %.2f" % [x, u])
	t.near(TitleMood.phase_for_x(TitleMood.ARC_CENTRE_X, true), 0.5, 1e-4, "the middle of the arc is noon")
	t.near(TitleMood.phase_for_x(TitleMood.ARC_CENTRE_X, false), 1.0, 1e-4, "the middle of the arc is midnight")
	t.near(TitleMood.phase_for_x(-5000.0, true), 0.25, 1e-4, "dragging past the left end clamps to sunrise")
	t.near(TitleMood.phase_for_x(5000.0, true), 0.75, 1e-4, "dragging past the right end clamps to sunset")
	t.near(TitleMood.phase_for_x(5000.0, false), 1.25, 1e-4, "the moon clamps to its far end")
	t.ok(TitleMood.arc_point(0.25).y > TitleMood.arc_point(0.5).y, "the body is lowest at the horizon and highest at noon")
	t.ok(TitleMood.arc_point(0.4).y < TitleMood.arc_point(0.3).y, "the arc curves up like a planet's path")
	var last_x: float = -1.0e9
	var rising: bool = true
	for i in 21:
		var x: float = TitleMood.arc_at(0.25 + 0.5 * float(i) / 20.0, true).x
		rising = rising and x >= last_x
		last_x = x
	t.ok(rising, "the sun's x only moves right across its day")
	for i in 24:
		var tp: float = float(i) / 24.0
		t.ok(TitleMood.body(sky, _t_for(sky, tp)).is_equal_approx(TitleMood.arc_point(tp)), "body and arc agree at phase %.3f" % tp)
	t.ok(TitleMood.arc_at(1.25, false).x > TitleMood.arc_at(1.1, false).x, "the moon's far end is on the right")
	t.ok(TitleMood.body(sky, noon_t).is_equal_approx(TitleMood.arc_point(0.5)), "the drawn body is the arc at its phase")

	# The grab spring: held and released bodies move smoothly; the calm one never overshoots.
	var x_calm: float = 0.0
	var v_calm: float = 0.0
	var peak_calm: float = 0.0
	var x_lively: float = 0.0
	var v_lively: float = 0.0
	var peak_lively: float = 0.0
	for i in 300:
		var calm_step: Vector2 = TitleBackground.spring_step(x_calm, v_calm, 1.0, 34.0, 2.0 * sqrt(34.0), 1.0 / 60.0)
		x_calm = calm_step.x
		v_calm = calm_step.y
		peak_calm = maxf(peak_calm, x_calm)
		var lively_step: Vector2 = TitleBackground.spring_step(x_lively, v_lively, 1.0, TitleBackground.GRAB_STIFFNESS, TitleBackground.GRAB_DAMPING, 1.0 / 60.0)
		x_lively = lively_step.x
		v_lively = lively_step.y
		peak_lively = maxf(peak_lively, x_lively)
	t.ok(peak_calm <= 1.0001, "Reduce Motion pull never overshoots")
	t.near(x_calm, 1.0, 1e-3, "Reduce Motion pull settles on the pointer")
	t.ok(peak_lively > 1.05, "the grab pull overshoots a little, so it feels springy")
	t.ok(peak_lively < 1.25, "the grab overshoot stays small")
	t.near(x_lively, 1.0, 1e-3, "the grab settles on the pointer")


static func _t_for(sky: SkyModel, p: float) -> float:
	return TitleMood.seconds_for(sky, p)
