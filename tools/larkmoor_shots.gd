extends Node
## Larkmoor tour: starts the real game in Larkmoor, teleports the walker to each district and saves PNGs to shots/.
## Run: godot --path . tools/larkmoor_shots.tscn   (headless servers: xvfb-run with the software Vulkan driver)

var main: Control
var root: Window


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _wait(3)
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/%s.png" % name))
	print("shot ", name)


func _goto(p: Vector2, zoom: int) -> void:
	main.walker.position = p
	main.walker.stop()
	while main.camera.zoom_level != zoom:
		main.camera.zoom_step(1 if main.camera.zoom_level < zoom else -1, Vector2(320, 180))
	main.camera.snap()
	await _wait(20)


func _ready() -> void:
	root = get_tree().root
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var sim: Sim = GameState.sim
	sim.gates_open[&"zone1"] = true
	sim.zone_id = &"larkmoor"
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _wait(40)
	await _shot("lm_start")
	var anchors: Node = main.meadow.get_node("Anchors")
	for d: String in ["green", "heronmere", "thistle", "oak", "cairnfold", "lanternwood", "emberwatch"]:
		var m: Marker2D = anchors.get_node("District_" + d) as Marker2D
		await _goto(main.walker.position, 2)
		await _goto(m.position + Vector2(0, 10), 2)
		await _wait(10)
		await _shot("lm_" + d)
	await _goto(Vector2(760, 470), 1)
	await _shot("lm_overview")
	var gate: Marker2D = anchors.get_node("Gate") as Marker2D
	await _goto(gate.position + Vector2(0, 40), 3)
	await _shot("lm_gate")
	get_tree().quit(0)
