class_name BootProgressBar
extends Control
## Progress bar from the UI theme (docs/theme.md section 4): 6 texels tall, 1 texel ink outline.
## The fill is palette index 3 (bar_fill), index 4 (bar_full) when complete. The leading two
## columns are Bayer-dithered against the empty index 2 so the edge reads as pixel art.

const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
const BAR_HEIGHT: float = 6.0
const BAR_WIDTH: float = 240.0

var value: float = 0.0:
	set(v):
		value = clampf(v, 0.0, 1.0)
		queue_redraw()

var _pal: PackedColorArray


func _ready() -> void:
	custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pal = Palettes.colors(Palettes.MEADOW)


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(0.0, 0.0, w, h), _pal[0])
	draw_rect(Rect2(1.0, 1.0, w - 2.0, h - 2.0), _pal[2])
	var inner: float = w - 2.0
	var fill_w: float = floorf(inner * value)
	if fill_w < 1.0:
		return
	var col: Color = _pal[4] if value >= 1.0 else _pal[3]
	var solid_end: float = maxf(1.0, fill_w - 2.0)
	draw_rect(Rect2(1.0, 1.0, solid_end, h - 2.0), col)
	for x in range(int(solid_end), int(fill_w) + 1):
		for y in range(1, int(h) - 1):
			var threshold: float = (BAYER[(y % 4) * 4 + (x % 4)] + 0.5) / 16.0
			if threshold < 0.5:
				draw_rect(Rect2(float(x), float(y), 1.0, 1.0), col)
