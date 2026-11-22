extends SceneTree
## Screenshots of the day/night cycle and rain over the real game view, into shots/.
## Run: godot --path . --script tools/sky_shots.gd
## Writes sky_<name>.png for dawn, noon, dusk, midnight, then noon in rain and midnight in rain. 640x360 texel view,
## upscale 2x nearest for review.
const SHOTS: Array = [
	["dawn", 0.27, -1.0], ["noon", 0.5, -1.0], ["dusk", 0.73, -1.0], ["midnight", 0.0, -1.0],
	["noon_rain", 0.5, 1.0], ["midnight_rain", 0.0, 1.0],
]

func _initialize() -> void:
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var main: Control = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in 40:
		await process_frame
	for shot: Array in SHOTS:
		SkyCycle.debug_phase = float(shot[1])
		SkyCycle.debug_rain = float(shot[2])
		for i in 45:
			await process_frame
		var img: Image = root.get_viewport().get_texture().get_image()
		var path: String = ProjectSettings.globalize_path("res://shots/sky_%s.png" % String(shot[0]))
		img.save_png(path)
		print("shot ", path)
	quit(0)
