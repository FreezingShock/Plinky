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
