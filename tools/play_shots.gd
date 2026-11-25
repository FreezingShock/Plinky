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

var _scale: float = 1.0

func _move(pos: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = pos * _scale
	mv.global_position = pos * _scale
	Input.parse_input_event(mv)

func _btn(pos: Vector2, button: MouseButton, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = down
	ev.position = pos * _scale
	ev.global_position = pos * _scale
	Input.parse_input_event(ev)

func _click(pos: Vector2, down: bool) -> void:
	_move(pos)
	_btn(pos, MOUSE_BUTTON_LEFT, down)

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
	await ShotHelpers.wait(40)
	await _shot("g1_start")
	_scale = root.get_final_transform().x.x
	var sim: Sim = GameState.sim
	print("scale ", _scale, " root size ", root.size, " win ", DisplayServer.window_get_size())
	var cam: WorldCamera = main.camera
	var ids: Array = main.pads.keys()
	sim.stats[&"embers"] = BigNum.from_float(5000.0)
	await ShotHelpers.wait(5)
	var pad: Node2D = main.pads[ids[0]]
	var p: Vector2 = pad.get_global_transform_with_canvas().origin
	if "behind" in OS.get_cmdline_user_args():
		main.set_process(false)
		cam.zoom_step(1, Vector2(320, 180))
		main.walker.position = Vector2(214, 126)  # inside the oak crown rect, above its foot at y=138
		await ShotHelpers.wait(50)
		await _shot("b_behind_tree")
		main.walker.position = Vector2(214, 150)  # in front of the same oak
		await ShotHelpers.wait(120)
		await _shot("b_in_front")
		var wp2: Vector2 = main.walker.get_global_transform_with_canvas().origin
		_click(wp2 + Vector2(70, 30), true)
		_click(wp2 + Vector2(70, 30), false)
		await ShotHelpers.wait(3)
		print("marker click world ", main.world.get_local_mouse_position(), " expected ", main.world.to_local(wp2 + Vector2(70, 30)) if false else (wp2 + Vector2(70, 30) - main.world.position) / 2.0)
		await _shot("b_marker")
		get_tree().quit(0)
		return
	if "popups" in OS.get_cmdline_user_args():
		main.set_process(false)
		await ShotHelpers.wait(30)
		await _shot("w_idle")
		var wp: Vector2 = main.walker.get_global_transform_with_canvas().origin
		_click(wp + Vector2(-60, 20), true)
		_click(wp + Vector2(-60, 20), false)
		await ShotHelpers.wait(14)
		await _shot("w_walk")
		await ShotHelpers.wait(60)
		for z in [1, 2]:
			while cam.zoom_level != z:
				cam.zoom_step(1 if cam.zoom_level < z else -1, Vector2(320, 180))
			await ShotHelpers.wait(40)
			sim.stats[&"embers"] = BigNum.from_float(1e30)
			p = pad.get_global_transform_with_canvas().origin
			pad.holding = true  # synthetic mouse input is unreliable offscreen; drive the pad directly
			pad._press()
			await ShotHelpers.wait(12)
			print("z", z, " p ", p, " presses ", sim.press_count, " holding ", pad.get("holding"), " can ", sim.can_afford(&"sprout_1"), " cost ", Formulas.button_cost(sim.button_defs[&"sprout_1"]).format())
			await _shot("p_z%d_press_hold" % z)
			await ShotHelpers.wait(60)
			await _shot("p_z%d_hold_long" % z)
			pad.hold_release()
			await ShotHelpers.wait(70)
		get_tree().quit(0)
		return
	# tooltip on hover
	_move(p + Vector2(40, 40))
	await ShotHelpers.wait(3)
	_move(p)
	await ShotHelpers.wait(3)
	_move(p + Vector2(1, 0))
	await ShotHelpers.wait(3)
	print("mouse ", main.get_viewport().get_mouse_position(), " pad ", p, " hit ", pad.hit(main.world.get_local_mouse_position()), " hovered ", main.get_viewport().gui_get_hovered_control())
	main.set_process(false)  # the offscreen window has no real cursor; show the tooltip directly
	main.tooltip.show_for(sim, ids[0], p)
	await ShotHelpers.wait(2)
	print("tooltip visible ", main.tooltip.visible)
	await _shot("h1_tooltip")
	# press and hold
	var cash0: String = sim.get_stat(&"embers").format()
	_btn(p, MOUSE_BUTTON_LEFT, true)
	await ShotHelpers.wait(90)
	_btn(p, MOUSE_BUTTON_LEFT, false)
	print("hold: presses ", sim.press_count, " cinder ", sim.get_stat(&"cinder").format(), " embers ", cash0, " -> ", sim.get_stat(&"embers").format())
	await _shot("h2_hold")
	# camera: zoom
	for z in 2:
		_btn(Vector2(320, 180), MOUSE_BUTTON_WHEEL_UP, true)
		await ShotHelpers.wait(2)
	await ShotHelpers.wait(30)
	print("zoom level ", cam.zoom_level, " world scale ", main.world.scale, " pos ", main.world.position)
	await _shot("h3_zoom")
	# right drag pan
	_move(Vector2(320, 180))
	_btn(Vector2(320, 180), MOUSE_BUTTON_RIGHT, true)
	for i in 10:
		var mm := InputEventMouseMotion.new()
		mm.position = (Vector2(320, 180) + Vector2(i * 8, 0)) * _scale
		mm.relative = Vector2(8, 0) * _scale
		Input.parse_input_event(mm)
		await ShotHelpers.wait(1)
	_btn(Vector2(400, 180), MOUSE_BUTTON_RIGHT, false)
	await ShotHelpers.wait(10)
	print("pan ", cam.pan, " presses after drag ", sim.press_count)
	await _shot("h4_pan")
	_key(KEY_HOME)
	await ShotHelpers.wait(40)
	print("after Home pan ", cam.pan)
	await _shot("h5_recentre")
	# Esc closes panel
	_key(KEY_R)
	await ShotHelpers.wait(5)
	await _shot("h6_relics_open")
	_key(KEY_ESCAPE)
	await ShotHelpers.wait(5)
	await _shot("h6_esc")
	get_tree().quit(0)
