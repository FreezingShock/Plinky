extends Node
## Captures the custom window frame: the title bar in the running scene, the settings panel, and wipe frames.
## Run: godot --path . tools/window_shots.tscn   (needs a window; saves PNGs to shots/)

func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://shots/%s.png" % name))
	print("shot ", name)


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	var main: Control = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _wait(40)
	await _shot("w1_titlebar")
	main.display_panel.open()
	await _wait(6)
	await _shot("w2_settings")
	main.display_panel.close()
	var frame: WindowFrame = main.window_frame
	frame._wipe.visible = true
	for i in [2, 4, 6, 8]:
		frame._set_progress(float(i) / 8.0)
		await _shot("w3_wipe_%d" % i)
	frame._wipe.visible = false
	DisplaySettings.native_frame = true
	await _wait(6)
	await _shot("w4_native_frame")
	get_tree().quit()
