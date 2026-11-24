class_name CozyAnimator
extends Node
## Steps the cozy sheets (wheat gust frames, the water wheel) and the swing seats once per life step, so they move on
## the same pixel clock as the rest of the life layer. Under Reduce Motion every sheet stays on its first frame and
## every swing hangs still. The frame and angle rules are static so tests can check them without a scene.

const SWING_PERIOD: float = 3.4      # seconds for one full swing
const SWING_AMP: float = 0.16        # radians at full wind (about 9 degrees); a calm day still moves a little
const SWING_CALM: float = 0.35       # share of the amplitude that is left at no wind

var _sheets: Array[Dictionary] = []  # {sprite, frames, frame_w, frame_h, phase, rate}
var _swings: Array[Dictionary] = []  # {sprite, phase}
var _t: float = 0.0
var _step: int = -1


## Frame index for a sheet at life step `step`. Phase shifts neighbouring sheets so a wave rolls across them.
static func frame_at(step: int, frames: int, phase: int, rate: float, still: bool) -> int:
	if still or frames <= 1:
		return 0
	return posmod(int(floorf(float(step) * rate)) + phase, frames)


## Swing angle in radians at time `tb` (seconds, already stepped) for a swing with `phase`.
static func swing_angle(tb: float, phase: float, wind: float, still: bool) -> float:
	if still:
		return 0.0
	var amp: float = SWING_AMP * lerpf(SWING_CALM, 1.0, clampf(wind, 0.0, 1.0))
	return amp * sin(tb * TAU / SWING_PERIOD + phase)


func add_sheet(sprite: Sprite2D, frames: int, frame_w: int, frame_h: int, phase: int, rate: float) -> void:
	_sheets.append({"sprite": sprite, "frames": frames, "frame_w": frame_w, "frame_h": frame_h,
		"phase": phase, "rate": rate})
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0.0, 0.0, float(frame_w), float(frame_h))


func add_swing(sprite: Node2D, phase: float) -> void:
	_swings.append({"sprite": sprite, "phase": phase})


func _process(delta: float) -> void:
	_t += delta
	var s: int = int(_t / GraphicsQuality.life_step())
	if s == _step:
		return
	_step = s
	var still: bool = MeadowLife.reduce_motion
	for sh: Dictionary in _sheets:
		var sp: Sprite2D = sh.sprite as Sprite2D
		if not is_instance_valid(sp):
			continue
		var f: int = frame_at(s, int(sh.frames), int(sh.phase), float(sh.rate), still)
		var fw: float = float(sh.frame_w)
		sp.region_rect = Rect2(float(f) * fw, 0.0, fw, float(sh.frame_h))
	var tb: float = float(s) * GraphicsQuality.life_step()
	for sw: Dictionary in _swings:
		var n: Node2D = sw.sprite as Node2D
		if not is_instance_valid(n):
			continue
		n.rotation = swing_angle(tb, float(sw.phase), MeadowLife.wind, still)
