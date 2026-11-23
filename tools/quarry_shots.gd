extends Node
## Ember Quarry ladder tour: the whole quarry at zoom 1, then one pad per row at zoom 4. Pass "locked" for the locked look.
## Run: godot --path . tools/quarry_shots.tscn   (headless servers: xvfb-run with the software Vulkan driver)

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


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var sim: Sim = GameState.sim
	var locked: bool = "locked" in OS.get_cmdline_user_args()
	sim.gates_open[&"zone1"] = true
	sim.gates_open[&"larkmoor"] = true
	sim.zone_id = &"zone2"
	if not locked:
		sim.dev_open_tiers()
	for k: StringName in [&"cash", &"mult", &"ironore", &"slag", &"ingot", &"alloy", &"emberheart"]:
		sim.stats[k] = BigNum.from_float(1.0e5)
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _wait(40)
	var tag: String = "_locked" if locked else ""
	await _goto(Vector2(320, 180), 1)
	await _shot("q_overview" + tag)
	var ids: Array = sim.current_zone().pad_buttons
	for row in 6:
		var pad: Node2D = main.pads.get(ids[row * 3 + 1]) as Node2D
		if pad == null:
			continue
		await _goto(pad.position + Vector2(0, 14), 4)
		await _shot("q_row%d%s" % [row + 1, tag])
	get_tree().quit(0)
