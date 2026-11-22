extends RefCounted
## Keyboard and gamepad input (ui/pad_input.gd): actions exist, bound to keys and pad, menus stop the walker.

func run(t: Object) -> void:
	PadInput.ensure()
	for a: StringName in [&"plinky_left", &"plinky_right", &"plinky_up", &"plinky_down", &"plinky_back", &"plinky_relics", &"plinky_upgrades", &"plinky_settings", &"plinky_zoom_in", &"plinky_zoom_out", &"plinky_recenter"]:
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
	t.eq(PadInput.move_vector(), Vector2.ZERO, "walker stands still while a menu is open")
	PadInput.menu_open = false
	Input.action_release(&"plinky_right")
	var root := Control.new()
	var dead := Button.new()
	dead.disabled = true
	var live := Button.new()
	root.add_child(dead)
	root.add_child(live)
	t.ok(PadInput.first_focusable(root) == live, "first_focusable skips disabled buttons")
	root.free()
