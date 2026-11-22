extends SceneTree
## Captures the real main scene at several window sizes and scale modes, then the settings panel.
## Writes PNGs to shots/sizes/. Needs a real window (not --headless).
## Run: godot --path . --import (once, to refresh the class cache), then
##      godot --path . --script tools/size_shots.gd

## [width, height, scale mode (0 Pixel perfect, 1 Fit, 2 Wide view), bleed preview (0 off, 1 on)]
const CASES: Array = [
	[1280, 720, 0, 0],
	[1024, 768, 0, 0],
	[1366, 768, 0, 0],
	[1024, 768, 1, 0],
	[1920, 1080, 0, 0],
	[1920, 1080, 1, 0],
	[1600, 1000, 1, 0],
	[2560, 1080, 2, 0],
	[2560, 1080, 2, 1],
	[1920, 1080, 2, 1],
	[800, 600, 2, 0],
]
const MODE_NAMES: Array = ["pixel", "fit", "wide"]
const SETTLE_FRAMES: int = 12


func _init() -> void:
	var out_dir: String = ProjectSettings.globalize_path("res://shots/sizes")
	DirAccess.make_dir_recursive_absolute(out_dir)
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
			" aspect=", root.content_scale_aspect, " frame=", main.size, " origin=", main.position)
		_save(out_dir + "/" + fname + ".png")

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
	_save(out_dir + "/settings_panel_1920x1080.png")
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


func _save(path: String) -> void:
	var img: Image = root.get_texture().get_image()
	print("save ", path, " err=", img.save_png(path))
