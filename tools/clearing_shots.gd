extends Node
## Starting Clearing tour: starts the real game in zone 1 with the tutorial's pads open, then frames the Sprout and Clover
## rows at zoom 2 and the whole zone at zoom 1, and saves PNGs to shots/clearing_<name>.png.
## Run: godot --path . tools/clearing_shots.tscn   (headless servers: xvfb-run with the software Vulkan driver).
## `-- phase=0.95` pins deep night (names end in _p095). Look at the PNGs.

var main: Control
var root: Window
var suffix: String = ""



func _shot(name: String) -> void:
	await ShotHelpers.wait(3)
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/%s.png" % name))
	print("shot ", name, "  nodes ", get_tree().get_node_count())


func _goto(p: Vector2, zoom: int) -> void:
	main.walker.position = p
	main.walker.stop()
	while main.camera.zoom_level != zoom:
		main.camera.zoom_step(1 if main.camera.zoom_level < zoom else -1, Vector2(320, 180))
	main.camera.snap()
	await ShotHelpers.wait(40)


func _centre(prefix: String) -> Vector2:
	var c := Vector2.ZERO
	var n: int = 0
	for id: StringName in main.pads:
		if String(id).begins_with(prefix):
			c += (main.pads[id] as Node2D).position
			n += 1
	return c / float(maxi(n, 1))


func _ready() -> void:
	root = get_tree().root
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("phase="):
			SkyCycle.debug_phase = float(a.substr(6))
			suffix = "_p" + a.substr(6).replace(".", "")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var sim: Sim = GameState.sim
	sim.gates_open[&"zone1"] = true
	sim.zone_id = &"zone1"
	sim.dev_open_tiers()
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await ShotHelpers.wait(40)
	await _goto(Vector2(320, 180), 1)
	await _shot("clearing_zone%s" % suffix)
	for row: String in ["sprout", "clover"]:
		var c: Vector2 = _centre(row + "_")
		await _goto(c + Vector2(0, 46), 2)
		await _shot("clearing_%s%s" % [row, suffix])
	get_tree().quit(0)
