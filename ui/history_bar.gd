class_name HistoryBar
extends Control
## A thin share bar: ink outline, solid fill for `value` (0..1). Used for time per zone on the History screen.

var value: float = 0.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()
var fill: Color = Color(0, 0, 0, 0):
	set(c):
		fill = c
		queue_redraw()


func _init(width: float = 120.0) -> void:
	custom_minimum_size = Vector2(width, 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w: int = int(size.x)
	draw_rect(Rect2(0, 0, w, 6), RelicStyle.ink)
	draw_rect(Rect2(1, 1, w - 2, 4), RelicStyle.dim.darkened(0.55))
	var fw: int = int(float(w - 2) * value)
	if value > 0.0:
		fw = maxi(fw, 1)
	var c: Color = fill if fill.a > 0.0 else RelicStyle.good
	draw_rect(Rect2(1, 1, fw, 4), c)
	draw_rect(Rect2(1, 1, fw, 1), RelicStyle.text)
