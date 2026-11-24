class_name TexelWalker
extends Node2D
## The walker in the 2D meadow (texel space, 640x360). WASD/arrows or click to move, Shift sprints, Ctrl locks the
## sprint, Space jumps, C crouches (or slides while sprinting). Movement state lives in WalkerMotion, drawing in WalkerBody.
## Pads and gates read `position`; a jump only changes `lift`, so the ground position (and the cast shadow) stay put.

## Feel values, texels per second. Vertical is halved to match the 2:1 isometric ground.
const SPEED: float = 70.0
const BOUNDS: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)   # outer clamp only; WalkMask decides where feet may go
static var bounds: Rect2 = BOUNDS                     # the current zone's world rect (main sets it on zone entry)

var palette: PackedColorArray = Palettes.colors(Palettes.MEADOW)
var moving: bool = false
## Height above the ground in texels (a jump). The cast shadow and the camera read it; `position` stays on the ground.
var lift: float = 0.0
## The eased movement multiplier from WalkerMotion (1 walking, about 1.55 sprinting, more after a jump). The camera reads it.
var speed_factor: float = 1.0
var motion: WalkerMotion = WalkerMotion.new()
var _target: Vector2 = Vector2.ZERO
var _has_target: bool = false
var _t: float = 0.0
var _gait: float = 0.0
var _body: WalkerBody
var _face: StringName = &"front"   # front, side, back
var _air_face: StringName = &"front"
var _flip: bool = false
var _lean: float = 0.0
var _squash_left: float = 0.0
var _step_clock: float = 0.0
var _slide_dir: Vector2 = Vector2.ZERO
var _last_dir: Vector2 = Vector2.ZERO
var _dust_clock: float = 0.0
const STEP_INTERVAL: float = 0.25   # seconds between footfalls while walking
const SURROUND_INTERVAL: float = 0.1   # how often shore and tree distance are re-read for the ambience
var _surround_clock: float = 0.0

## Fired on touchdown. impact is 0 (a hop) to 1.5 (a long fall). The camera thumps on it.
signal landed(impact: float)

const SQUASH_TIME: float = 0.18
const LEAN_SPRINT: float = 3.0      # texels the head leans into a sprint
const LEAN_WALK: float = 1.0


func _ready() -> void:
	add_to_group(&"walker")
	PadInput.ensure()
	_body = WalkerBody.new()
	_body.name = "Body"
	add_child(_body)
	_body.colors = palette
	add_child(WalkerRelics.new())   # equipped relics: motes, pool and sparks (world/walker_relics.gd)


## True while the walker is off the ground. Pads only count a walker that is standing on them.
var airborne: bool:
	get:
		return not motion.grounded


## 0 not sprinting, 1 Shift held, 2 locked with Ctrl. The Momentum label shows it.
func sprint_state() -> int:
	return motion.sprint_state()


## Cancels a click-to-walk target (used when the zone scene changes).
func stop() -> void:
	_has_target = false


## Brief squash frame, called by main when the walker's pad fires.
func squash() -> void:
	_squash_left = SQUASH_TIME


func _typing() -> bool:
	var f: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	return f is LineEdit or f is TextEdit


func _key_down(action: StringName) -> bool:
	return Keybinds.held(action)


func _process(delta: float) -> void:
	_t += delta
	var blocked: bool = PadInput.menu_open or _typing()
	var input: Vector2 = PadInput.move_vector()   # WASD, arrows, d-pad or left stick; analog tilt scales speed
	var dir := Vector2.ZERO
	if input != Vector2.ZERO:
		_has_target = false
		dir = input
	elif _has_target:
		var to: Vector2 = _target - position
		if to.length() < 1.0:
			_has_target = false
		else:
			dir = to.normalized()
	if motion.sliding() and _slide_dir != Vector2.ZERO:
		dir = _slide_dir   # a slide commits to its direction
		_has_target = false
	motion.cfg = GameState.sim.config
	motion.tick(delta, dir != Vector2.ZERO,
		not blocked and _key_down(&"sprint"),
		not blocked and _key_down(&"crouch"),
		not blocked and (_key_down(&"jump") or Input.is_action_pressed(&"plinky_jump")))
	speed_factor = motion.speed_factor
	lift = motion.z
	if motion.just_slid:
		_slide_dir = dir
		_kick_dust(3, dir)
	if motion.just_jumped:
		_kick_dust(2, Vector2.ZERO)
		Audio.footstep(MeadowSites.surface_at(position), 1.0)   # the push-off
		_air_face = _face if dir != Vector2.ZERO else &"front"
	if motion.just_landed:
		_kick_dust(2 + int(motion.land_impact * 2.0), Vector2.ZERO)
		Audio.footstep(MeadowSites.surface_at(position), clampf(motion.land_impact * 3.0, 0.0, 5.0))   # a hard landing thumps
		landed.emit(motion.land_impact)
	moving = dir != Vector2.ZERO
	if moving:
		var speed: float = SPEED * GameState.sim.walk_speed_mult() * motion.speed_mult()
		var step := Vector2(dir.x, dir.y * 0.5) * speed * delta
		if _has_target:
			step = step.limit_length((_target - position).length())
		var moved: bool = _try_step(step)
		if moved:
			GameState.sim.feed_momentum(step.length())
			_last_dir = dir
		if not moved and _has_target:
			_has_target = false   # click target was behind water, a cliff or a trunk: stop at the edge
		if not moved and motion.sliding():
			motion.slide_t = 0.0   # a slide ends at a wall
		moving = moved
	var quiet: bool = motion.sliding() or not motion.grounded or motion.crouching()
	if moving and not quiet:
		_step_clock += delta * motion.speed_factor
		if _step_clock >= STEP_INTERVAL:
			_step_clock = 0.0
			Audio.footstep(MeadowSites.surface_at(position), clampf((motion.speed_factor - 1.0) * 3.0, -1.0, 2.5))   # a sprint lands heavier
	else:
		_step_clock = STEP_INTERVAL * 0.5
	if moving:
		_gait += delta * (1.0 + (motion.speed_factor - 1.0) * 0.9)
		if absf(dir.x) >= absf(dir.y):
			_face = &"side"
			_flip = dir.x < 0.0
		else:
			_face = &"front" if dir.y > 0.0 else &"back"
			_flip = false
	if moving and motion.grounded and (motion.sprinting(true) or motion.sliding()):
		_dust_clock -= delta
		if _dust_clock <= 0.0:
			_dust_clock = 0.05 if motion.sliding() else 0.11
			_kick_dust(1, dir)
	_surround_clock -= delta
	if _surround_clock <= 0.0:
		_surround_clock = SURROUND_INTERVAL
		Audio.set_surroundings(MeadowSites.water_proximity(position), MeadowSites.tree_proximity(position))
	_animate(delta, dir)


## Dust behind the feet, thrown opposite the way the walker runs.
func _kick_dust(n: int, dir: Vector2) -> void:
	var back: Vector2 = Vector2(-dir.x, -dir.y * 0.5).normalized() if dir != Vector2.ZERO else Vector2.ZERO
	for i: int in n:
		var jitter := Vector2(randf_range(-4.0, 4.0), randf_range(-1.0, 1.0))
		_body.puff(position + jitter + back * 3.0, back * randf_range(8.0, 20.0) + Vector2(randf_range(-6.0, 6.0), randf_range(-8.0, -2.0)))


## Move by step if the new spot is walkable, else slide along x or y. Returns whether the walker moved.
func _try_step(step: Vector2) -> bool:
	for s: Vector2 in [step, Vector2(step.x, 0.0), Vector2(0.0, step.y)]:
		if s == Vector2.ZERO:
			continue
		var q := Vector2(
			clampf(position.x + s.x, bounds.position.x, bounds.end.x),
			clampf(position.y + s.y, bounds.position.y, bounds.end.y))
		if WalkMask.walkable(q):
			position = q
			return true
	return false


## Cells (col, row) in the atlas: row 0 = front, side, back, blink; row 1 = side walk 1-4; row 2 = front walk 1-2,
## back walk 1-2; row 3 = press, crouch front, crouch side, slide; row 4 = jump rise and fall, front then side.
## The procedural part (squash, stretch, lean, hop height) is applied by WalkerBody on top of the chosen cell.
func _animate(delta: float, dir: Vector2) -> void:
	_squash_left = maxf(_squash_left - delta, 0.0)
	var m: WalkerMotion = motion
	var cell := Vector2i(0, 0)
	var flip: bool = false
	var sy: float = 1.0
	var sx: float = 1.0
	var face: StringName = _face if (moving or m.sliding()) else &"front"
	if not m.grounded:
		face = _air_face
		var k: float = clampf(absf(m.vz) / WalkerMotion.JUMP_V, 0.0, 1.2)
		sy = 1.0 + 0.14 * k
		sx = 1.0 - 0.08 * k
		if face == &"side":
			cell = Vector2i(2 if m.vz > 0.0 else 3, 4)
			flip = _flip
		elif face == &"back":
			cell = Vector2i(2, 0)
		else:
			cell = Vector2i(0 if m.vz > 0.0 else 1, 4)
	elif m.sliding():
		cell = Vector2i(3, 3)
		flip = _slide_dir.x < 0.0 if absf(_slide_dir.x) > 0.01 else _flip
	elif _squash_left > 0.0:
		cell = Vector2i(0, 3)
	elif m.crouch_amt > 0.5:
		if face == &"side":
			cell = Vector2i(2, 3)
			flip = _flip
		elif face == &"back":
			cell = Vector2i(2, 0)
			sy = 0.8
		else:
			cell = Vector2i(1, 3)
	else:
		sy = 1.0 - 0.3 * m.crouch_amt   # easing into and out of a crouch
		if not moving:
			var blink: bool = fmod(_t, 3.2) < 0.12
			cell = Vector2i(3, 0) if blink else Vector2i(0, 0)
			if fmod(_t, 2.6) < 0.3:
				sy = minf(sy, 0.96)   # a slow breath
		elif face == &"side":
			cell = Vector2i(int(_gait * 8.0) % 4, 1)
			flip = _flip
		elif face == &"front":
			cell = Vector2i(int(_gait * 6.0) % 2, 2)
		else:
			cell = Vector2i(2 + int(_gait * 6.0) % 2, 2)
		if m.land_t > 0.0:
			var u: float = m.land_t / WalkerMotion.LAND_TIME
			sy = minf(sy, 1.0 - 0.3 * minf(m.land_impact, 1.0) * u)
			sx = 1.0 + 0.16 * minf(m.land_impact, 1.0) * u
	var lean_goal: float = 0.0
	if dir != Vector2.ZERO and m.slide_t <= 0.0:
		var side_part: float = signf(dir.x) * clampf(absf(dir.x) * 1.5, 0.0, 1.0)
		lean_goal = side_part * (LEAN_SPRINT if m.speed_factor > 1.3 else LEAN_WALK)
	_lean = lerpf(_lean, lean_goal, 1.0 - exp(-12.0 * delta))
	_body.cell = cell
	_body.flip = flip
	_body.sy = sy
	_body.sx = sx
	_body.lean = _lean
	_body.lift = lift
	_body.colors = palette


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not PadInput.menu_open:
		if Keybinds.matches(&"sprint_lock", event):
			motion.toggle_sprint_lock()
			return
		if Keybinds.matches(&"jump", event) or event.is_action_pressed(&"plinky_jump"):
			motion.queue_jump()
			get_viewport().set_input_as_handled()
			return
	elif event.is_action_pressed(&"plinky_jump") and not PadInput.menu_open:
		motion.queue_jump()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = (get_parent() as Node2D).to_local(get_global_mouse_position())
		_target = WalkMask.nearest_inset(Vector2(clampf(p.x, bounds.position.x, bounds.end.x), clampf(p.y, bounds.position.y, bounds.end.y)))
		_has_target = true


static func _key(code: Key) -> bool:
	return Input.is_physical_key_pressed(code)
