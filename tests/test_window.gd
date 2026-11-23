extends RefCounted
## Window suite: the custom frame is on in windowed mode only, the native-frame fallback turns it off,
## and the wipe shader source compiles to a Shader. Run through tests/run.gd.

func run(t: SceneTree) -> void:
	DisplaySettings.native_frame = false
	DisplaySettings.fullscreen = false
	DisplaySettings._loaded = true
	t.ok(DisplaySettings.custom_frame_active(), "windowed uses the custom frame by default")
	DisplaySettings.fullscreen = true
	t.ok(not DisplaySettings.custom_frame_active(), "fullscreen has no frame")
	DisplaySettings.fullscreen = false
	DisplaySettings.native_frame = true
	t.ok(not DisplaySettings.custom_frame_active(), "the native-frame setting turns the custom frame off")
	DisplaySettings.native_frame = false

	var sh := Shader.new()
	sh.code = WindowFrame.WIPE_SHADER
	t.ok(sh.code.contains("BAYER"), "wipe shader carries the 4x4 Bayer matrix")
	t.eq(WindowFrame.BAR_H, 12, "title bar is 12 texels, one Spleen 6x12 line")

	# Resize edges: band and corner hit-testing in window pixels, at several window sizes.
	for s: Vector2i in [Vector2i(640, 360), Vector2i(1280, 720), Vector2i(3840, 2160), Vector2i(5120, 1440)]:
		var band: int = maxi(5, s.y / 360)
		var corner: int = band * 12 / 5
		t.eq(WindowFrame.edge_at(Vector2i(0, s.y / 2), s, band, corner), DisplayServer.WINDOW_EDGE_LEFT, "left edge at %s" % s)
		t.eq(WindowFrame.edge_at(Vector2i(s.x - 1, s.y / 2), s, band, corner), DisplayServer.WINDOW_EDGE_RIGHT, "right edge at %s" % s)
		t.eq(WindowFrame.edge_at(Vector2i(s.x / 2, 0), s, band, corner), DisplayServer.WINDOW_EDGE_TOP, "top edge at %s" % s)
		t.eq(WindowFrame.edge_at(Vector2i(s.x / 2, s.y - 1), s, band, corner), DisplayServer.WINDOW_EDGE_BOTTOM, "bottom edge at %s" % s)
		t.eq(WindowFrame.edge_at(Vector2i(0, 0), s, band, corner), DisplayServer.WINDOW_EDGE_TOP_LEFT, "top-left corner at %s" % s)
		t.eq(WindowFrame.edge_at(Vector2i(s.x - 1, s.y - 1), s, band, corner), DisplayServer.WINDOW_EDGE_BOTTOM_RIGHT, "bottom-right corner at %s" % s)
		t.eq(WindowFrame.edge_at(Vector2i(s.x - 1, 1), s, band, corner), DisplayServer.WINDOW_EDGE_TOP_RIGHT, "top-right corner at %s" % s)
		t.eq(WindowFrame.edge_at(Vector2i(2, s.y - 1), s, band, corner), DisplayServer.WINDOW_EDGE_BOTTOM_LEFT, "bottom-left corner at %s" % s)
		t.eq(WindowFrame.edge_at(s / 2, s, band, corner), -1, "the middle is not an edge at %s" % s)
		t.eq(WindowFrame.edge_at(Vector2i(-1, 5), s, band, corner), -1, "outside the window is not an edge at %s" % s)

	# Window size options: the biggest size is the monitor's own, cut to the usable area so the taskbar stays clear.
	var native := Vector2i(1920, 1080)
	var usable := Vector2i(1920, 1040)
	t.eq(DisplaySettings.max_window_size(native, usable), usable, "the biggest window leaves the taskbar clear")
	t.eq(DisplaySettings.max_window_size(native, native), native, "no taskbar: the biggest window is the native size")
	var opts: Array[Vector2i] = DisplaySettings.options_for(native, usable)
	t.eq(opts[opts.size() - 1], usable, "the last option is the biggest the monitor holds")
	for sz: Vector2i in opts:
		t.ok(sz.x <= usable.x and sz.y <= usable.y, "option %s fits the usable area" % sz)
		t.eq(DisplaySettings.fit_size(sz, usable), sz, "applying option %s keeps its size" % sz)
	t.ok(opts.has(Vector2i(1280, 720)) and opts.has(Vector2i(1024, 576)), "common sizes that fit are offered")
	t.ok(not opts.has(Vector2i(2560, 1440)), "sizes bigger than the monitor are hidden")
	t.eq(DisplaySettings.fit_size(Vector2i(3840, 2160), usable), usable, "an oversize request is cut to the usable area")
	t.eq(DisplaySettings.fit_size(Vector2i(100, 100), usable), DisplaySettings.BASE, "a tiny request is raised to 640x360")
	# A 4K monitor offers every common size, with no duplicate of its own size.
	var big: Array[Vector2i] = DisplaySettings.options_for(Vector2i(3840, 2160), Vector2i(3840, 2120))
	t.eq(big.size(), DisplaySettings.COMMON_SIZES.size(), "a 4K monitor offers each common size once")
