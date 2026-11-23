extends SceneTree
## Lighting review shots of the real game view into shots/: a full 640x360 meadow at zoom 1 with the HUD hidden, at
## dawn, noon, golden hour, dusk, midnight, and dawn and dusk in rain. Needs a renderer (xvfb + lavapipe works).
## Run: godot --path . --script tools/light_shots.gd -- [prefix] [zoom 1..4] [hud 0|1] [larkmoor] [north|lake]
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
	var zoom: int = int(args[1]) if args.size() > 1 else 1
	var show_hud: bool = args.size() > 2 and args[2] == "1"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var main: Control = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in 40:
		await process_frame
	if args.size() > 3 and args[3] == "larkmoor":
		var sim: Sim = main.sim
		for z: ZoneDef in sim.zone_defs.values():
			if z.next_zone == &"larkmoor":
				sim.gates_open[z.id] = true
		sim.enter_zone(&"larkmoor")
		for i in 200:
			await process_frame
	main.camera.zoom_level = zoom
	main.camera.auto_return = true
	if args.size() > 4 and args[4] == "north":   # look at the mountain strip along the top of Larkmoor
		main.camera.auto_return = false
		main.camera.pan = Vector2(0.0, -420.0)
	elif args.size() > 4 and args[4] == "lake":
		main.camera.auto_return = false
		main.camera.pan = Vector2(-220.0, 60.0)
	main.hud.visible = show_hud
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
