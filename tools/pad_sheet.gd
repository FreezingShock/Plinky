extends Node
## Contact sheet of the six tier pads (idle, buyable, locked) on a flat ground. Output: shots/pad_sheet.png
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
	var tiers: Array[String] = ["sprout", "clover", "thistle", "heather", "foxglove", "starbloom"]
	for r in 3:
		for i in 6:
			var id: StringName = StringName("%s_%d" % [tiers[i], 1 + (r % 3)])
			var pad: TexelPad = TexelPad.new()
			pad.button_id = id
			pad.walker = walker
			pad.position = Vector2(50 + i * 100, 70 + r * 110)
			world.add_child(pad)
			if r == 0:
				sim.stats[&"sunlight"] = BigNum.from_float(1.0e12)
			await get_tree().process_frame
	for i in 6:
		sim.stats[&"sunlight"] = BigNum.from_float(1.0e12)
	for k: StringName in sim.stat_defs:
		sim.stats[k] = BigNum.from_float(1.0e12)
	sim.dev_open_tiers()
	await get_tree().create_timer(1.4).timeout
	get_tree().root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/pad_sheet.png"))
	get_tree().quit(0)
