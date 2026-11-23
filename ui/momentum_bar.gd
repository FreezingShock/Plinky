class_name MomentumBar
extends Control
## Momentum bar: ink frame, one colour per stage, tick pips at every stage threshold that light as they are passed,
## a pale decay ghost trailing behind the fill, a hold timer line under it, and a flash when a stage is crossed.
## Pure drawing. MomentumMeter feeds it numbers.

const H: int = 9
const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

var value: float = 0.0          ## fill, 0..1
var ghost: float = 0.0          ## trailing value, >= value
var tier: int = 0
var thresholds: PackedFloat32Array = PackedFloat32Array()
var tier_colors: Array[Color] = []
var hold: float = 0.0           ## 0..1, share of the hold window left
var flash: float = 0.0          ## 1 -> 0 after a stage is crossed
var pulse: bool = false         ## Surge shimmer


func _init(width: float = 128.0) -> void:
	custom_minimum_size = Vector2(width, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w: int = int(size.x)
	var inner: int = w - 2
	draw_rect(Rect2(0, 0, w, 7), RelicStyle.flash_ink(flash))
	var track: Color = RelicStyle.ink.lerp(RelicStyle.edge, 0.45)
	for y in 5:
		for x in inner:
			if BAYER[((y + 1) % 4) * 4 + ((x + 1) % 4)] < 5:
				draw_rect(Rect2(x + 1, y + 1, 1, 1), track)
	var fc: Color = tier_colors[clampi(tier, 0, tier_colors.size() - 1)] if not tier_colors.is_empty() else RelicStyle.good
	if pulse:
		fc = fc.lerp(RelicStyle.text, 0.5)
	var g: int = int(float(inner) * ghost)
	var f: int = int(float(inner) * value)
	# Ghost: the part that just drained, as a dithered band in the fill colour.
	for x in range(f, g):
		for y in 5:
			if BAYER[((y + 1) % 4) * 4 + ((x + 1) % 4)] < 7:
				draw_rect(Rect2(1 + x, 1 + y, 1, 1), fc.lerp(RelicStyle.ink, 0.45))
	if f > 0:
		draw_rect(Rect2(1, 1, f, 5), fc)
		for x in range(0, f, 2):
			draw_rect(Rect2(1 + x, 1, 1, 1), RelicStyle.text)
		draw_rect(Rect2(1, 5, f, 1), fc.lerp(RelicStyle.ink, 0.35))
	# Stage ticks: ink gaps over the bar; the end of a stage lights up once it is reached.
	for i in thresholds.size() - 1:
		var tx: int = 1 + int(float(inner) * thresholds[i])
		var reached: bool = value >= thresholds[i]
		draw_rect(Rect2(tx, 1, 1, 5), RelicStyle.ink)
		draw_rect(Rect2(tx, 7, 1, 2), RelicStyle.text if reached else RelicStyle.dim)
	# Hold timer: a thin line that shrinks while the bar is holding before it drains.
	var hw: int = int(float(inner) * hold)
	if hw > 0:
		draw_rect(Rect2(1, 8, hw, 1), RelicStyle.accent)
