class_name CounterTick
extends Label
## Rolling number counter. Set .target; display eases toward it in stepped
## updates, flashes paper on gain, and pulses on a size jump.

var target := 0.0:
	set(v):
		if v > target:
			_gain_pulse(v - target)
		target = v
var shown := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # body font is Spleen 6x12 from the theme
var _accum := 0.0

func _process(delta: float) -> void:
	_accum += delta
	if _accum < 1.0 / 30.0: # 30 Hz text updates, matches pixel feel
		return
	_accum = 0.0
	if absf(target - shown) < 0.5:
		shown = target
	else:
		shown = lerpf(shown, target, 1.0 - exp(-delta * 30.0 / FxConfig.COUNTER_TICK_TIME * 0.1))
	text = NumberFormat.short(shown)

func _gain_pulse(amount: float) -> void:
	pivot_offset = size / 2.0
	var big: bool = amount > maxf(shown * 0.25, 1.0)
	var t := create_tween()
	scale = Vector2.ONE * (1.25 if big else 1.08)
	modulate = Color("f6efd9") # palette 7
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate", Color.WHITE, 0.25)
