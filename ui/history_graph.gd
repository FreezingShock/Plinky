class_name HistoryGraph
extends Control
## Pixel bar graph of income over the session: one 2 px bar per sample on a log scale, ink panel, dotted guide lines,
## and an accent tick under each rebirth. Draws only; HistoryPanel feeds it RunStats.samples.

const BAR_W: int = 2
const BAR_GAP: int = 0
const HEIGHT: int = 72

var samples: PackedFloat32Array = PackedFloat32Array():
	set(v):
		samples = v
		queue_redraw()
var marks: Array[int] = []:
	set(v):
		marks = v
		queue_redraw()


func _init(width: float = 380.0) -> void:
	custom_minimum_size = Vector2(width, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Pure: bar heights in whole pixels (0 to `h`) for `values` on a scale from the lowest to the highest value, so a
## flat line still draws and a climb fills the box. Empty values give an empty list.
static func bar_heights(values: PackedFloat32Array, h: int) -> Array[int]:
	var out: Array[int] = []
	if values.is_empty():
		return out
	var lo: float = values[0]
	var hi: float = values[0]
	for v: float in values:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	lo = floorf(lo)
	hi = maxf(ceilf(hi), lo + 1.0)
	for v: float in values:
		out.append(clampi(int(roundf((v - lo) / (hi - lo) * float(h))), 1 if v > 0.0 else 0, h))
	return out


## Pure: how many bars fit in `width`.
static func capacity(width: int) -> int:
	return maxi(1, (width - 2) / (BAR_W + BAR_GAP))


func _draw() -> void:
	var w: int = int(size.x)
	var h: int = int(size.y)
	draw_rect(Rect2(0, 0, w, h), RelicStyle.ink)
	draw_rect(Rect2(0, 0, w, 1), RelicStyle.edge)
	draw_rect(Rect2(0, h - 1, w, 1), RelicStyle.edge)
	draw_rect(Rect2(0, 0, 1, h), RelicStyle.edge)
	draw_rect(Rect2(w - 1, 0, 1, h), RelicStyle.edge)
	for q in range(1, 4):   # dotted quarter lines
		var gy: int = h * q / 4
		for gx in range(2, w - 2, 4):
			draw_rect(Rect2(gx, gy, 1, 1), RelicStyle.dim.darkened(0.45))
	var cap: int = capacity(w)
	var shown: int = mini(samples.size(), cap)
	if shown == 0:
		return
	var first: int = samples.size() - shown
	var inner: int = h - 4
	var hs: Array[int] = bar_heights(samples.slice(first), inner)
	var x0: int = 1   # bars grow in from the left, so a young session is not a packed right edge
	for i in shown:
		var bx: int = x0 + i * (BAR_W + BAR_GAP)
		var bh: int = hs[i]
		if bh > 0:
			draw_rect(Rect2(bx, h - 2 - bh, BAR_W, bh), RelicStyle.good)
			draw_rect(Rect2(bx, h - 2 - bh, BAR_W, 1), RelicStyle.text)
	for m: int in marks:
		var mi: int = m - first
		if mi >= 0 and mi < shown:
			var mx: int = x0 + mi * (BAR_W + BAR_GAP)
			draw_rect(Rect2(mx, 1, 1, h - 2), RelicStyle.accent)
