extends RefCounted
## Graphics quality levels and frame-time stats (render/graphics_quality.gd, render/perf_stats.gd).

func run(t: Object) -> void:
	t.eq(GraphicsQuality.parse("Low"), GraphicsQuality.Level.LOW, "parse low")
	t.eq(GraphicsQuality.parse(" med "), GraphicsQuality.Level.MEDIUM, "parse med")
	t.eq(GraphicsQuality.parse("HIGH"), GraphicsQuality.Level.HIGH, "parse high")
	t.eq(GraphicsQuality.parse("2"), GraphicsQuality.Level.HIGH, "parse digit")
	t.eq(GraphicsQuality.parse("ultra"), -1, "parse rejects unknown names")

	var saved_path: String = GraphicsQuality.path
	var saved_level: int = GraphicsQuality.level
	GraphicsQuality.path = "user://test_graphics.cfg"
	GraphicsQuality.set_level(99, false)
	t.eq(GraphicsQuality.level, GraphicsQuality.Level.HIGH, "level clamps high")
	GraphicsQuality.set_level(-5, false)
	t.eq(GraphicsQuality.level, GraphicsQuality.Level.LOW, "level clamps low")
	t.eq(GraphicsQuality.label(), "Low", "label follows level")

	# Every level scales cost down monotonically, and High is the full look.
	var prev_density: float = 0.0
	for lv: int in [GraphicsQuality.Level.LOW, GraphicsQuality.Level.MEDIUM, GraphicsQuality.Level.HIGH]:
		GraphicsQuality.set_level(lv, false)
		t.ok(GraphicsQuality.life_density() > prev_density, "life density rises with quality (level %d)" % lv)
		prev_density = GraphicsQuality.life_density()
		t.ok(GraphicsQuality.life_count(12) >= 1, "life count stays at least 1")
		t.ok(GraphicsQuality.particle_count(10) >= 2, "bursts keep at least 2 particles")
	t.eq(GraphicsQuality.life_count(12), 12, "High draws every firefly")
	t.eq(GraphicsQuality.particle_count(10), 10, "High keeps full bursts")
	t.near(GraphicsQuality.life_step(), 1.0 / 12.0, 1e-9, "High life steps at 12 fps")
	t.near(GraphicsQuality.sway_step(), 1.0 / 6.0, 1e-9, "High sway steps at 6 fps")
	t.ok(GraphicsQuality.LIFE_STEP[0] > GraphicsQuality.LIFE_STEP[2], "Low steps life less often than High")

	# Save and load round trip through its own file.
	GraphicsQuality.set_level(GraphicsQuality.Level.MEDIUM, true)
	GraphicsQuality.level = GraphicsQuality.Level.HIGH
	GraphicsQuality._loaded = false
	GraphicsQuality.load_settings()
	t.eq(GraphicsQuality.level, GraphicsQuality.Level.MEDIUM, "saved level loads back")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_graphics.cfg"))
	t.ok(GraphicsQuality.from_args(PackedStringArray(["--quality=low"])), "from_args finds --quality")
	t.eq(GraphicsQuality.level, GraphicsQuality.Level.LOW, "from_args sets the level")
	t.ok(not GraphicsQuality.from_args(PackedStringArray(["--frames=10"])), "from_args ignores other args")
	GraphicsQuality.path = saved_path
	GraphicsQuality.set_level(saved_level, false)

	# Stats: 100 frames 1..100 ms.
	var st := PerfStats.new(100)
	t.eq(st.summary().frames, 0, "empty stats")
	for i: int in range(1, 101):
		st.push(float(i))
	var s: Dictionary = st.summary()
	t.near(float(s.avg), 50.5, 1e-4, "average of 1..100")
	t.near(float(s.p95), 95.0, 1e-4, "p95 of 1..100")
	t.near(float(s.max), 100.0, 1e-4, "max of 1..100")
	st.push(2.0)  # ring buffer drops the oldest (1.0)
	t.eq(st.summary().frames, 100, "ring buffer stays at capacity")
	t.near(float(st.summary().max), 100.0, 1e-4, "ring keeps recent samples")
	var fast := PerfStats.new(10)
	for i: int in 10:
		fast.push(8.0)
	t.near(float(fast.summary().over_budget), 0.0, 1e-9, "8 ms frames are within budget")
	t.near(float(fast.summary().fps), 125.0, 1e-3, "fps from average")
