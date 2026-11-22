extends SceneTree
## Captures the real main scene at several window sizes and scale modes, then the settings panel.
## Writes PNGs to shots/sizes/. Needs a real window (not --headless).
## Shots are cropped from the screen, so they show the window at its real size. The root viewport
## renders at the 640x360 base, so its texture would be 640x360 whatever the window is.
## Run: godot --path . --import (once, to refresh the class cache), then
##      godot --path . --script tools/size_shots.gd

## [width, height, scale mode (0 Pixel perfect, 1 Fit, 2 Wide view), bleed flag (0 off, 1 on)]
const CASES: Array = [
	[1280, 720, 1, 0],
	[1920, 1080, 1, 0],
	[2560, 1440, 1, 0],
	[1600, 1000, 1, 0],
	[800, 600, 1, 0],
	[1024, 768, 0, 0],
	[1920, 1080, 0, 0],
	[2560, 1080, 2, 1],
	[1920, 1080, 2, 1],
	[2560, 1440, 2, 1],
]
const MODE_NAMES: Array = ["pixel", "fit", "wide"]
const SETTLE_FRAMES: int = 12


func _init() -> void:
	var out_dir: String = ProjectSettings.globalize_path("res://shots/sizes")
	DirAccess.make_dir_recursive_absolute(out_dir)
	# Autoloads (GameState, EventBus, ...) are only registered after the first frame. Loading main.gd
	# before that fails to compile, so wait one frame first.
	await process_frame
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _settle()

	for c: Array in CASES:
		var w: int = c[0]
		var h: int = c[1]
		var mode: int = c[2]
		DisplaySettings.bleed_ready = c[3] == 1
		DisplaySettings.set_scale_mode(root, mode)
		DisplayServer.window_set_size(Vector2i(w, h))
		await _settle()
		DisplaySettings.apply(root)
		await _settle()
		var real: Vector2i = DisplayServer.window_get_size()
		var fname: String = "%dx%d_%s%s" % [real.x, real.y, MODE_NAMES[mode], "_bleed" if c[3] == 1 else ""]
		print("shot ", fname, " integer=", DisplaySettings.integer_scale(root), " stretch=", root.content_scale_stretch,
			" aspect=", root.content_scale_aspect, " mode=", root.content_scale_mode, " view=", root.get_visible_rect().size,
			" final_scale=", root.get_final_transform().x.x, " frame=", main.size, " origin=", main.position,
			" hud_px=", _hud_px(main))
		await _save(out_dir + "/" + fname + ".png")

	# Maximized (what Nathan does by hand). The frame and HUD must follow the maximized size, and the mode must stick.
	for mode: int in [DisplaySettings.Scale.FIT, DisplaySettings.Scale.WIDE]:
		DisplaySettings.bleed_ready = true
		DisplaySettings.set_scale_mode(root, mode)
		root.mode = Window.MODE_MAXIMIZED
		await _settle()
		DisplaySettings.apply(root)
		await _settle()
		var real: Vector2i = DisplayServer.window_get_size()
		var fname: String = "%dx%d_%s_maximized" % [real.x, real.y, MODE_NAMES[mode]]
		print("shot ", fname, " window_mode=", root.mode, " frame=", main.size, " origin=", main.position)
		await _save(out_dir + "/" + fname + ".png")
		root.mode = Window.MODE_WINDOWED
		await _settle()

	# Settings panel open at 1920x1080, Pixel perfect.
	DisplaySettings.bleed_ready = false
	DisplaySettings.set_scale_mode(root, DisplaySettings.Scale.PIXEL)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _settle()
	DisplaySettings.apply(root)
	await _settle()
	Input.parse_input_event(_key(KEY_F10, true))
	Input.parse_input_event(_key(KEY_F10, false))
	await _settle()
	await _save(out_dir + "/settings_panel_1920x1080.png")
	quit(0)


func _settle() -> void:
	for i in SETTLE_FRAMES:
		await process_frame


func _key(code: Key, down: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = down
	return ev


## Crop the window's pixels out of the screen grab. On some machines the grab comes back non-null but
## fully transparent, so a blank grab is treated as missing. The fallback is the root viewport at its
## 640x360 base, which cannot show the window's real size; the log line says so.
func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var win_pos: Vector2i = DisplayServer.window_get_position()
	var win_size: Vector2i = DisplayServer.window_get_size()
	var img: Image = null
	var screen: Image = DisplayServer.screen_get_image()
	if screen != null and not screen.is_empty():
		# Crop first, so the blank test looks at the window and not at the whole desktop.
		var crop: Image = screen.get_region(Rect2i(win_pos, win_size))
		if not _is_blank(crop):
			img = crop
	if img == null:
		img = root.get_texture().get_image()
		print("WARN ", path, " window grab blank; saved the 640x360 base canvas instead of the window")
	print("save ", path, " size=", img.get_size(), " err=", img.save_png(path))


## The HUD's size on screen in window pixels: its base size times the window's final stretch.
## A canvas-local transform always reads 1.0, so the stretch has to come from get_final_transform().
func _hud_px(main: Node) -> Vector2:
	var hud: Control = main.get("hud") as Control
	if hud == null:
		return Vector2.ZERO
	return hud.size * root.get_final_transform().x.x


## True when every sampled pixel is fully transparent or the image has no size.
func _is_blank(img: Image) -> bool:
	var w: int = img.get_width()
	var h: int = img.get_height()
	if w == 0 or h == 0:
		return true
	for gy in 16:
		for gx in 16:
			var px: Color = img.get_pixel(clampi(w * gx / 15, 0, w - 1), clampi(h * gy / 15, 0, h - 1))
			if px.a > 0.0:
				return false
	return true
