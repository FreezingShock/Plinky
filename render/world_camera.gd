class_name WorldCamera
extends Node
## Camera for the baked 2D world. Moves and scales the `world` Node2D (the HUD stays put).
## Follow: smooth chase of the walker. Zoom: mouse wheel or +/-, integer levels only, so every
## texel stays a whole number of screen texels (pixel snap at every zoom). Pan: hold right or
## middle mouse and drag, or push the mouse to a window edge. The pan drifts back to the walker
## after a short idle (sooner while the walker moves). C or Home snaps back at once.
## Polish layers, all off under Calm camera (WorldCamera.calm), all whole-texel at the end:
## look-ahead leans the view a few texels in the walk direction, a punch kicks it on a crit, and a slow
## drift sways it after a long stillness. None of them touch pan, so follow, zoom and pan behave as before.

signal zoom_changed(level: int)

## Set by the Access setting "Calm camera". True turns off look-ahead, punch and drift.
static var calm: bool = false

const VIEW: Vector2 = Vector2(640.0, 360.0)
const WORLD: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)
const ZOOM_LEVELS: Array[int] = [1, 2, 3, 4]
const FOLLOW_RATE: float = 8.0          # higher = tighter chase
const EDGE_ZONE: float = 10.0           # viewport texels
const EDGE_SPEED: float = 180.0         # world texels per second at zoom 1
const RETURN_DELAY: float = 1.2         # seconds idle before the pan drifts back
const RETURN_DELAY_MOVING: float = 0.4  # same, while the walker is walking
const RETURN_RATE: float = 3.0
const LOOK_AHEAD: float = 14.0          # world texels the view leans toward the walk direction
const LOOK_RATE: float = 2.2            # ease rate of the lean (slow, so it never snaps)
const PUNCH_TEXELS: float = 2.0         # peak kick of a crit, screen texels
const PUNCH_DECAY: float = 9.0
const DRIFT_DELAY: float = 6.0          # seconds of stillness before the drift starts
const DRIFT_FADE: float = 4.0           # seconds to fade it in
const DRIFT_AMPLITUDE: Vector2 = Vector2(4.0, 2.5)   # world texels
const DRIFT_PERIOD: Vector2 = Vector2(23.0, 31.0)    # seconds, two slow axes
const FOCUS_LIFT: Vector2 = Vector2(0.0, -6.0)   # aim at the walker's body, not its feet

var world: Node2D
var target: Node2D
var shake: ScreenShake
var zoom_level: int = 2
var pan: Vector2 = Vector2.ZERO          # offset from the walker, world texels
var auto_return: bool = true
var frame: Vector2 = VIEW                 # the visible view in Main texels (640x360, or the bleed size)
var frame_origin: Vector2 = Vector2.ZERO  # frame top-left in the window, to turn mouse positions into frame texels
var bounds: Rect2 = WORLD                 # the area the camera centre may move within (the bleed when it is in)

var _center: Vector2 = Vector2.ZERO
var _idle: float = 0.0
var _dragging: bool = false
var _look: Vector2 = Vector2.ZERO
var _punch: Vector2 = Vector2.ZERO
var _still: float = 0.0
var _clock: float = 0.0
var _last_target: Vector2 = Vector2.ZERO


func _ready() -> void:
	if target != null:
		_center = _clamp_center(target.position + FOCUS_LIFT)
	_last_target = target.position if target != null else Vector2.ZERO
	# Looked up by path, not by the autoload identifier, so this script still compiles under tests/run.gd.
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null and not bus.is_connected(&"button_pressed", _on_pressed):
		bus.connect(&"button_pressed", _on_pressed)
	_apply()


func _process(delta: float) -> void:
	if world == null:
		return
	var z: float = float(zoom_level)
	var manual: bool = _dragging
	if not _dragging and zoom_level > 1:
		var edge: Vector2 = _edge_push()
		if edge != Vector2.ZERO:
			pan += edge * EDGE_SPEED / z * delta
			manual = true
	if manual:
		_idle = 0.0
	else:
		_idle += delta
		var moving: bool = target != null and "moving" in target and bool(target.get("moving"))
		if auto_return and _idle > (RETURN_DELAY_MOVING if moving else RETURN_DELAY):
			pan = pan.lerp(Vector2.ZERO, 1.0 - exp(-RETURN_RATE * delta))
	var base: Vector2 = _clamp_center(_follow_point() + pan)
	pan = base - _follow_point()
	_update_polish(delta, manual)
	var goal: Vector2 = _clamp_center(base + _look + _drift())
	_center = _center.lerp(goal, 1.0 - exp(-FOLLOW_RATE * delta))
	_apply()


## Look-ahead lean, punch decay and stillness clock. Calm camera zeroes all of it.
func _update_polish(delta: float, manual: bool) -> void:
	_clock += delta
	var step: Vector2 = Vector2.ZERO
	if target != null:
		step = target.position - _last_target
		_last_target = target.position
	var moving: bool = target != null and "moving" in target and bool(target.get("moving"))
	if calm:
		_look = Vector2.ZERO
		_punch = Vector2.ZERO
		_still = 0.0
		return
	var want: Vector2 = look_ahead_goal(step, delta, moving, LOOK_AHEAD)
	_look = _look.lerp(want, 1.0 - exp(-LOOK_RATE * delta))
	_punch = _punch.lerp(Vector2.ZERO, 1.0 - exp(-PUNCH_DECAY * delta))
	_still = 0.0 if (moving or manual) else _still + delta


func _on_pressed(_id: StringName, _pos: Vector3, _gain: BigNum, crit: bool) -> void:
	if crit and not calm:
		_punch = Vector2(0.0, PUNCH_TEXELS)   # a downward thump, the same weight as the pad sinking


func _drift() -> Vector2:
	if calm:
		return Vector2.ZERO
	return drift_offset(_clock, clampf((_still - DRIFT_DELAY) / DRIFT_FADE, 0.0, 1.0))


## Lean target from the walker's last step: along its direction, full length once it moves at all.
static func look_ahead_goal(step: Vector2, delta: float, moving: bool, reach: float) -> Vector2:
	if not moving or delta <= 0.0 or step.length_squared() < 0.0001:
		return Vector2.ZERO
	return step.normalized() * reach


## Slow two-axis sway, `weight` 0..1 fades it in. Zero at weight 0.
static func drift_offset(clock: float, weight: float) -> Vector2:
	return Vector2(
		sin(TAU * clock / DRIFT_PERIOD.x) * DRIFT_AMPLITUDE.x,
		sin(TAU * clock / DRIFT_PERIOD.y + 1.3) * DRIFT_AMPLITUDE.y) * weight


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_step(1, get_viewport().get_mouse_position() - frame_origin)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_step(-1, get_viewport().get_mouse_position() - frame_origin)
	elif event is InputEventMouseMotion and _dragging:
		var mm: InputEventMouseMotion = event
		pan -= mm.relative / float(zoom_level)
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		var k: InputEventKey = event
		match k.keycode:
			KEY_EQUAL, KEY_KP_ADD, KEY_PAGEUP:
				zoom_step(1, frame * 0.5)
			KEY_MINUS, KEY_KP_SUBTRACT, KEY_PAGEDOWN:
				zoom_step(-1, frame * 0.5)
			KEY_HOME:
				recenter()
			_:
				if Keybinds.matches(&"recenter", event):
					recenter()


## Zoom one level in (+1) or out (-1), keeping the world point under `screen_pos` in place.
func zoom_step(dir: int, screen_pos: Vector2) -> void:
	var i: int = clampi(ZOOM_LEVELS.find(zoom_level) + dir, 0, ZOOM_LEVELS.size() - 1)
	var new_level: int = ZOOM_LEVELS[i]
	if new_level == zoom_level:
		return
	var anchor: Vector2 = _center + (screen_pos - frame * 0.5) / float(zoom_level)
	zoom_level = new_level
	_center = _clamp_center(anchor - (screen_pos - frame * 0.5) / float(zoom_level))
	pan = _center - _follow_point()
	_idle = 0.0
	zoom_changed.emit(zoom_level)
	_apply()


func recenter() -> void:
	pan = Vector2.ZERO
	_idle = RETURN_DELAY


func _follow_point() -> Vector2:
	return (target.position + FOCUS_LIFT) if target != null else frame * 0.5


## Keep the view inside `area`. When the view is as big as the area or bigger on an axis, centre on it.
static func clamp_center(center: Vector2, level: int, view: Vector2, area: Rect2) -> Vector2:
	var half: Vector2 = view / (2.0 * float(level))
	return Vector2(
		_clamp_axis(center.x, area.position.x, area.end.x, half.x),
		_clamp_axis(center.y, area.position.y, area.end.y, half.y))


static func _clamp_axis(v: float, lo: float, hi: float, half: float) -> float:
	if hi - lo <= 2.0 * half:
		return (lo + hi) * 0.5
	return clampf(v, lo + half, hi - half)


## World transform for a camera centre. Whole screen texels at every integer zoom level.
static func world_position(center: Vector2, level: int, view: Vector2) -> Vector2:
	return (view * 0.5 - center * float(level)).round()


func _clamp_center(c: Vector2) -> Vector2:
	return clamp_center(c, zoom_level, frame, bounds)


func _edge_push() -> Vector2:
	var vp: Viewport = get_viewport()
	var m: Vector2 = vp.get_mouse_position() - frame_origin
	if m.x < 0.0 or m.y < 0.0 or m.x > frame.x or m.y > frame.y:
		return Vector2.ZERO
	var out: Vector2 = Vector2.ZERO
	if m.x < EDGE_ZONE:
		out.x = -1.0
	elif m.x > frame.x - EDGE_ZONE:
		out.x = 1.0
	if m.y < EDGE_ZONE:
		out.y = -1.0
	elif m.y > frame.y - EDGE_ZONE:
		out.y = 1.0
	return out


func _apply() -> void:
	if world == null:
		return
	world.scale = Vector2(zoom_level, zoom_level)
	var offset: Vector2 = shake.offset if shake != null else Vector2.ZERO
	world.position = world_position(_clamp_center(_center), zoom_level, frame) + offset + _punch.round()
