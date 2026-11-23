class_name WalkerMotion
extends RefCounted
## The walker's movement state: sprint, jump, crouch and slide. Pure logic, no nodes, so it runs under tests/run.gd.
## TexelWalker feeds it input each frame, then reads speed_mult(), lift and the pose flags back.
## Balance numbers (speed multipliers, slide length, jump boost) are in GameConfig; the constants below are feel.

const GRAVITY: float = 640.0          ## texels/s^2 going up
const FALL_GRAVITY: float = 900.0     ## heavier on the way down, so a hop is snappy
const JUMP_V: float = 150.0           ## texels/s, about 17 texels of height (peak = v^2 / 2g)
const SPRINT_JUMP: float = 1.12       ## a sprinting jump launches a little harder
const JUMP_CUT: float = 0.45          ## releasing jump early keeps this share of the rise
const JUMP_BUFFER: float = 0.12       ## a press this soon before landing still jumps
const COYOTE: float = 0.08            ## a jump this soon after leaving the ground still works
const ACCEL: float = 7.0              ## ease rate of the speed factor while moving
const BRAKE: float = 14.0             ## ease rate back to 1 when stopped
const SLIDE_MIN: float = 1.25         ## speed factor needed to start a slide
const SLIDE_COOLDOWN: float = 0.45
const CROUCH_EASE: float = 16.0
const LAND_TIME: float = 0.16         ## squash recovery after landing

var cfg: GameConfig = GameConfig.new()
var sprint_locked: bool = false       ## Ctrl toggles
var z: float = 0.0                    ## height above the ground, texels
var vz: float = 0.0
var grounded: bool = true
var speed_factor: float = 1.0         ## eased movement multiplier, without the Attribute walk speed
var boost: float = 0.0                ## jump speed bonus, decays
var crouch_amt: float = 0.0           ## 0..1, eased
var slide_t: float = 0.0              ## seconds left in a slide
var land_t: float = 0.0               ## seconds of landing squash left
var land_impact: float = 0.0          ## 0..1.5, how hard the last landing was
var airtime: float = 0.0

## One-frame events, cleared at the start of each tick.
var just_jumped: bool = false
var just_landed: bool = false
var just_slid: bool = false

var _buffer: float = 0.0
var _coyote: float = 0.0
var _slide_cd: float = 0.0
var _was_crouch: bool = false
var _sprint_in: bool = false
var _cut_done: bool = false


func queue_jump() -> void:
	_buffer = JUMP_BUFFER


func toggle_sprint_lock() -> void:
	sprint_locked = not sprint_locked


func sliding() -> bool:
	return slide_t > 0.0


func crouching() -> bool:
	return grounded and crouch_amt > 0.5 and slide_t <= 0.0


## 0 not sprinting, 1 Shift held, 2 locked with Ctrl. This is what the HUD label shows.
func sprint_state() -> int:
	if sprint_locked:
		return 2
	return 1 if _sprint_in else 0


func sprinting(moving: bool) -> bool:
	return moving and grounded and slide_t <= 0.0 and crouch_amt < 0.5 and (sprint_locked or _sprint_in)


## Multiplier on the walk speed for this frame.
func speed_mult() -> float:
	return speed_factor


func tick(delta: float, moving: bool, sprint_held: bool, crouch_held: bool, jump_held: bool) -> void:
	just_jumped = false
	just_landed = false
	just_slid = false
	_sprint_in = sprint_held
	_buffer = maxf(_buffer - delta, 0.0)
	_slide_cd = maxf(_slide_cd - delta, 0.0)
	land_t = maxf(land_t - delta, 0.0)
	boost = maxf(boost - cfg.jump_boost_decay * delta, 0.0)
	_coyote = COYOTE if grounded else maxf(_coyote - delta, 0.0)
	# Crouch and slide (grounded only).
	var crouch_edge: bool = crouch_held and not _was_crouch
	_was_crouch = crouch_held
	if slide_t > 0.0:
		slide_t = maxf(slide_t - delta, 0.0)
		if not grounded:
			slide_t = 0.0
	elif grounded and crouch_edge and moving and _slide_cd <= 0.0 and speed_factor >= SLIDE_MIN:
		slide_t = cfg.slide_time
		_slide_cd = cfg.slide_time + SLIDE_COOLDOWN
		just_slid = true
	var want_crouch: bool = grounded and (crouch_held or slide_t > 0.0)
	crouch_amt = lerpf(crouch_amt, 1.0 if want_crouch else 0.0, 1.0 - exp(-CROUCH_EASE * delta))
	# Jump.
	if _buffer > 0.0 and (grounded or _coyote > 0.0):
		_launch()
	if not grounded:
		airtime += delta
		if not jump_held and vz > 0.0 and not _cut_done:
			vz *= JUMP_CUT
			_cut_done = true
		vz -= (GRAVITY if vz > 0.0 else FALL_GRAVITY) * delta
		z += vz * delta
		if z <= 0.0:
			land_impact = clampf(-vz / JUMP_V, 0.0, 1.5)
			z = 0.0
			vz = 0.0
			grounded = true
			land_t = LAND_TIME
			just_landed = true
			airtime = 0.0
			if _buffer > 0.0:
				_launch()   # bunny hop: pressing just before touchdown chains the next jump
	# Speed factor eases toward its target.
	var target: float = 1.0
	if slide_t > 0.0:
		var u: float = 1.0 - slide_t / maxf(cfg.slide_time, 0.001)
		target = lerpf(cfg.slide_mult_start, cfg.slide_mult_end, 1.0 - (1.0 - u) * (1.0 - u))
		speed_factor = target   # a slide is a burst, so it does not ease in
	elif not moving:
		speed_factor = lerpf(speed_factor, 1.0, 1.0 - exp(-BRAKE * delta))
	else:
		if grounded and crouch_amt > 0.5:
			target = cfg.crouch_mult
		elif sprint_locked or sprint_held:
			target = cfg.sprint_mult
		speed_factor = lerpf(speed_factor, target + boost, 1.0 - exp(-ACCEL * delta))


func _launch() -> void:
	var v: float = JUMP_V * (SPRINT_JUMP if (sprint_locked or _sprint_in) else 1.0)
	vz = v
	grounded = false
	_buffer = 0.0
	_coyote = 0.0
	_cut_done = false
	boost = minf(boost + cfg.jump_boost_per + (0.15 if slide_t > 0.0 else 0.0), cfg.jump_boost_max)
	slide_t = 0.0
	just_jumped = true


## HUD label for a sprint_state().
static func sprint_text(state: int) -> String:
	match state:
		1:
			return "SPRINTING HELD"
		2:
			return "SPRINTING ENABLED"
	return ""


## Cast-shadow size for a jump height: 1 on the ground, 0.55 from about 20 texels up.
static func shadow_scale(height: float) -> float:
	return 1.0 - 0.45 * clampf(height / 20.0, 0.0, 1.0)


## Peak height of a full jump, texels. For tests and the camera.
static func peak_height(v: float = JUMP_V) -> float:
	return v * v / (2.0 * GRAVITY)
