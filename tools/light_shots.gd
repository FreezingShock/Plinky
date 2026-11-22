extends SceneTree
## Lighting review shots of the real game view into shots/: a full 640x360 meadow at zoom 1 with the HUD hidden, at
## dawn, noon, golden hour, dusk, midnight, and dawn and dusk in rain. Needs a renderer (xvfb + lavapipe works).
## Run: godot --path . --script tools/light_shots.gd -- [prefix]
## Write PNGs to shots/<prefix>_<name>.png

const SHOTS: Array = [
	["dawn", 0.27, -1.0], ["morning", 0.36, -1.0], ["noon", 0.5, -1.0], ["golden", 0.66, -1.0], ["dusk", 0.74, -1.0],
	["twilight", 0.80, -1.0], ["midnight", 0.0, -1.0], ["dawn_rain", 0.27, 1.0],
]

func _initialize() -> void:
	_run()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "light"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var main: Control = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in 40:
		await process_frame
	main.camera.zoom_level = 1
	main.camera.auto_return = true
	main.hud.visible = false
	for shot: Array in SHOTS:
		SkyCycle.debug_phase = float(shot[1])
		SkyCycle.debug_rain = float(shot[2])
		for i in 45:
			await process_frame
		var img: Image = root.get_viewport().get_texture().get_image()
		var path: String = ProjectSettings.globalize_path("res://shots/%s_%s.png" % [prefix, String(shot[0])])
		img.save_png(path)
		print("shot ", path)
	quit(0)
