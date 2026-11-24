extends Node
## Contact sheet of the six Larkmoor tier pads, stages 1 to 5 (one row per stage), on a flat ground. Output: shots/pad_sheet_<mode>.png
## Run: godot --path . tools/pad_sheet.tscn   (xvfb-run with the software Vulkan driver on a headless server)


func _ready() -> void:
	var sim: Sim = GameState.sim
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("5f8f4a")
	bg.size = Vector2(640, 360)
	add_child(bg)
	var world: Node2D = Node2D.new()
	add_child(world)
	var walker: Node2D = Node2D.new()
	walker.position = Vector2(-900, -900)
	world.add_child(walker)
	var tiers: Array[String] = ["lark_sprout", "lark_clover", "thistle", "heather", "foxglove", "starbloom"]
	for r in 5:
		for i in 6:
			var id: StringName = StringName("%s_%d" % [tiers[i], 1 + r])
			var pad: TexelPad = TexelPad.new()
			pad.button_id = id
			pad.walker = walker
			pad.position = Vector2(50 + i * 100, 40 + r * 62)
			world.add_child(pad)
			if r == 0:
				sim.stats[&"sunlight"] = BigNum.from_float(1.0e12)
			await get_tree().process_frame
	var mode: String = "rich"
	for arg: String in OS.get_cmdline_user_args():
		mode = arg   # rich (buyable), poor (open but unaffordable) or locked
	for k: StringName in sim.stat_defs:
		sim.stats[k] = BigNum.from_float(1.0e12 if mode == "rich" else 0.0)
	if mode != "locked":
		sim.dev_open_tiers()
	await get_tree().create_timer(1.4).timeout
	get_tree().root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/pad_sheet_%s.png" % mode))
	get_tree().quit(0)
