extends RefCounted
## Keyboard and gamepad input (ui/pad_input.gd): actions exist, bound to keys and pad; menus leave WASD walking and stop the arrows, pad and stick from walking.

func run(t: Object) -> void:
	PadInput.ensure()
	for a: StringName in [&"plinky_left", &"plinky_right", &"plinky_up", &"plinky_down", &"plinky_back", &"plinky_relics", &"plinky_upgrades", &"plinky_settings", &"plinky_zoom_in", &"plinky_zoom_out", &"plinky_recenter", &"plinky_jump"]:
		t.ok(InputMap.has_action(a), "%s is registered" % a)
	var has_pad: bool = false
	var has_key: bool = false
	for e: InputEvent in InputMap.action_get_events(&"plinky_back"):
		has_pad = has_pad or e is InputEventJoypadButton
		has_key = has_key or e is InputEventKey
	t.ok(has_pad and has_key, "back is bound to a key and a pad button")
	var stick: bool = false
	for e: InputEvent in InputMap.action_get_events(&"plinky_left"):
		stick = stick or e is InputEventJoypadMotion
	t.ok(stick, "left stick drives walking")
	PadInput.menu_open = false
	Input.action_press(&"plinky_right")
	t.ok(PadInput.move_vector().x > 0.9, "right input walks right")
	PadInput.menu_open = true
	t.eq(PadInput.move_vector(), Vector2.ZERO, "arrows and the stick do not walk while a menu is open (they move menu focus)")
	PadInput.menu_open = false
	Input.action_release(&"plinky_right")
	# WASD walks with a menu open; the arrow and stick actions still do not
	t.eq(PadInput.walk_from_keys(false, true, false, false), Vector2(1, 0), "D walks right")
	t.eq(PadInput.walk_from_keys(true, false, false, false), Vector2(-1, 0), "A walks left")
	t.eq(PadInput.walk_from_keys(false, false, true, false), Vector2(0, -1), "W walks up the screen")
	t.eq(PadInput.walk_from_keys(false, false, false, true), Vector2(0, 1), "S walks down the screen")
	t.eq(PadInput.walk_from_keys(true, true, false, false), Vector2.ZERO, "opposite keys cancel")
	var diag: Vector2 = PadInput.walk_from_keys(false, true, false, true)
	t.ok(absf(diag.length() - 1.0) < 0.001 and diag.x > 0.0 and diag.y > 0.0, "a diagonal is scaled to length 1")
	t.eq(PadInput.walk_from_keys(false, false, false, false), Vector2.ZERO, "no keys held, no walk")
	var has_a: bool = false
	for e: InputEvent in InputMap.action_get_events(&"plinky_left"):
		has_a = has_a or (e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_A)
	t.ok(has_a, "A is bound to plinky_left, which the menu walk reads by physical key")
	PadInput.menu_open = true
	Input.action_press(&"plinky_down")
	t.eq(PadInput.move_vector(), Vector2.ZERO, "the S action alone does not walk while a menu is open")
	Input.action_release(&"plinky_down")
	PadInput.menu_open = false
	var root := Control.new()
	var dead := Button.new()
	dead.disabled = true
	var live := Button.new()
	root.add_child(dead)
	root.add_child(live)
	t.ok(PadInput.first_focusable(root) == live, "first_focusable skips disabled buttons")
	root.free()
