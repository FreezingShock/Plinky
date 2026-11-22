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
