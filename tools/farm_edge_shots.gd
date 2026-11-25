extends Node
## Farm layout capture: starts the real game in Larkmoor, walks to the farm's fields and south-east groves, and saves
## day and night PNGs to shots/farm_<spot>_<phase>.png.
## Run: godot --path . tools/farm_edge_shots.tscn   (headless servers: xvfb-run with the software Vulkan driver)
const SPOTS: Dictionary = {
	"west": Vector2(2030, 1010), "south": Vector2(2110, 1230), "east": Vector2(2250, 1060), "yard": Vector2(2160, 1100),
	"wide_n": Vector2(2080, 1020), "wide_s": Vector2(2140, 1200),
}
const PHASES: Dictionary = {"day": 0.5, "night": 0.9}

var main: Control


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


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
	sim.gates_open[&"zone1"] = true
	sim.zone_id = &"larkmoor"
	GameState.onboarding.tips_enabled = false
	SkyCycle.debug_season = 0
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _wait(40)
	var zoom: int = 2
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("zoom="):
			zoom = int(a.substr(5))
	for phase: String in PHASES:
		SkyCycle.debug_phase = float(PHASES[phase])
		await _wait(30)
		for spot: String in SPOTS:
			await _goto(SPOTS[spot] as Vector2, zoom)
			await _wait(10)
			get_tree().root.get_viewport().get_texture().get_image().save_png(
				ProjectSettings.globalize_path("res://shots/farm_%s_%s.png" % [spot, phase]))
			print("shot ", spot, " ", phase)
	get_tree().quit(0)
