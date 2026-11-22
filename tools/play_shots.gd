extends Node
## Windowed gameplay capture: runs main.tscn, presses/holds pads, opens panels, saves PNGs to shots/.
## Run: godot --path . tools/play_shots.tscn   (one batched window; use --position to park it)

var main: Control
var root: Window

func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://shots/%s.png" % name))
	print("shot ", name)

func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _click(pos: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = pos
	ev.global_position = pos
	var mv := InputEventMouseMotion.new()
	mv.position = pos
	mv.global_position = pos
	root.push_input(mv)
	root.push_input(ev)

func _key(k: Key) -> void:
	for d in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.physical_keycode = k
		ev.pressed = d
		root.push_input(ev)

func _ready() -> void:
	root = get_tree().root
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _wait(40)
	await _shot("g1_start")
	var sim: Sim = GameState.sim
	var ids: Array = main.pads.keys()
	print("pads: ", ids, " zone ", sim.zone_id)
	sim.stats[&"cash"] = BigNum.from_float(50.0)
	await _wait(5)
	var first: Node2D = main.pads[ids[0]]
	var p: Vector2 = first.get_global_transform_with_canvas().origin
	print("pad screen pos ", p)
	_click(p, true)
	await _wait(2)
	print("hover ", root.gui_get_hovered_control(), " gmouse ", first.get_global_mouse_position(), " local ", first.to_local(first.get_global_mouse_position()), " holding ", first.get("holding"))
	await _wait(6)
	await _shot("g2_press")
	await _wait(60)
	await _shot("g3_hold")
	_click(p, false)
	print("press_count ", sim.press_count, " m1 stat ", sim.get_stat(&"mult").format())
	_key(KEY_TAB)
	await _wait(5)
	await _shot("g4_upgrades")
	_key(KEY_TAB)
	_key(KEY_R)
	await _wait(10)
	await _shot("g5_relics")
	_key(KEY_ESCAPE)
	await _wait(3)
	# open the gate
	sim.stats[&"reb"] = BigNum.from_float(20.0)
	sim.step(0.1)
	await _wait(60)
	await _shot("g6_gate")
	get_tree().quit(0)
