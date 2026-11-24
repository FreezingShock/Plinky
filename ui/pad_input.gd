class_name PadInput
extends RefCounted
## One place for keyboard and gamepad input. Registers the plinky_* actions at runtime (no project.godot edit),
## reads the walk vector, and finds the first focusable control in a panel so menus work without a mouse.
## Menus use Godot's ui_* actions (arrows, d-pad, left stick, Enter/Space, pad A); pad B and Esc are plinky_back.

const DEADZONE: float = 0.3

## True while any menu is open. Only WASD walks then; arrows, d-pad and the stick drive menu focus instead.
static var menu_open: bool = false
## True while Settings waits for a key to rebind. Those keys belong to the rebind, so the walker ignores them.
static var key_capture: bool = false
static var _ready: bool = false


static func ensure() -> void:
	if _ready:
		return
	_ready = true
	# Keys for settings, relics, upgrades, recenter, jump and crouch are rebindable, so they live in Keybinds; only the pad lives here.
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
			[&"plinky_settings", [], [JOY_BUTTON_START], []],
			[&"plinky_relics", [], [JOY_BUTTON_Y], []],
			[&"plinky_upgrades", [], [JOY_BUTTON_X], []],
			[&"plinky_stats", [], [JOY_BUTTON_BACK], []],
			[&"plinky_attributes", [], [JOY_BUTTON_LEFT_STICK], []],
			[&"plinky_tab_prev", [], [JOY_BUTTON_LEFT_SHOULDER], []],
			[&"plinky_tab_next", [], [JOY_BUTTON_RIGHT_SHOULDER], []],
			[&"plinky_zoom_in", [KEY_EQUAL, KEY_KP_ADD, KEY_PAGEUP], [JOY_BUTTON_RIGHT_SHOULDER], []],
			[&"plinky_zoom_out", [KEY_MINUS, KEY_KP_SUBTRACT, KEY_PAGEDOWN], [JOY_BUTTON_LEFT_SHOULDER], []],
			[&"plinky_recenter", [KEY_HOME], [JOY_BUTTON_RIGHT_STICK], []],
			[&"plinky_jump", [], [JOY_BUTTON_A], []]]:
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


## Focus is dropped only on the frame a menu closes, so its pad focus ring does not linger on the HUD. Dropping it
## every frame cancelled mouse clicks: a Button takes focus on press, and losing focus before release eats the click.
static func should_release_focus(menu_just_closed: bool, has_focus_owner: bool) -> bool:
	return menu_just_closed and has_focus_owner


## Walk input, screen space, length at most 1 (stick tilt gives partial speed). While a menu is open only WASD
## walks, so the arrows, d-pad and stick keep moving menu focus (Godot's ui_* actions, which WASD is not part of).
static func move_vector() -> Vector2:
	ensure()
	if menu_open:
		return menu_walk_vector()
	return Input.get_vector(&"plinky_left", &"plinky_right", &"plinky_up", &"plinky_down")


## WASD as a walk vector, read from the physical keys like the plinky_* actions. Used while a menu is open.
static func menu_walk_vector() -> Vector2:
	return walk_from_keys(Input.is_physical_key_pressed(KEY_A), Input.is_physical_key_pressed(KEY_D),
			Input.is_physical_key_pressed(KEY_W), Input.is_physical_key_pressed(KEY_S))


## Four held keys to a walk vector: opposite keys cancel, a diagonal is scaled to length 1.
static func walk_from_keys(left: bool, right: bool, up: bool, down: bool) -> Vector2:
	return Vector2(int(right) - int(left), int(down) - int(up)).limit_length(1.0)


## Right-stick camera pan, length at most 1.
static func pan_vector() -> Vector2:
	ensure()
	if menu_open:
		return Vector2.ZERO
	return Input.get_vector(&"plinky_pan_left", &"plinky_pan_right", &"plinky_pan_up", &"plinky_pan_down")


## Marching-dots focus ring (1 texel dots every 2, stepping around the rect) for pad and keyboard focus.
static func draw_focus_ring(item: CanvasItem, r: Rect2, color: Color) -> void:
	var phase: int = int(Time.get_ticks_msec() / 120) % 2
	var x0: int = int(r.position.x)
	var y0: int = int(r.position.y)
	var x1: int = int(r.end.x) - 1
	var y1: int = int(r.end.y) - 1
	for x: int in range(x0, x1 + 1):
		if (x + phase) % 2 == 0:
			item.draw_rect(Rect2(x, y0, 1, 1), color)
			item.draw_rect(Rect2(x, y1, 1, 1), color)
	for y: int in range(y0 + 1, y1):
		if (y + phase) % 2 == 0:
			item.draw_rect(Rect2(x0, y, 1, 1), color)
			item.draw_rect(Rect2(x1, y, 1, 1), color)


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
