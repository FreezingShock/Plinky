class_name PipBar
extends Control
## A row of small level pips: filled up to the current level. The newest pip pops taller and lights up when a level
## is bought. Whole texels only. Maxed fills every pip in the good colour.

const GAP: int = 1
const MAX_WIDTH: int = 100

var cap: int = 1
var level: int = 0
var maxed: bool = false
var flash: float = 0.0   ## 1 at the buy, down to 0 in steps
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func pip_width() -> int:
	return 3 if cap * (3 + GAP) <= MAX_WIDTH else 2


func set_level(p_level: int, p_cap: int, p_maxed: bool) -> void:
	if p_level == level and p_cap == cap and p_maxed == maxed:
		return
	level = p_level
	cap = maxi(p_cap, 1)
	maxed = p_maxed
	custom_minimum_size = Vector2(float(cap * (pip_width() + GAP) - GAP), 7.0)
	queue_redraw()


## Light up the newest pip. Quantised to four steps so it reads as pixel art, not a fade.
func pop() -> void:
	if FxConfig.still() or FxConfig.reduce_flashing:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_flash, 1.0, 0.0, 0.45)


func _set_flash(v: float) -> void:
	flash = roundf(v * 4.0) / 4.0
	queue_redraw()


func _draw() -> void:
	var w: int = pip_width()
	var empty: Color = RelicStyle.edge.lerp(RelicStyle.ink, 0.3)   # readable on the dark panel (was 0.65)
	var full: Color = RelicStyle.good if maxed else RelicStyle.accent
	for i: int in cap:
		var x: float = float(i * (w + GAP))
		if i < level:
			var newest: bool = i == level - 1 and flash > 0.0
			var h: float = 5.0 + (2.0 if newest else 0.0)
			var c: Color = RelicStyle.text if newest else full
			draw_rect(Rect2(x, 6.0 - h + 1.0, float(w), h), c)
		else:
			draw_rect(Rect2(x, 2.0, float(w), 3.0), empty)
