extends SceneTree
## Season review shots of the real game view into shots/: the same noon (and golden hour) in each season, meadow
## or Larkmoor. Needs a renderer (xvfb + lavapipe works).
## Run: godot --path . --script tools/season_shots.gd -- [prefix] [larkmoor] [hud 0|1]
const SEASONS: PackedStringArray = ["spring", "summer", "autumn", "winter"]
const TIMES: Array = [["noon", 0.5], ["golden", 0.68], ["night", 0.02]]


func _initialize() -> void:
	_run()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "season"
	var show_hud: bool = args.size() > 2 and args[2] == "1"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var main: Control = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in 40:
		await process_frame
	if args.size() > 1 and args[1] == "larkmoor":
		var sim: Sim = main.sim
		for z: ZoneDef in sim.zone_defs.values():
			if z.next_zone == &"larkmoor":
				sim.gates_open[z.id] = true
		sim.enter_zone(&"larkmoor")
		for i in 200:
			await process_frame
	main.camera.zoom_level = 1
	if show_hud:
		main.sim.press_count = 1   # unlocks the stats panel and the clock
		root.get_node("GameState").onboarding.update()
	main.hud.visible = show_hud
	for s in 4:
		SkyCycle.debug_season = s
		for tm: Array in TIMES:
			SkyCycle.debug_phase = float(tm[1])
			SkyCycle.debug_rain = -1.0
			for i in 90:
				await process_frame
			var img: Image = root.get_viewport().get_texture().get_image()
			var path: String = ProjectSettings.globalize_path("res://shots/%s_%s_%s.png" % [prefix, SEASONS[s], String(tm[0])])
			img.save_png(path)
			print("shot ", path)
	quit(0)
