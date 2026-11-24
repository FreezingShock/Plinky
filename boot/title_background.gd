class_name TitleBackground
extends ColorRect
## The title and loading backdrop. title_background.gdshader draws the layers; this node runs the day clock (SkyModel
## over TitleMood), lerps the palette, sun or moon, stars and rays through the day, and feeds the mouse parallax.
## Skip moves the clock forward to the next time of day. Reduce Motion freezes the clock on golden hour and makes
## skips instant.
##
## The sun or moon can be grabbed. Press near it (anywhere within GRAB_RADIUS) and it glides onto the pointer along its
## arc: the pointer's x is the time of day (sun, sunrise on the left to sunset on the right) or night (moon). The pull is
## a spring, so the body lags and overshoots a little, lifts toward the pointer while held, and the sky follows it.
## Release flicks it with the drag's speed, then the natural cycle carries on from where it was dropped.

const SHADER: Shader = preload("res://boot/title_background.gdshader")
## Largest parallax shift of the nearest layer, in texels, at the screen edge.
const PARALLAX_TEXELS: float = 8.0
const EASE: float = 4.0
## A skip to the next time of day runs the sky forward over this many seconds.
const SEEK_SECONDS: float = 1.6
## How close the pointer must be to the body's centre (backdrop texels) to grab it. Generous, so "kinda near it" works.
const GRAB_RADIUS: float = 34.0
## The grab spring: stiffness and damping. 58 and 7.6 is a damping ratio of 0.5, so the body overshoots its target by
## about 16% of the distance once, then settles. Lively without bouncing around.
const GRAB_STIFFNESS: float = 58.0
const GRAB_DAMPING: float = 7.6
## Reduce Motion: the same pull, critically damped, so nothing overshoots.
const CALM_STIFFNESS: float = 34.0
## The lift toward the pointer while held, and how far above or below the arc the body may go (texels).
const LIFT_MAX: float = 36.0
const LIFT_STIFFNESS: float = 60.0
const LIFT_DAMPING: float = 6.0
## Release flick: the drag's speed in phase per second, capped, and how many seconds the flick takes to die away.
const FLING_LIMIT: float = 0.8
const FLING_DECAY: float = 0.45
## How much speed is kept when the body hits the end of its half of the arc (sunrise, sunset, moonrise, moonset).
const ARC_BOUNCE: float = 0.35

var parallax: Vector2 = Vector2.ZERO
## Session seconds on the day clock. The sky reads TitleMood.START_PHASE at 0.
var clock: float = 0.0
var sky: SkyModel = TitleMood.make_sky()
## False while a panel is over the backdrop, so the body does not react under it.
var drag_enabled: bool = true

var _mat: ShaderMaterial
var _time: float = 0.0
var _seek_from: float = 0.0
var _seek_to: float = 0.0
## Seconds into the current skip, or -1 when no skip is running.
var _seek_t: float = -1.0
var _mood: Dictionary = {}
## Grab state. _u is the body's phase along its own half of the arc (unwrapped, so it stays continuous while held).
var _grabbing: bool = false
var _grab_sun: bool = true
var _u: float = 0.0
var _u_vel: float = 0.0
## 0 resting on the arc, 1 held up toward the pointer (may ring slightly past either end).
var _lift: float = 0.0
var _lift_vel: float = 0.0
## How far the held body reaches toward the pointer's height, captured while held so the drop back is clean.
var _reach: float = 0.0
## Hover and hold highlight, eased 0..1.
var _focus: float = 0.0
## Clock speed left over from a release flick, in phase per second. Decays to nothing.
var _fling: float = 0.0
var _cursor_shape: int = Input.CURSOR_ARROW


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("canvas_texels", Vector2(640.0, 360.0))
	material = _mat
	if still():
		clock = TitleMood.seconds_for(sky, TitleMood.START_PHASE)
	_apply()


func _exit_tree() -> void:
	_set_cursor(Input.CURSOR_ARROW)


## True when motion is reduced: the clock holds, parallax stays put, skips are instant and the grab has no overshoot.
static func still() -> bool:
	return FxConfig.reduce_flashing or MeadowLife.reduce_motion


## Pure: mouse position in the title's rect -> target parallax in texels (-1..1 of PARALLAX_TEXELS on each axis,
## y damped). Clamped, so a cursor outside the window never flings the layers.
static func parallax_for(mouse: Vector2, rect_size: Vector2) -> Vector2:
	if rect_size.x <= 0.0 or rect_size.y <= 0.0:
		return Vector2.ZERO
	var n := Vector2(clampf(mouse.x / rect_size.x * 2.0 - 1.0, -1.0, 1.0), clampf(mouse.y / rect_size.y * 2.0 - 1.0, -1.0, 1.0))
	return Vector2(-n.x, -n.y * 0.4) * PARALLAX_TEXELS


## Pure: one step of a damped spring toward target. Returns Vector2(position, velocity). Semi-implicit Euler, so it stays
## stable at normal frame rates.
static func spring_step(x: float, v: float, target: float, stiffness: float, damping: float, dt: float) -> Vector2:
	var nv: float = v + (stiffness * (target - x) - damping * v) * dt
	return Vector2(x + nv * dt, nv)


func _process(delta: float) -> void:
	_time += delta
	_mat.set_shader_parameter("time", _time)
	if _grabbing and (not drag_enabled or not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		_end_grab()
	var cursor: Vector2 = _cursor_art()
	if _grabbing:
		_step_grab(delta, cursor)
	else:
		_step_free(delta)
	_step_lift(delta)
	# The art is centred in whatever the window shows, so the backdrop fills any aspect ratio.
	_mat.set_shader_parameter("canvas_texels", size)
	var want: Vector2 = Vector2.ZERO
	if not still():
		want = parallax_for(get_local_mouse_position(), size)
	parallax = parallax.lerp(want, clampf(EASE * delta, 0.0, 1.0))
	_mat.set_shader_parameter("parallax", parallax)
	var on_body: bool = drag_enabled and (_grabbing or _near_body(cursor))
	_focus = move_toward(_focus, 1.0 if on_body else 0.0, delta * 6.0)
	_set_cursor(Input.CURSOR_DRAG if _grabbing else (Input.CURSOR_POINTING_HAND if on_body else Input.CURSOR_ARROW))
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if not drag_enabled or _grabbing or not is_inside_tree():
		return
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT:
		return
	if not _near_body(_cursor_art()):
		return
	_begin_grab()
	get_viewport().set_input_as_handled()


## Panels over the backdrop turn the body off. Letting go of a held body ends the grab.
func set_drag_enabled(on: bool) -> void:
	drag_enabled = on
	if not on and _grabbing:
		_end_grab()


## True while the pointer holds the sun or moon.
func grabbing() -> bool:
	return _grabbing


## Push the current time of day into the shader.
func _apply() -> void:
	_mood = TitleMood.sample(phase())
	var sky_cols: PackedColorArray = _mood["sky"]
	for i in 8:
		_mat.set_shader_parameter("c%d" % i, sky_cols[i])
	var ground_cols: PackedColorArray = _mood["ground"]
	for i in 4:
		_mat.set_shader_parameter("g%d" % i, ground_cols[i])
	_mat.set_shader_parameter("body_xy", body_art())
	_mat.set_shader_parameter("focus", clampf(_focus + _lift * 0.5, 0.0, 1.5))
	_mat.set_shader_parameter("star_amt", TitleMood.stars(sky, clock))
	_mat.set_shader_parameter("rays", sky.rays(clock))
	_mat.set_shader_parameter("glow", sky.golden(clock))


## Where the sun or moon is drawn, in art texels: on its arc at the current time, lifted toward the pointer while held.
func body_art() -> Vector2:
	var base: Vector2 = TitleMood.arc_at(_u, _grab_sun) if _grabbing else TitleMood.arc_point(phase())
	var dy: float = _lift * _reach
	if not still():
		dy += sin(_time * 5.0) * 0.8 * _lift
	return base + Vector2(0.0, dy)


## Position in the day, 0..1.
func phase() -> float:
	return sky.phase(clock)


## Name of the time of day on screen, for the time chip.
func time_name() -> String:
	return str(_mood.get("name", ""))


## The whole time-of-day sample (sky, ground, tint, shade, name), for the screens built over the backdrop.
func mood() -> Dictionary:
	return _mood


## The mood's colour at one sky role (0 ink .. 7 paper), for the screens built over the backdrop.
func role(i: int) -> Color:
	var sky_cols: PackedColorArray = _mood.get("sky", PackedColorArray())
	return sky_cols[clampi(i, 0, 7)] if sky_cols.size() == 8 else Color.BLACK


## Move the clock so the sky reads phase p at once (used to open a screen at a chosen time of day).
func set_phase_now(p: float) -> void:
	if _grabbing:
		_end_grab()
	clock = TitleMood.seconds_for(sky, p)
	_seek_t = -1.0
	_fling = 0.0
	_apply()


## Run the sky forward to the next time of day on the chip. Instant under Reduce Motion.
func skip_to_next() -> void:
	if _seek_t >= 0.0 or _grabbing:
		return
	var ahead: float = fposmod(TitleMood.next_phase(phase()) - phase(), 1.0)
	var seconds: float = ahead * sky.day_seconds
	if still():
		clock += seconds
		_apply()
		return
	_seek_from = clock
	_seek_to = clock + seconds
	_seek_t = 0.0


## 0 shows the scene, 1 covers it with ink.
func set_dissolve(amount: float) -> void:
	_mat.set_shader_parameter("dissolve", clampf(amount, 0.0, 1.0))


## The pointer in art texels (the 640x360 art is centred in the canvas, so this is the pointer minus that offset).
func _cursor_art() -> Vector2:
	if not is_inside_tree():
		return Vector2.ZERO
	return get_local_mouse_position() - _art_origin()


## Where the 640x360 art sits in this canvas. Same rounding as the shader's art_origin, so the grab lines up with the art.
func _art_origin() -> Vector2:
	return ((size - Vector2(640.0, 360.0)) * 0.5).floor()


func _near_body(cursor: Vector2) -> bool:
	return cursor.distance_to(body_art()) <= GRAB_RADIUS


## Start holding the body. It is the sun by day and the moon by night, and it can only travel along its own half of the arc.
func _begin_grab() -> void:
	_seek_t = -1.0
	_fling = 0.0
	_grab_sun = SkyModel.sun_of(phase()) >= 0.0
	var lo: float = TitleMood.arc_start(_grab_sun)
	_u = lo + fposmod(phase() - lo, 1.0)
	_u_vel = 0.0
	_grabbing = true


func _end_grab() -> void:
	_grabbing = false
	# A quick flick keeps some of its speed and fades into the natural cycle. Reduce Motion drops it.
	_fling = 0.0 if still() else clampf(_u_vel, -FLING_LIMIT, FLING_LIMIT)
	_u_vel = 0.0


## While held, the body springs toward the time of day under the pointer and the clock follows the body.
func _step_grab(delta: float, cursor: Vector2) -> void:
	var dt: float = minf(delta, 1.0 / 20.0)    # a long frame must not blow the spring up
	var target: float = TitleMood.phase_for_x(cursor.x, _grab_sun)
	var calm: bool = still()
	var k: float = CALM_STIFFNESS if calm else GRAB_STIFFNESS
	var d: float = 2.0 * sqrt(k) if calm else GRAB_DAMPING
	var s: Vector2 = spring_step(_u, _u_vel, target, k, d, dt)
	_u = s.x
	_u_vel = s.y
	var lo: float = TitleMood.arc_start(_grab_sun)
	var hi: float = lo + 0.5
	if _u <= lo:
		_u = lo
		if _u_vel < 0.0:
			_u_vel = -_u_vel * ARC_BOUNCE
	elif _u >= hi:
		_u = hi
		if _u_vel > 0.0:
			_u_vel = -_u_vel * ARC_BOUNCE
	clock = TitleMood.seconds_for(sky, _u)
	var base: Vector2 = TitleMood.arc_at(_u, _grab_sun)
	_reach = clampf(cursor.y, base.y - LIFT_MAX, base.y + 6.0) - base.y


## The natural clock: it runs on, carrying any release flick, and a skip runs it forward.
func _step_free(delta: float) -> void:
	if _seek_t >= 0.0:
		_fling = 0.0
		_seek_t += delta
		var f: float = clampf(_seek_t / SEEK_SECONDS, 0.0, 1.0)
		f = f * f * (3.0 - 2.0 * f)
		clock = lerpf(_seek_from, _seek_to, f)
		if _seek_t >= SEEK_SECONDS:
			_seek_t = -1.0
	elif not still():
		clock += delta * (1.0 + _fling * sky.day_seconds)
		_fling *= exp(-delta / FLING_DECAY)


## The lift springs up while held and drops back onto the arc after release (a little bounce, so it lands rather than stops).
func _step_lift(delta: float) -> void:
	var dt: float = minf(delta, 1.0 / 20.0)
	var target: float = 1.0 if _grabbing else 0.0
	var k: float = LIFT_STIFFNESS
	var d: float = 2.0 * sqrt(k) if still() else LIFT_DAMPING
	var s: Vector2 = spring_step(_lift, _lift_vel, target, k, d, dt)
	_lift = clampf(s.x, -0.1, 1.1)
	_lift_vel = s.y


func _set_cursor(shape: int) -> void:
	if shape == _cursor_shape:
		return
	_cursor_shape = shape
	Input.set_default_cursor_shape(shape)
