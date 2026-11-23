extends Node
## Tier pad tour: the meadow and Larkmoor with every tier open (and a second shot with the tiers locked).
## Run: godot --path . tools/tier_shots.tscn   (headless servers: xvfb-run with the software Vulkan driver)

var main: Control


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _wait(3)
	get_tree().root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/%s.png" % name))
	print("shot ", name)


func _goto(p: Vector2, zoom: int) -> void:
	main.walker.position = p
	main.walker.stop()
	while main.camera.zoom_level != zoom:
		main.camera.zoom_step(1 if main.camera.zoom_level < zoom else -1, Vector2(320, 180))
	main.camera.snap()
	await _wait(20)


func _tour(zone: StringName, tag: String) -> void:
	var sim: Sim = GameState.sim
	sim.zone_id = zone
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _wait(40)
	var z: ZoneDef = sim.current_zone()
	var ids: Array = z.pad_buttons
	for i: int in [0, ids.size() / 2, ids.size() - 1]:
		var pad: Node2D = main.pads.get(ids[i]) as Node2D
		if pad == null:
			continue
		await _goto(pad.position + Vector2(0, 14), 3)
		await _shot("%s_%d" % [tag, i])
	main.queue_free()
	await _wait(5)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var sim: Sim = GameState.sim
	sim.gates_open[&"zone1"] = true
	sim.dev_open_tiers()
	for k: StringName in [&"sunlight", &"dewdrop", &"clover", &"thistle", &"heather", &"foxglove", &"starbloom"]:
		sim.stats[k] = BigNum.from_float(1.0e5)
	await _tour(&"zone1", "t1")
	await _tour(&"larkmoor", "t2")
	get_tree().quit(0)
