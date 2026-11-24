class_name WorldCamera
extends Node
## Camera for the baked 2D world. Moves and scales the `world` Node2D (the HUD stays put).
## Follow: smooth chase of the walker. Zoom: mouse wheel or +/-, integer levels only, so every
## texel stays a whole number of screen texels (pixel snap at every zoom). Pan: hold right or
## middle mouse and drag, or push the mouse to a window edge. The pan drifts back to the walker
## after a short idle (sooner while the walker moves). Home (rebindable) snaps back at once. A jump lifts the view by
## two thirds of its height, eased; a hard landing thumps it; sprinting leans it further ahead.
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
const LIFT_FOLLOW: float = 0.65         # share of a jump's height the view rises with (a jump nudges it, never throws it)
const LIFT_RATE: float = 6.0            # ease rate of that rise
const SPRINT_LOOK: float = 0.9          # extra look-ahead per +1.0 of the walker's speed factor
const THUMP_TEXELS: float = 2.5         # a hard landing's downward kick, screen texels
const FOCUS_LIFT: Vector2 = Vector2(0.0, -6.0)   # aim at the walker's body, not its feet
const HUD_CLEAR: float = 6.0          # screen texels a landmark keeps below the HUD chip it must not hide under
const WALKER_EDGE: float = 36.0       # screen texels the walker keeps off the bottom edge when the view gives way to the HUD

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
var _lift: float = 0.0                   # eased height the view has risen with the walker's jump

## HUD control the view must keep landmarks clear of (the clock chip). Main sets it; null means no constraint.
var keep_clear: Control
## World rects the view must not hide under `keep_clear` (the zone gates' arches). Main sets them per zone.
var landmarks: Array[Rect2] = []


func _ready() -> void:
	if target != null:
		_center = _clamp_center(target.position + FOCUS_LIFT)
	_last_target = target.position if target != null else Vector2.ZERO
	# Looked up by path, not by the autoload identifier, so this script still compiles under tests/run.gd.
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null and not bus.is_connected(&"button_pressed", _on_pressed):
		bus.connect(&"button_pressed", _on_pressed)
	if target != null and target.has_signal(&"landed") and not target.is_connected(&"landed", land_thump):
		target.connect(&"landed", land_thump)
	_apply()


func _process(delta: float) -> void:
	if world == null:
		return
	var z: float = float(zoom_level)
	var lift_goal: float = 0.0
	if target != null and not calm and "lift" in target:
		lift_goal = float(target.get("lift")) * LIFT_FOLLOW
	_lift = lift_follow_step(_lift, lift_goal, delta)
	var manual: bool = _dragging
	var stick: Vector2 = PadInput.pan_vector()
	if stick != Vector2.ZERO:
		pan += stick * EDGE_SPEED / z * delta
		manual = true
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
	var goal: Vector2 = _framed(base + _look + _drift())
	_center = _center.lerp(goal, 1.0 - exp(-follow_rate(_speed_factor()) * delta))
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
	var want: Vector2 = look_ahead_goal(step, delta, moving, look_reach(_speed_factor()))
	_look = lean_step(_look, want, delta)
	_punch = _punch.lerp(Vector2.ZERO, 1.0 - exp(-PUNCH_DECAY * delta))
	_still = 0.0 if (moving or manual) else _still + delta


## The walker's eased speed factor (1 walking, higher sprinting or after a jump), 1 when the target has none.
func _speed_factor() -> float:
	if target != null and "speed_factor" in target:
		return float(target.get("speed_factor"))
	return 1.0


## Look-ahead reach for a speed factor: it leans further the faster the walker runs, so sprinting shows more road.
static func look_reach(factor: float) -> float:
	return LOOK_AHEAD * (1.0 + clampf(factor - 1.0, 0.0, 1.2) * SPRINT_LOOK)


## Follow rate for a speed factor: a touch tighter at speed so the walker never outruns the view.
static func follow_rate(factor: float) -> float:
	return FOLLOW_RATE * (1.0 + clampf(factor - 1.0, 0.0, 1.2) * 0.35)


## One eased step of the view's rise toward `goal` (a share of the walker's jump height). Exponential, no overshoot.
static func lift_follow_step(cur: float, goal: float, delta: float) -> float:
	return lerpf(cur, goal, 1.0 - exp(-LIFT_RATE * delta))


## A landing's downward thump, the same kick as a crit but scaled by how hard the walker came down.
func land_thump(impact: float) -> void:
	if calm:
		return
	_punch = Vector2(0.0, THUMP_TEXELS * clampf(impact, 0.0, 1.2) / 1.2)


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


## One eased step of the lean toward its goal. Exponential, so it never overshoots.
static func lean_step(cur: Vector2, want: Vector2, delta: float) -> Vector2:
	return cur.lerp(want, 1.0 - exp(-LOOK_RATE * delta))


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
	elif event.is_action_pressed(&"plinky_zoom_in") and not PadInput.menu_open:
		zoom_step(1, frame * 0.5)
	elif event.is_action_pressed(&"plinky_zoom_out") and not PadInput.menu_open:
		zoom_step(-1, frame * 0.5)
	elif (event.is_action_pressed(&"plinky_recenter") or Keybinds.matches(&"recenter", event)) and not PadInput.menu_open:
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


## Jumps straight to the walker (a zone change, where a chase across the map would show the whole trip).
func snap() -> void:
	pan = Vector2.ZERO
	if target != null:
		_center = _framed(target.position + FOCUS_LIFT)
	_apply()


func recenter() -> void:
	pan = Vector2.ZERO
	_idle = RETURN_DELAY


func _follow_point() -> Vector2:
	return (target.position + FOCUS_LIFT - Vector2(0.0, _lift)) if target != null else frame * 0.5


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


## A goal centre inside the bounds, aimed so no landmark hides under the HUD chip.
func _framed(c: Vector2) -> Vector2:
	var inside: Vector2 = _clamp_center(c)
	if keep_clear == null or landmarks.is_empty():
		return inside
	var walker_y: float = target.position.y if target != null else inside.y
	return _clamp_center(clear_hud_center(inside, zoom_level, frame, _chip_rect(), landmarks, walker_y))


## The HUD chip in frame texels (the same space as the centre and the landmarks), or an empty rect when it is not shown.
func _chip_rect() -> Rect2:
	if keep_clear == null or not keep_clear.is_visible_in_tree():
		return Rect2()
	var g: Rect2 = keep_clear.get_global_rect()
	return Rect2(g.position - frame_origin, g.size)


## Aim the view up just enough that no landmark sits under `chip` (frame texels). It only ever moves the view up,
## and never so far that the walker leaves the bottom of the view. Pure: depends on its arguments alone.
static func clear_hud_center(center: Vector2, level: int, view: Vector2, chip: Rect2, marks: Array[Rect2], walker_y: float) -> Vector2:
	if chip.size == Vector2.ZERO or marks.is_empty():
		return center
	var z: float = float(level)
	var c: Vector2 = center
	var shifted: bool = false
	for lm: Rect2 in marks:
		# where the landmark lands on screen for the centre as shifted so far: frame centre + (world - centre) * zoom
		var s: Rect2 = Rect2(view * 0.5 + (lm.position - c) * z, lm.size * z)
		var over_x: bool = s.position.x < chip.end.x and s.end.x > chip.position.x
		var over_y: bool = s.position.y < chip.end.y and s.end.y > chip.position.y
		if over_x and over_y:
			c.y -= (chip.end.y + HUD_CLEAR - s.position.y) / z
			shifted = true
	if shifted:
		# the lowest centre that keeps the walker inside the bottom edge; the walker outranks the arch
		c.y = maxf(c.y, walker_y - (view.y * 0.5 - WALKER_EDGE) / z)
	return c


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
	RenderGlobals.set_world(world.position, float(zoom_level))
