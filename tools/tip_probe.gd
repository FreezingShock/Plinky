extends Node
## Frame-exact tooltip trace. Run: godot --path . tools/tip_probe.tscn  (use an isolated APPDATA)
var main: Control
var root: Window
var sc: float = 1.0

var real: bool = false
func _move(pos: Vector2, flush: bool) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = pos
	mv.global_position = pos
	if real:
		Input.warp_mouse(root.get_final_transform() * pos)   # moves the real OS cursor: the pad path reads the viewport mouse
	root.push_input(mv, true)   # straight into the viewport: same-frame, no OS cursor involved

func _vis(kind: String) -> bool:
	if kind == "pad":
		return main.tooltip.visible
	return Tip.host(get_tree()).visible

## Moves onto `on`, then counts frames until visible; moves to `off`, counts frames until hidden.
func _trace(label: String, kind: String, on: Vector2, off: Vector2, flush: bool) -> void:
	_move(off, flush)
	await ShotHelpers.wait(8)
	var f0: int = Engine.get_process_frames()
	_move(on, flush)
	var show_f: int = -1
	for i in 8:
		await get_tree().process_frame
		if _vis(kind) and show_f < 0:
			show_f = Engine.get_process_frames() - f0
	var shot: String = ProjectSettings.globalize_path("res://captures/tip_%s.png" % label)
	root.get_viewport().get_texture().get_image().save_png(shot)
	var f1: int = Engine.get_process_frames()
	_move(off, flush)
	var hide_f: int = -1
	for i in 8:
		await get_tree().process_frame
		if not _vis(kind) and hide_f < 0:
			hide_f = Engine.get_process_frames() - f1
	print("TRACE %s flush=%s show_after_frames=%d hide_after_frames=%d" % [label, flush, show_f, hide_f])

func _ready() -> void:
	root = get_tree().root
	main = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await ShotHelpers.wait(60)
	sc = root.get_final_transform().x.x
	print("scale ", sc, " user ", ProjectSettings.globalize_path("user://"))
	var chip: Control = main.hud.get("_menu_chip") as Control
	var chip_c: Vector2 = chip.get_global_rect().get_center()
	var pad: Node2D = main.pads[main.pads.keys()[0]]
	var pad_c: Vector2 = pad.get_global_transform_with_canvas().origin
	var away: Vector2 = Vector2(320, 120)
	print("DBG ft ", root.get_final_transform(), " win ", DisplayServer.window_get_size(), " size ", root.size, " cs ", root.content_scale_size)
	_move(chip_c, true)
	await ShotHelpers.wait(2)
	print("DBG chip_c ", chip_c, " mouse ", main.get_viewport().get_mouse_position())
	_move(pad_c, true)
	await ShotHelpers.wait(3)
	var wl: Vector2 = main.world.get_local_mouse_position()
	print("DBG pad_c ", pad_c, " mouse ", main.get_viewport().get_mouse_position(), " hit ", pad.hit(wl), " hovered ", pad.hovered, " over ", main.get_viewport().gui_get_hovered_control(), " pos ", pad.position, " wl ", wl)
	for fl in [false, true]:
		real = true
		await _trace("pad", "pad", pad_c, away, fl)
		real = false
		await _trace("hud_button" if fl else "hud_button_noflush", "hud", chip_c, away, fl)
	# keyboard focus
	var chip2: Control = chip
	Tip.focus_muted = false
	chip2.grab_focus()
	await get_tree().process_frame
	print("TRACE focus visible_after_1_frame=", Tip.host(get_tree()).visible)
	chip2.release_focus()
	await ShotHelpers.wait(3)
	# menu open: no tooltip
	_move(away, true)
	await ShotHelpers.wait(5)
	main.menus.call("toggle", &"gallery") if main.menus.has_method("toggle") else null
	await ShotHelpers.wait(20)
	print("TRACE menu_open tip_visible=", Tip.host(get_tree()).visible, " menus_methods_toggle=", main.menus.has_method("toggle"))
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://captures/tip_menu_open.png"))
	get_tree().quit(0)
