extends SceneTree
## Captures the real main scene at several window sizes and both scale modes, then the settings panel.
## Writes PNGs to shots/sizes/. Needs a real window (not --headless).
## Run: godot --path . --script tools/size_shots.gd

## [width, height, scale mode (0 = Pixel perfect, 1 = Fit)]
const CASES: Array = [
	[1280, 720, 0],
	[1024, 768, 0],
	[1366, 768, 0],
	[1024, 768, 1],
	[1920, 1080, 0],
	[1920, 1080, 1],
	[1600, 1000, 1],
	[2560, 1080, 1],
	[800, 600, 1],
]
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
		DisplaySettings.set_scale_mode(root, c[2])
		DisplayServer.window_set_size(Vector2i(w, h))
		await _settle()
		DisplaySettings.apply(root)
		await _settle()
		var real: Vector2i = DisplayServer.window_get_size()
		var fname: String = "%dx%d_%s" % [real.x, real.y, "pixel" if c[2] == 0 else "fit"]
		print("shot ", fname, " scale=", DisplaySettings.integer_scale(root), " stretch=", root.content_scale_stretch)
		_save(out_dir + "/" + fname + ".png")

	# Settings panel open at 1920x1080 Pixel perfect.
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
