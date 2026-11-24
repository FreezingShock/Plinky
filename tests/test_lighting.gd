extends RefCounted
## Lighting and atmosphere: sun model (pure), config ramps, shadow placement, light flicker, particle tuning.

func run(t: Object) -> void:
	run_meadow(t)
	run_quarry(t)
	var cfg: SkyConfig = load(SkyCycle.CONFIG_PATH) as SkyConfig
	t.ok(cfg != null, "sky.tres loads")
	if cfg == null:
		return
	var m := SkyModel.new()
	m.day_seconds = 720.0
	m.rain_max = cfg.rain_max
	m.rain_threshold = 2.0   # never rains: weather is tested separately
	var day: float = m.day_seconds

	# Sun arc: light from the left at sunrise, overhead at noon, from the right at sunset.
	m.start_phase = 0.25
	t.near(m.azimuth(0.0), -1.0, 1e-6, "sunrise light comes from the left")
	m.start_phase = 0.5
	t.near(m.azimuth(0.0) + 1.0, 1.0, 1e-6, "noon light is overhead")
	m.start_phase = 0.75
	t.near(m.azimuth(0.0), 1.0, 1e-6, "sunset light comes from the right")
	var in_range: bool = true
	var smooth: bool = true
	var prev: float = m.azimuth(0.0)
	m.start_phase = 0.0
	for s in range(1, int(day)):
		var a: float = m.azimuth(float(s))
		if a < -1.0001 or a > 1.0001:
			in_range = false
		# the only allowed jump is the hand-over from sun to moon at the horizon, where shadows are faded out
		if absf(a - prev) > 0.1 and m.shadow_strength(float(s), cfg.shadow_moon) > cfg.shadow_moon + 0.01:
			smooth = false
		prev = a
	t.ok(in_range, "azimuth stays within -1..1 all day")
	t.ok(smooth, "azimuth moves smoothly while shadows are strong")

	# Low sun: golden hour peaks at sunrise and sunset, none at noon or midnight.
	m.start_phase = 0.27
	t.ok(m.low_sun(0.0) > 0.8, "sunrise is golden hour")
	m.start_phase = 0.5
	t.near(m.low_sun(0.0) + 1.0, 1.0, 1e-6, "noon is not golden hour")
	m.start_phase = 0.0
	t.near(m.low_sun(0.0) + 1.0, 1.0, 1e-6, "midnight is not golden hour")

	# Shadows: short at noon, long at low sun, a faint one under the moon.
	m.start_phase = 0.5
	var noon_len: float = m.shadow_length(0.0, cfg.shadow_len_noon, cfg.shadow_len_low, cfg.shadow_len_moon)
	t.near(noon_len, cfg.shadow_len_noon, 1e-4, "noon shadow is the short one")
	t.near(m.shadow_strength(0.0, cfg.shadow_moon), 1.0, 1e-6, "noon sun shadow is full strength")
	m.start_phase = 0.27
	var low_len: float = m.shadow_length(0.0, cfg.shadow_len_noon, cfg.shadow_len_low, cfg.shadow_len_moon)
	t.ok(low_len > noon_len * 2.0, "low sun throws a much longer shadow (%.2f vs %.2f)" % [low_len, noon_len])
	m.start_phase = 0.0
	t.near(m.shadow_strength(0.0, cfg.shadow_moon), cfg.shadow_moon, 1e-6, "midnight keeps only the moon shadow")

	# God rays: only while the sun is low, never at noon or midnight.
	m.start_phase = 0.5
	t.near(m.rays(0.0) + 1.0, 1.0, 1e-6, "no god rays at noon")
	m.start_phase = 0.0
	t.near(m.rays(0.0) + 1.0, 1.0, 1e-6, "no god rays at midnight")
	m.start_phase = 0.27
	t.ok(m.rays(0.0) > 0.7, "god rays at dawn")
	m.start_phase = 0.73
	t.ok(m.rays(0.0) > 0.7, "god rays at dusk")

	# Mist 0..1, thickest around dawn.
	var mist_ok: bool = true
	m.start_phase = 0.0
	var mist_dawn: float = 0.0
	var mist_noon: float = 1.0
	for s in range(0, int(day), 5):
		var v: float = m.mist(float(s))
		if v < 0.0 or v > 1.0:
			mist_ok = false
	m.start_phase = 0.27
	mist_dawn = m.mist(0.0)
	m.start_phase = 0.5
	mist_noon = m.mist(0.0)
	t.ok(mist_ok, "mist stays in range")
	t.ok(mist_dawn > mist_noon + 0.3, "dawn is mistier than noon (%.2f vs %.2f)" % [mist_dawn, mist_noon])

	# Config: the colour ramps exist and sample to valid colours over the whole day.
	t.ok(cfg.grade_tint != null and cfg.grade_amount != null and cfg.haze_color != null and cfg.ray_color != null,
			"sky.tres has the four colour ramps")
	var ramps_ok: bool = true
	for g: Gradient in [cfg.grade_tint, cfg.grade_amount, cfg.haze_color, cfg.ray_color]:
		for i in 25:
			var c: Color = g.sample(float(i) / 24.0)
			if c.r < 0.0 or c.r > 1.0 or c.g < 0.0 or c.g > 1.0 or c.b < 0.0 or c.b > 1.0:
				ramps_ok = false
	t.ok(ramps_ok, "colour ramps stay in 0..1")
	t.near(cfg.grade_amount.sample(0.0).r, cfg.grade_amount.sample(1.0).r, 1e-6, "grade ramp loops at midnight")
	t.ok(cfg.grade_amount.sample(0.27).r > cfg.grade_amount.sample(0.5).r, "sunrise is graded more than noon")
	t.ok(cfg.vignette_strength >= 0.0 and cfg.vignette_strength <= 1.0, "vignette strength in range")

	# Shaders load.
	for sh: Shader in [SkyCycle.HAZE_SHADER, SkyCycle.RAYS_SHADER, SkyCycle.SHADE_SHADER, SkyCycle.SWAY_SHADER,
			SkyShadows.SHADER, ScreenLight.SHADER]:
		t.ok(sh != null and sh.code.length() > 100, "lighting shader loads")

	# Shadow placement: light from the left puts the tip to the right of the foot, and low sun is longer than noon.
	var sh := SkyShadows.new()
	var src := Sprite2D.new()
	src.position = Vector2(100.0, 100.0)
	sh.add_caster(src, "oak", Vector2(40.0, 50.0))
	var p: Dictionary = {"foot": 1.0, "tip": 0.4}
	sh.set_sun(-1.0, 1.0, 1.0, p)
	var tf_left: Transform2D = (sh._items[0].sprite as Sprite2D).transform
	var tip_left: Vector2 = tf_left * Vector2(0.0, -1.0)
	t.ok(tip_left.x > 100.0 + 20.0, "dawn shadow falls to the right (tip x %.1f)" % tip_left.x)
	sh.set_sun(1.0, 1.0, 1.0, p)
	var tip_right: Vector2 = (sh._items[0].sprite as Sprite2D).transform * Vector2(0.0, -1.0)
	t.ok(tip_right.x < 100.0 - 20.0, "dusk shadow falls to the left (tip x %.1f)" % tip_right.x)
	sh.set_sun(0.0, 0.2, 1.0, p)
	var tip_noon: Vector2 = (sh._items[0].sprite as Sprite2D).transform * Vector2(0.0, -1.0)
	t.ok(tip_noon.distance_to(Vector2(100.0, 100.0)) < tip_left.distance_to(Vector2(100.0, 100.0)) * 0.6,
			"noon shadow is shorter than dawn")
	sh.free()
	src.free()

	# Reduce motion / Reduce flashing: light pools hold still.
	var moved: bool = false
	for s in 40:
		if SkyCycle.light_flicker(float(s) * 0.17, 572, true) != 0.0:
			moved = true
	t.ok(not moved, "steady mode (Reduce motion or Reduce flashing) has no pool flicker")
	var wobbled: bool = false
	for s in 40:
		var f: float = SkyCycle.light_flicker(float(s) * 0.17, 572, false)
		if absf(f) > 0.05:
			wobbled = true
		if absf(f) > 1.0001:
			moved = true
	t.ok(wobbled and not moved, "normal pools wobble within one texel")

	# Particles follow the light: fireflies at night, pollen by day, nothing but a few motes in the rain.
	var air := LifeAir.new()
	MeadowLife.night = 0.0
	MeadowLife.low_sun = 0.0
	MeadowLife.rain = 0.0
	var ff_day: int = air._firefly_count()
	var pol_day: int = air._pollen_count()
	MeadowLife.night = 1.0
	var ff_night: int = air._firefly_count()
	var pol_night: int = air._pollen_count()
	MeadowLife.night = 0.0
	MeadowLife.low_sun = 1.0
	var pol_golden: int = air._pollen_count()
	MeadowLife.low_sun = 0.0
	MeadowLife.rain = 1.0
	var ff_rain: int = air._firefly_count()
	MeadowLife.rain = 0.0
	t.ok(ff_night > ff_day * 3, "many more fireflies at night (%d vs %d)" % [ff_night, ff_day])
	t.eq(ff_rain, 0, "no fireflies in the rain")
	t.ok(pol_day > pol_night * 2, "pollen is a daytime thing (%d vs %d)" % [pol_day, pol_night])
	t.ok(pol_golden > pol_day, "more motes in the low sun (%d vs %d)" % [pol_golden, pol_day])
	air.free()


## The onboarding meadow boots its sky: the haze material exists, the rects are built, and nothing errors.
## (A typed-array assignment slipped through once because only Larkmoor's scene was loaded by a test.)
func run_meadow(t: Object) -> void:
	var scene: Node = (load("res://world/meadow3d_scene.tscn") as PackedScene).instantiate()
	var holder := Node2D.new()
	holder.add_child(scene)
	scene.call("_ready")
	var sky: SkyCycle = scene.get_node_or_null("Sky") as SkyCycle
	t.ok(sky != null, "meadow has a Sky node")
	if sky != null:
		sky.call("_ready")   # holder is outside the tree, so the sky is not readied for us
		t.ok(sky._haze_mat != null, "meadow sky built its haze material")
		t.ok(sky.get_node_or_null("Haze") != null, "meadow has a haze rect")
	holder.free()


## Ember Quarry light: the flicker is stepped at 6 fps, bounded, and steady when asked; the emitter list is capped.
func run_quarry(t: Object) -> void:
	t.eq(LavaFlicker.frame(0.0), 0, "flicker frame starts at 0")
	t.eq(LavaFlicker.frame(0.17), 1, "flicker frame advances at 6 fps")
	t.ok(LavaFlicker.level(0.01, 3, 0.3, true) == 1.0, "steady flicker holds full brightness")
	t.ok(LavaFlicker.level(0.01, 3, 0.0, false) == 1.0, "zero depth never dims")
	var steps_ok: bool = true
	var same_in_step: bool = true
	for i in range(200):
		var v: float = LavaFlicker.level(float(i) * 0.05, 7, 0.35, false)
		if v < 0.65 - 1e-6 or v > 1.0 + 1e-6:
			steps_ok = false
		if LavaFlicker.level(float(LavaFlicker.frame(float(i) * 0.05)) / 6.0 + 0.01, 7, 0.35, false) != v:
			same_in_step = false
	t.ok(steps_ok, "flicker stays within 1 - depth .. 1")
	t.ok(same_in_step, "flicker is constant inside one 1/6 s step")
	var cfg: SkyConfig = load(SkyCycle.CONFIG_PATH) as SkyConfig
	t.ok(cfg.lava_glow > 0.0 and cfg.shimmer_amount > 0.0, "quarry light tuning loads from sky.tres")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/zone2/quarry/placements3d.json"))
	var cols: PackedColorArray = Palettes.colors(Palettes.for_zone(&"zone2"))
	var list: Array[Dictionary] = QuarryLight.emitters(data, cfg, cols)
	t.ok(list.size() > 0 and list.size() <= QuarryLight.MAX_EMIT, "quarry emitters fit the shader array")
	t.ok(list.size() > 0 and int(list[0].kind) == QuarryLight.KIND_BRAZIER, "braziers are packed first")
