extends SceneTree
## Runs the render demo for N frames and saves a PNG, then quits. Needs a window (not --headless).
## Run: godot --path . --script tools/screenshot.gd -- [out.png] [frames] [key]
## key: optional input keycode name to press before capture (e.g. SPACE, 2, I, A).

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://shot.png"
	var frames: int = int(args[1]) if args.size() > 1 else 30
	var key: String = args[2] if args.size() > 2 else ""
	var demo := Control.new()
	demo.set_script(load("res://render/render_demo.gd"))
	var host := Control.new()  # PixelViewport is a Control and lays itself out against its parent's size
	host.add_child(demo)
	root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	for i in frames:
		if key != "" and i == frames / 2:
			var ev := InputEventKey.new()
			ev.keycode = OS.find_keycode_from_string(key)
			ev.pressed = true
			Input.parse_input_event(ev)
		await process_frame
	var pv: Control = demo.get("pv")
	if pv: print("pv size=", pv.size, " scale=", pv.get("scale_factor"), " clip=", pv._clip.size, pv._clip.position, " post=", pv.post.size, pv.post.scale, pv.post.position, " win=", root.size, DisplayServer.window_get_size())
	var img: Image = root.get_viewport().get_texture().get_image()
	var path: String = out if out.is_absolute_path() or out.begins_with("user://") else ProjectSettings.globalize_path("res://" + out)
	print("save ", path, " err=", img.save_png(path))
	quit(0)
