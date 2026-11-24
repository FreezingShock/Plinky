extends Node
## Lantern check: starts the real game in Larkmoor, pins the sky to night, dusk and noon in turn, walks the walker up to
## evenly spaced lamps at zoom 3 and saves PNGs to shots/lantern_<phase>_<n>.png. The lamps come from the Larkmoor sprite
## manifest, so the shots follow the placement that the art was built with.
## Pass "-- meadow" to shoot the starting meadow (zone 1, its own manifest) instead of Larkmoor.
## Run: godot --path . tools/lantern_shots.tscn [-- meadow]   (headless servers: xvfb-run with the software Vulkan driver)

const PHASES: Array = [["night", 0.9], ["dusk", 0.8], ["noon", 0.5]]
const PICKS: int = 4
const MANIFESTS: Dictionary = {"larkmoor": "res://assets/art/zone1b/larkmoor/placements3d.json", "meadow": "res://assets/art/zone1/meadow3d/placements3d.json"}
const ZONES: Dictionary = {"larkmoor": &"larkmoor", "meadow": &"zone1"}

var main: Control
var root: Window


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


## Ordinary lamps (the great lantern is taller and has its own look), sorted by their foot, every k-th one picked.
func _lamp_feet(manifest: String) -> Array:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest))
	var feet: Array = []
	for s: Dictionary in data.sprites:
		if String(s.kind) == "lantern" and float(s.w) < 20.0:
			feet.append(Vector2(float(s.foot[0]), float(s.foot[1])))
	feet.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var out: Array = []
	for i in PICKS:
		out.append(feet[(feet.size() - 1) * i / maxi(PICKS - 1, 1)])
	return out


func _ready() -> void:
	root = get_tree().root
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var which: String = "meadow" if "meadow" in OS.get_cmdline_user_args() else "larkmoor"
	var sim: Sim = GameState.sim
	sim.gates_open[&"zone1"] = true
	sim.zone_id = ZONES[which]
	SkyCycle.debug_season = 0
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _wait(40)
	var feet: Array = _lamp_feet(MANIFESTS[which])
	for ph: Array in PHASES:
		SkyCycle.debug_phase = float(ph[1])
		for i in feet.size():
			var f: Vector2 = feet[i]
			await _goto(f + Vector2(10.0, 12.0), 3)
			await _wait(30)
			root.get_viewport().get_texture().get_image().save_png(
					ProjectSettings.globalize_path("res://shots/lantern_%s_%s_%d.png" % [which, String(ph[0]), i]))
			print("shot ", ph[0], " ", i, " ", f)
	get_tree().quit(0)
