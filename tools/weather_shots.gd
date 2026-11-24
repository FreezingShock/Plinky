extends Node
## Weather tour: starts the real game in Larkmoor's Green district and saves one PNG per weather and season pair
## to shots/ (weather_<name>.png). Run: godot --path . tools/weather_shots.tscn   (headless: xvfb-run with lavapipe)

var main: Control
var root: Window


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _wait(3)
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/weather_%s.png" % name))
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
	var anchors: Node = main.meadow.get_node("Anchors")
	var m: Marker2D = anchors.get_node("District_green") as Marker2D
	await _goto(m.position + Vector2(0, 10), 2)
	# name, season (0 spring, 1 summer, 2 autumn, 3 winter), rain (0 clear, 0.6 = the config's rain_max), phase (0.5 noon)
	var plan: Array = [
		["spring_clear", 0, 0.0, 0.5],
		["spring_rain", 0, 0.6, 0.5],
		["spring_rain_wet", 0, 0.6, 0.5],
		["summer_clear", 1, 0.0, 0.5],
		["autumn_clear", 2, 0.0, 0.5],
		["autumn_rain", 2, 0.6, 0.5],
		["winter_clear", 3, 0.0, 0.5],
		["winter_snow", 3, 0.6, 0.5],
	]
	plan.append_array([
		["night_rain", 1, 0.6, 0.0, false],
		["spring_rain_calm", 0, 0.6, 0.5, true],
		["spring_dawn", 0, 0.0, 0.25],
		["autumn_dawn", 2, 0.0, 0.25],
	])
	for p: Array in plan:
		SkyCycle.debug_season = int(p[1])
		SkyCycle.debug_rain = float(p[2])
		SkyCycle.debug_phase = float(p[3])
		MeadowLife.reduce_motion = p.size() > 4 and bool(p[4])
		await _wait(30)
		await _shot(String(p[0]))
	MeadowLife.reduce_motion = false
	SkyCycle.debug_season = -1
	SkyCycle.debug_rain = -1.0
	SkyCycle.debug_phase = -1.0
	get_tree().quit(0)
