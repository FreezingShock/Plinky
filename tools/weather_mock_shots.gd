extends Node
## Night and dusk weather mockups: starts the real game in Larkmoor's Green district and saves clear and rain frames
## at night and dusk to shots/mock_<name>.png. Run under xvfb with lavapipe:
##   xvfb-run godot --path . tools/weather_mock_shots.tscn

var main: Control
var root: Window



func _shot(name: String) -> void:
	await ShotHelpers.wait(3)
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/mock_%s.png" % name))
	print("shot ", name)


func _goto(p: Vector2, zoom: int) -> void:
	main.walker.position = p
	main.walker.stop()
	while main.camera.zoom_level != zoom:
		main.camera.zoom_step(1 if main.camera.zoom_level < zoom else -1, Vector2(320, 180))
	main.camera.snap()
	await ShotHelpers.wait(20)


func _ready() -> void:
	root = get_tree().root
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var sim: Sim = GameState.sim
	sim.gates_open[&"zone1"] = true
	sim.zone_id = &"larkmoor"
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await ShotHelpers.wait(40)
	var anchors: Node = main.meadow.get_node("Anchors")
	var m: Marker2D = anchors.get_node("District_green") as Marker2D
	await _goto(m.position + Vector2(-60, 30), 2)
	# name, season, rain, phase (0 midnight, 0.25 dawn, 0.5 noon, 0.75 dusk)
	var plan: Array = [
		["night_clear", 1, 0.0, 0.0],
		["night_rain", 1, 0.6, 0.0],
		["dusk_clear", 2, 0.0, 0.75],
		["dusk_rain", 2, 0.6, 0.75],
	]
	for p: Array in plan:
		# clean frame for the look: no HUD, tooltip or offline popup over the world
		main.hud.visible = false
		main.tooltip.hide_tip()
		SkyCycle.debug_season = int(p[1])
		SkyCycle.debug_rain = float(p[2])
		SkyCycle.debug_phase = float(p[3])
		await ShotHelpers.wait(30)
		await _shot(String(p[0]))
	SkyCycle.debug_season = -1
	SkyCycle.debug_rain = -1.0
	SkyCycle.debug_phase = -1.0
	get_tree().quit(0)
