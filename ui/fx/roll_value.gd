class_name RollValue
extends Label
## Rolling stat counter. Call set_target() with the real BigNum; the shown number eases toward it in
## 30 Hz steps (pixel feel), flashes on a gain, and emits big_gain when a jump is large.
## Whole-number stats roll in whole numbers. The first value is shown at once, never rolled up from zero.

signal big_gain(amount: BigNum)

var target: BigNum = BigNum.zero()
var shown: BigNum = BigNum.zero()
var _primed: bool = false
var _whole: bool = false
var _accum: float = 0.0
var _flash: Tween
var _pop: Tween


## One ease step. Pure, so tests can run it without a scene.
static func step(from: BigNum, to: BigNum, dt: float) -> BigNum:
	var diff: BigNum = to.sub(from)
	if diff.is_zero():
		return to
	var ref: BigNum = to if not to.is_zero() else from
	if absf(diff.div(ref).to_float()) < FxConfig.ROLL_SNAP:
		return to
	var k: float = 1.0 - exp(-dt / FxConfig.ROLL_TIME)
	return from.add(diff.mul(BigNum.from_float(k)))


## Gain relative to the value before it. A gain onto zero counts as 1.
static func gain_ratio(before: BigNum, gain: BigNum) -> float:
	if before.is_zero():
		return 1.0
	return gain.div(before).to_float()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func set_target(v: BigNum) -> void:
	if not _primed:
		_primed = true
		target = v
		shown = v
		_whole = _is_whole(v)
		_show()
		return
	if v.gt(target):
		var gain: BigNum = v.sub(target)
		var ratio: float = gain_ratio(target, gain)
		_flash_gain(ratio >= FxConfig.BIG_GAIN_RATIO)
		if ratio >= FxConfig.BIG_GAIN_RATIO:
			big_gain.emit(gain)
	target = v
	_whole = _is_whole(v)


func _process(delta: float) -> void:
	_accum += delta
	if _accum < 1.0 / FxConfig.ROLL_HZ:
		return
	var dt: float = _accum
	_accum = 0.0
	if shown.eq(target):
		return
	shown = step(shown, target, dt)
	_show()


func _show() -> void:
	var d: BigNum = shown
	if _whole and d.e < 15:
		d = BigNum.from_float(floorf(d.to_float()))
	text = d.format()


func _is_whole(v: BigNum) -> bool:
	return v.e < 15 and v.to_float() == floorf(v.to_float())


func _flash_gain(big: bool) -> void:
	if FxConfig.reduce_flashing or not is_inside_tree():
		return
	if _flash != null and _flash.is_valid():
		_flash.kill()
	var hot: Color = RelicStyle.accent if big else RelicStyle.text
	modulate = Color(hot.r, hot.g, hot.b, modulate.a)
	_flash = create_tween()
	_flash.tween_property(self, "modulate", Color.WHITE, FxConfig.BIG_GAIN_FLASH if big else FxConfig.SMALL_GAIN_FLASH)
	if big:
		_punch()


## Scale punch with overshoot on a big gain. Held to a few fixed steps so the glyphs stay on whole pixels.
func _punch() -> void:
	if FxConfig.reduce_shake or not is_inside_tree():
		return
	if _pop != null and _pop.is_valid():
		_pop.kill()
	pivot_offset = size / 2.0
	_pop = create_tween()
	for i in FxConfig.PUNCH_STEPS.size():
		_pop.tween_callback(func() -> void: scale = Vector2.ONE * FxConfig.PUNCH_STEPS[i])
		_pop.tween_interval(FxConfig.PUNCH_STEP_TIME)
