extends Node
## Windowed camera capture: zoom at a far cursor, rest the pointer at a window edge, right-drag pan, recentre.
## Saves PNG frames to shots/camera/ and prints the camera state at each step.
## Run: godot --path . tools/camera_shots.tscn   (needs a window; xvfb works in the cloud)

var main: Control
var root: Window
var cam: WorldCamera


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await get_tree().process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://shots/camera/%s.png" % name))
	print("shot %s centre=%s zoom=%d free=%s pan=%s" % [name, cam._center, cam.zoom_level, cam.is_free(), cam.pan])


func _btn(b: MouseButton, down: bool, pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = b
	ev.pressed = down
	ev.position = pos
	cam._unhandled_input(ev)


func _motion(rel: Vector2, pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.relative = rel
	ev.position = pos
	cam._unhandled_input(ev)


func _ready() -> void:
	root = get_tree().root
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/camera"))
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _wait(60)
	cam = main.camera
	await _shot("0_start")
	# 1. Wheel zoom in with the cursor far from the walker (a top-right corner of the view).
	cam.zoom_step(1, Vector2(600.0, 40.0))
	await _wait(2)
	await _shot("1_zoom_far_cursor")
	await _wait(120)
	await _shot("2_after_2s")
	# 2. The pointer rests on the left edge of the view for three seconds.
	cam.set_pointer_for_test(Vector2(2.0, 180.0))
	await _wait(180)
	await _shot("3_pointer_rests_at_edge")
	# 3. Right-drag pan away from the walker, then recentre.
	_btn(MOUSE_BUTTON_RIGHT, true, Vector2(320.0, 180.0))
	for i in 20:
		_motion(Vector2(-6.0, 2.0), Vector2(320.0, 180.0))
		await _wait(1)
	_btn(MOUSE_BUTTON_RIGHT, false, Vector2(320.0, 180.0))
	await _shot("4_after_drag_pan")
	cam.recenter()
	await _wait(150)
	await _shot("5_recentred")
	print("done")
	get_tree().quit(0)
