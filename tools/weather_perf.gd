extends Node
## Weather performance probe: starts the real game in Larkmoor's Green district, then times the frame for each
## weather and time-of-day pair over a fixed number of frames and prints the mean and the 95th percentile.
## Run under xvfb with lavapipe (software GPU, so the numbers rank the costs but are not device timings):
##   xvfb-run godot --path . tools/weather_perf.tscn

var main: Control
var root: Window



func _measure(label: String, frames: int) -> void:
	var times: PackedFloat64Array = PackedFloat64Array()
	for i in frames:
		await get_tree().process_frame
		times.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0 + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	var sorted: PackedFloat64Array = times.duplicate()
	sorted.sort()
	var sum: float = 0.0
	for t: float in times:
		sum += t
	var p95: float = sorted[mini(int(float(sorted.size()) * 0.95), sorted.size() - 1)]
	print("PERF %-14s mean %.2f ms  p95 %.2f ms  fps %.0f" % [label, sum / float(frames), p95, Engine.get_frames_per_second()])


func _ready() -> void:
	root = get_tree().root
	var sim: Sim = GameState.sim
	sim.gates_open[&"zone1"] = true
	sim.zone_id = &"larkmoor"
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await ShotHelpers.wait(40)
	var anchors: Node = main.meadow.get_node("Anchors")
	var m: Marker2D = anchors.get_node("District_green") as Marker2D
	main.walker.position = m.position + Vector2(-60, 30)
	main.walker.stop()
	while main.camera.zoom_level != 2:
		main.camera.zoom_step(1, Vector2(320, 180))
	main.camera.snap()
	await ShotHelpers.wait(60)
	var plan: Array = [
		["day_clear", 0.0, 0.5],
		["day_rain", 0.6, 0.5],
		["night_clear", 0.0, 0.0],
		["night_rain", 0.6, 0.0],
	]
	for p: Array in plan:
		SkyCycle.debug_season = 2
		SkyCycle.debug_rain = float(p[1])
		SkyCycle.debug_phase = float(p[2])
		await ShotHelpers.wait(60)
		await _measure(String(p[0]), 240)
	SkyCycle.debug_season = -1
	SkyCycle.debug_rain = -1.0
	SkyCycle.debug_phase = -1.0
	get_tree().quit(0)
