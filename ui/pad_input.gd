class_name PadInput
extends RefCounted
## One place for keyboard and gamepad input. Registers the plinky_* actions at runtime (no project.godot edit),
## reads the walk vector, and finds the first focusable control in a panel so menus work without a mouse.
## Menus use Godot's ui_* actions (arrows, d-pad, left stick, Enter/Space, pad A); pad B and Esc are plinky_back.

const DEADZONE: float = 0.3

## True while any menu is open. The walker stands still then, so the stick and arrows drive menu focus instead.
static var menu_open: bool = false
static var _ready: bool = false


static func ensure() -> void:
	if _ready:
		return
	_ready = true
	for pair: Array in [
			[&"plinky_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [JOY_AXIS_LEFT_X, -1.0]],
			[&"plinky_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [JOY_AXIS_LEFT_X, 1.0]],
			[&"plinky_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], [JOY_AXIS_LEFT_Y, -1.0]],
			[&"plinky_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], [JOY_AXIS_LEFT_Y, 1.0]],
			[&"plinky_pan_left", [], [], [JOY_AXIS_RIGHT_X, -1.0]],
			[&"plinky_pan_right", [], [], [JOY_AXIS_RIGHT_X, 1.0]],
			[&"plinky_pan_up", [], [], [JOY_AXIS_RIGHT_Y, -1.0]],
			[&"plinky_pan_down", [], [], [JOY_AXIS_RIGHT_Y, 1.0]],
			[&"plinky_back", [KEY_ESCAPE], [JOY_BUTTON_B], []],
			[&"plinky_settings", [KEY_F10], [JOY_BUTTON_START], []],
			[&"plinky_relics", [KEY_R], [JOY_BUTTON_Y], []],
			[&"plinky_upgrades", [KEY_TAB], [JOY_BUTTON_X], []],
			[&"plinky_zoom_in", [KEY_EQUAL, KEY_KP_ADD, KEY_PAGEUP], [JOY_BUTTON_RIGHT_SHOULDER], []],
			[&"plinky_zoom_out", [KEY_MINUS, KEY_KP_SUBTRACT, KEY_PAGEDOWN], [JOY_BUTTON_LEFT_SHOULDER], []],
			[&"plinky_recenter", [KEY_C, KEY_HOME], [JOY_BUTTON_RIGHT_STICK], []]]:
		var action: StringName = pair[0]
		if not InputMap.has_action(action):
			InputMap.add_action(action, DEADZONE)
		for k: int in pair[1]:
			var ek := InputEventKey.new()
			ek.physical_keycode = k as Key
			InputMap.action_add_event(action, ek)
		for b: int in pair[2]:
			var eb := InputEventJoypadButton.new()
			eb.button_index = b as JoyButton
			InputMap.action_add_event(action, eb)
		if not (pair[3] as Array).is_empty():
			var em := InputEventJoypadMotion.new()
			em.axis = (pair[3] as Array)[0] as JoyAxis
			em.axis_value = (pair[3] as Array)[1]
			InputMap.action_add_event(action, em)


## Walk input, screen space, length at most 1 (stick tilt gives partial speed). Zero while a menu is open.
static func move_vector() -> Vector2:
	ensure()
	if menu_open:
		return Vector2.ZERO
	return Input.get_vector(&"plinky_left", &"plinky_right", &"plinky_up", &"plinky_down")


## Right-stick camera pan, length at most 1.
static func pan_vector() -> Vector2:
	ensure()
	if menu_open:
		return Vector2.ZERO
	return Input.get_vector(&"plinky_pan_left", &"plinky_pan_right", &"plinky_pan_up", &"plinky_pan_down")


## First visible, enabled, focusable control under root in tree order, or null.
static func first_focusable(root: Node) -> Control:
	if root is Control:
		var c: Control = root
		if not c.visible:
			return null
		if c.focus_mode == Control.FOCUS_ALL and not (c is BaseButton and (c as BaseButton).disabled):
			return c
	for child: Node in root.get_children():
		var found: Control = first_focusable(child)
		if found != null:
			return found
	return null
