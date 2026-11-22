extends SceneTree
## Captures the zone 1 world life over time, frames every 0.25 s into shots/ (for a GIF).
## Run: godot --path . --script tools/life_shots.gd -- [frames] [reduce] [meadow]
##   reduce: turns MeadowLife.reduce_motion on for the run.
##   meadow: captures the bare meadow scene (full backdrop, no HUD, no camera) instead of the game view.
## Output is the 640x360 texel view. Upscale 2x nearest for review (the game window does the same).

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var frames: int = int(args[0]) if args.size() > 0 else 12
	var reduce: bool = args.size() > 1 and args[1] == "reduce"
	var bare: bool = args.size() > 2 and args[2] == "meadow"
	MeadowLife.reduce_motion = reduce
	_run(frames, reduce, bare)


func _run(frames: int, reduce: bool, bare: bool) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var host: Node
	if bare:
		host = (load("res://world/meadow_scene.tscn") as PackedScene).instantiate()
		root.add_child(host)
	else:
		var main: Control = (load("res://main.tscn") as PackedScene).instantiate()
		root.add_child(main)
		main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		host = main
	for i in 40:
		await process_frame  # settle the first palette and layout
	if not bare:
		var sim: Object = root.get_node("/root/GameState").sim
		sim.stats[&"cash"] = BigNum.from_float(5000.0)
	var tag: String = ("meadow" if bare else "game") + ("_reduce" if reduce else "")
	for i in frames:
		for j in 15:
			await process_frame  # 15 frames is about 0.25 s at 60 fps
		var img: Image = root.get_viewport().get_texture().get_image()
		var path: String = ProjectSettings.globalize_path("res://shots/life_%s_%02d.png" % [tag, i])
		img.save_png(path)
		print("frame ", path)
	quit(0)
