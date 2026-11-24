extends Node
## Flower capture: the tutorial meadow (zone 1) and the Larkmoor verges at game zoom 1 and 2, in daylight, saved to shots/flowers_*.png.
## Run: xvfb-run -a godot --rendering-driver vulkan --path . tools/flower_shots.tscn  (add `-- phase=0.5` to pin the time of day).

var main: Control
var root: Window
var suffix: String = ""


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	_clear_overlays(main)
	await _wait(3)
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/%s%s.png" % [name, suffix]))
	print("shot ", name, suffix)


## Drops the offline-earnings card (ui/welcome_card.gd, ui/welcome_tile.gd) so the shots show the world.
func _clear_overlays(n: Node) -> void:
	for c in n.get_children():
		var sp: Script = c.get_script() as Script
		if sp != null and (sp.resource_path.contains("welcome_card") or sp.resource_path.contains("welcome_tile")):
			if c is CanvasItem:
				(c as CanvasItem).visible = false   # hide, not free: the HUD keeps a reference to the card
		_clear_overlays(c)


func _goto(p: Vector2, zoom: int) -> void:
	main.walker.position = p
	main.walker.stop()
	while main.camera.zoom_level != zoom:
		main.camera.zoom_step(1 if main.camera.zoom_level < zoom else -1, Vector2(320, 180))
	main.camera.snap()
	await _wait(40)


func _ready() -> void:
	root = get_tree().root
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("phase="):
			SkyCycle.debug_phase = float(a.substr(6))
			suffix = "_p" + a.substr(6).replace(".", "")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var sim: Sim = GameState.sim
	sim.zone_id = &"zone1"
	sim.calendar.jump_to_season(0)
	sim.calendar.set_day_fraction(0.5)   # noon
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _wait(40)
	_clear_overlays(main)
	await _wait(10)
	var start: Vector2 = main.walker.position
	await _goto(start, 1)
	await _shot("flowers_meadow_wide")
	await _goto(start, 2)
	await _shot("flowers_meadow_close")
	get_tree().quit(0)
