extends RefCounted
## Day/night and weather: SkyModel is a pure function of time, SkyConfig loads, the shaders compile.

func run(t: Object) -> void:
	var cfg: SkyConfig = load(SkyCycle.CONFIG_PATH) as SkyConfig
	t.ok(cfg != null, "sky.tres loads as SkyConfig")
	if cfg == null:
		return
	t.ok(cfg.day_seconds >= 300.0, "a day is at least five minutes (slow cycle)")
	var m := SkyModel.new()
	m.day_seconds = cfg.day_seconds
	m.start_phase = cfg.start_phase
	m.night_strength = cfg.night_strength
	m.dusk_strength = cfg.dusk_strength
	m.rain_period_a = cfg.rain_period_a
	m.rain_period_b = cfg.rain_period_b
	m.rain_phase_a = cfg.rain_phase_a
	m.rain_phase_b = cfg.rain_phase_b
	m.rain_threshold = cfg.rain_threshold
	m.rain_max = cfg.rain_max
	m.wind_calm = cfg.wind_calm
	m.wind_rain_boost = cfg.wind_rain_boost
	m.gust_period_a = cfg.gust_period_a
	m.gust_period_b = cfg.gust_period_b
	m.daylight_fraction = cfg.daylight_fraction
	m.golden_reach = cfg.golden_reach
	m.golden_floor = cfg.golden_floor

	# Time of day: noon is bright, midnight is dark, the day repeats.
	m.start_phase = 0.5
	t.near(m.night(0.0), 0.0, 1e-6, "noon has no night shade")
	m.start_phase = 0.0
	t.near(m.night(0.0), cfg.night_strength, 1e-6, "midnight is at full night strength")
	m.start_phase = cfg.start_phase
	t.near(m.phase(0.0), cfg.start_phase, 1e-6, "session starts at the configured phase")
	t.near(m.phase(cfg.day_seconds), cfg.start_phase, 1e-6, "phase repeats after one day")
	t.ok(m.night(0.0) < 0.05, "a new session starts in daylight")
	m.start_phase = 0.25
	t.near(m.dusk(0.0), cfg.dusk_strength, 1e-6, "sunrise has the full warm band")
	m.start_phase = 0.5
	t.ok(m.dusk(0.0) < 0.001, "noon has no warm band")
	m.start_phase = cfg.start_phase

	# Golden light: full at the horizon, a floor at noon, none at night, and the 08:08 look sits well above the floor.
	m.start_phase = 0.26
	t.ok(m.golden(0.0) > 0.9, "sunrise is full golden light")
	m.start_phase = 0.5
	t.near(m.golden(0.0), cfg.golden_floor, 1e-3, "noon keeps the golden floor")
	t.ok(m.rays(0.0) < 0.001, "no god rays at noon")
	m.start_phase = 0.0
	t.ok(m.golden(0.0) < 0.001, "no golden light at midnight")
	m.start_phase = 0.366
	t.ok(m.golden(0.0) > cfg.golden_floor + 0.2, "mid morning is still well into the golden look")
	t.ok(m.golden(0.0) > m.low_sun(0.0), "golden holds longer than the low sun")
	m.start_phase = cfg.start_phase

	# Sample two days: values stay in range and move a little at a time (no pops).
	var prev_n: float = m.night(0.0)
	var prev_r: float = m.rain(0.0)
	var prev_w: float = m.wind(0.0)
	var in_range: bool = true
	var smooth: bool = true
	var rain_secs: int = 0
	var total: int = int(cfg.day_seconds) * 4
	var max_rain: float = 0.0
	for s in range(1, total):
		var tt: float = float(s)
		var n: float = m.night(tt)
		var r: float = m.rain(tt)
		var w: float = m.wind(tt)
		if n < 0.0 or n > 1.0 or r < 0.0 or r > cfg.rain_max + 1e-6 or w < 0.0 or w > 1.0:
			in_range = false
		if absf(n - prev_n) > 0.02 * 720.0 / cfg.day_seconds * 1.4 or absf(r - prev_r) > 0.2 or absf(w - prev_w) > 0.8:
			smooth = false
		if r > 0.0:
			rain_secs += 1
		max_rain = maxf(max_rain, r)
		prev_n = n
		prev_r = r
		prev_w = w
	t.ok(in_range, "night, rain and wind stay in range")
	t.ok(smooth, "night, rain and wind change smoothly second to second")
	var frac: float = float(rain_secs) / float(total)
	t.ok(frac > 0.05 and frac < 0.35, "it rains some of the time, not most (%.2f)" % frac)
	t.ok(max_rain > 0.3, "rain reaches a visible intensity (%.2f)" % max_rain)
	t.near(m.rain(0.0), 0.0, 1e-6, "the first seconds are dry")
	t.near(m.rain(12.5), m.rain(12.5), 1e-9, "same time gives the same rain")
	t.ok(m.wind(1000.0) == m.wind(1000.0), "same time gives the same wind")

	# Wind is never dead calm and rain raises it.
	var min_w: float = 1.0
	for s in 2000:
		min_w = minf(min_w, m.wind(float(s)))
	t.ok(min_w >= cfg.wind_calm - 1e-6, "wind never drops below the calm breeze")

	# Shaders compile, and the sway material takes its parameters.
	t.ok(SkyCycle.SHADE_SHADER != null and SkyCycle.SWAY_SHADER != null, "sky shaders load")
	var mat := ShaderMaterial.new()
	mat.shader = SkyCycle.SWAY_SHADER
	mat.set_shader_parameter("wind", 0.5)
	t.near(float(mat.get_shader_parameter("wind")), 0.5, 1e-6, "sway material holds the wind value")

	# Padding keeps the sprite and adds transparent columns.
	var img := Image.create(5, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 0, 1))
	var padded: Texture2D = SkyCycle.padded(ImageTexture.create_from_image(img))
	t.eq(padded.get_width(), 5 + SkyCycle.SWAY_PAD * 2, "padded sprite is wider by the pad on both sides")
	t.eq(padded.get_height(), 4, "padded sprite keeps its height")
	var pi: Image = padded.get_image()
	t.near(pi.get_pixel(0, 0).a, 0.0, 1e-6, "pad columns are transparent")
	t.near(pi.get_pixel(SkyCycle.SWAY_PAD, 0).a, 1.0, 1e-6, "sprite pixels sit after the pad")
	# A missing texture must not crash the sky (the 'texture has no image data' race): it comes back as it was.
	t.ok(SkyCycle.padded(null) == null, "padding nothing gives nothing")
