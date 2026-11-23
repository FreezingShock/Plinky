extends Node
## Windowed capture of the walker's new moves: idle, walk, sprint, jump (rise, apex, fall), slide, crouch, Ctrl lock.
## Saves PNG frames to shots/walker/ plus a per-frame log of lift, speed factor and camera for the jump.
## Run: godot --path . --fixed-fps 60 tools/walker_shots.tscn   (needs a window)

var main: Control
var root: Window
var _n: int = 0
var _seq: bool = false


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame
		if _seq:
			_save("seq/f%04d" % _n)
			_n += 1


func _save(name: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://shots/walker/%s.png" % name))


func _shot(name: String) -> void:
	await get_tree().process_frame
	_save(name)
	print("shot ", name)


func _key(k: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = down
	Input.parse_input_event(ev)


func _ready() -> void:
	root = get_tree().root
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/walker/seq"))
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameState.onboarding.tips_enabled = false
	GameState.sim.press_count = 1
	await _wait(40)
	var cam: WorldCamera = main.camera
	var w: TexelWalker = main.walker
	var spawn: Vector2 = w.position
	await _wait(60)
	await _shot("w_idle")
	_key(KEY_D, true)
	await _wait(40)
	await _shot("w_walk")
	_key(KEY_SHIFT, true)
	await _wait(60)
	await _shot("w_sprint")
	print("sprint factor ", w.speed_factor, " state ", w.sprint_state())
	# Jump while sprinting; log lift, factor and the camera each frame.
	w.position = spawn
	await _wait(25)
	_seq = true
	_key(KEY_SPACE, true)
	for f in 36:
		await _wait(1)
		print("f%d lift %.1f vz %.0f factor %.2f airborne %s cam %s" % [f, w.lift, w.motion.vz, w.speed_factor, w.airborne, str(cam._center)])
		if f == 5:
			_save("w_jump_rise")
		if f == 14:
			_save("w_jump_apex")
		if f == 24:
			_save("w_jump_fall")
	_key(KEY_SPACE, false)
	await _wait(20)
	# Slide.
	w.position = spawn
	await _wait(25)
	_key(KEY_C, true)
	await _wait(6)
	_save("w_slide")
	print("slide ", w.motion.sliding(), " factor ", w.speed_factor)
	_key(KEY_C, false)
	await _wait(50)
	_seq = false
	# Ctrl lock: let go of Shift, tap Ctrl.
	_key(KEY_SHIFT, false)
	_key(KEY_CTRL, true)
	_key(KEY_CTRL, false)
	await _wait(40)
	await _shot("w_locked")
	print("locked state ", w.sprint_state())
	_key(KEY_CTRL, true)
	_key(KEY_CTRL, false)
	_key(KEY_D, false)
	await _wait(30)
	_key(KEY_C, true)
	await _wait(25)
	await _shot("w_crouch")
	_key(KEY_C, false)
	await _wait(10)
	print("DONE")
	get_tree().quit(0)
