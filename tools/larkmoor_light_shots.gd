extends SceneTree
## Larkmoor lighting review: the real game in Larkmoor at dawn, noon, golden hour, dusk and midnight, at the
## lantern wood (pools) and at a wide zoom-1 overview (haze, shadows). HUD hidden. Needs a renderer (xvfb + lavapipe).
## Run: godot --path . --script tools/larkmoor_light_shots.gd -- [prefix]

const SHOTS: Array = [["dawn", 0.27], ["noon", 0.5], ["golden", 0.66], ["dusk", 0.74], ["midnight", 0.0]]

func _initialize() -> void:
	_run()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "lml"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	for i in 5:
		await process_frame
	var sim: Sim = (root.get_node("GameState") as Node).get("sim") as Sim
	sim.gates_open[&"zone1"] = true
	sim.zone_id = &"larkmoor"
	var main: Control = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in 40:
		await process_frame
	main.hud.visible = false
	var anchors: Node = main.meadow.get_node("Anchors")
	var spots: Array = [["wood", (anchors.get_node("District_lanternwood") as Marker2D).position + Vector2(0, 10), 2],
			["over", Vector2(760, 470), 1]]
	for sp: Array in spots:
		main.walker.position = sp[1]
		main.walker.stop()
		while main.camera.zoom_level != int(sp[2]):
			main.camera.zoom_step(1 if main.camera.zoom_level < int(sp[2]) else -1, Vector2(320, 180))
		main.camera.snap()
		for shot: Array in SHOTS:
			SkyCycle.debug_phase = float(shot[1])
			for i in 45:
				await process_frame
			var path: String = ProjectSettings.globalize_path("res://shots/%s_%s_%s.png" % [prefix, String(sp[0]), String(shot[0])])
			root.get_viewport().get_texture().get_image().save_png(path)
			print("shot ", path)
	quit(0)
