class_name DitherBar
extends Control
## 6 texel tall progress bar: ink outline, Bayer-dithered empty track, solid fill with a lit top row.
## Set `value` (0..1). Colours follow the zone palette through RelicStyle.

const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

var value: float = 0.0:
	set(v):
		v = clampf(v, 0.0, 1.0)
		if v != value:
			value = v
			queue_redraw()


func _init(width: float = 120.0) -> void:
	custom_minimum_size = Vector2(width, 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w: int = int(size.x)
	draw_rect(Rect2(0, 0, w, 6), RelicStyle.ink)
	var track: Color = RelicStyle.ink.lerp(RelicStyle.edge, 0.45)
	for y in 4:
		for x in w - 2:
			if BAYER[((y + 1) % 4) * 4 + ((x + 1) % 4)] < 5:
				draw_rect(Rect2(x + 1, y + 1, 1, 1), track)
	var f: int = int(float(w - 2) * value)
	if f > 0:
		draw_rect(Rect2(1, 1, f, 4), RelicStyle.good)
		for x in range(0, f, 2):
			draw_rect(Rect2(1 + x, 1, 1, 1), RelicStyle.text)
		# dithered leading edge
		for y in 4:
			if f + 1 < w - 1 and BAYER[((y + 1) % 4) * 4 + ((f + 1) % 4)] < 8:
				draw_rect(Rect2(1 + f, 1 + y, 1, 1), RelicStyle.good)
