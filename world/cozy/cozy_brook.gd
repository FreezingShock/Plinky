class_name CozyBrook
extends Node2D
## A brook drawn over the meadow floor: a band of water along each polyline, with a lighter ripple that runs
## downstream once per life step. It sits at the origin, so the y-sorted props draw over it. Under Reduce Motion the
## ripples stop; the water itself never moves.

const IDX_DEEP: int = 2
const IDX_BASE: int = 3
const IDX_LIGHT: int = 4
const RIPPLE_EVERY: int = 6          # points between ripples (points are two texels apart)

var palette: PackedColorArray = Palettes.colors(Palettes.MEADOW)
var _runs: Array[Dictionary] = []    # {points: PackedVector2Array, width: int}
var _t: float = 0.0
var _step: int = -1


static func make(brooks: Array) -> CozyBrook:
	var b := CozyBrook.new()
	for v: Variant in brooks:
		var d: Dictionary = v as Dictionary
		var pts := PackedVector2Array()
		for p: Variant in d.get("points", []) as Array:
			var a: Array = p as Array
			if a.size() == 2:
				pts.append(Vector2(float(a[0]), float(a[1])))
		if pts.size() >= 2:
			b._runs.append({"points": pts, "width": int(d.get("width", 3))})
	return b


func _process(delta: float) -> void:
	if MeadowLife.reduce_motion or _runs.is_empty():
		return
	_t += delta
	var s: int = int(_t / GraphicsQuality.life_step())
	if s != _step:
		_step = s
		queue_redraw()


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var flow: int = 0 if MeadowLife.reduce_motion else maxi(_step, 0)
	for run: Dictionary in _runs:
		var pts: PackedVector2Array = run.points as PackedVector2Array
		var w: int = int(run.width)
		var half: int = w / 2
		for i: int in pts.size():
			var p: Vector2 = pts[i]
			var phase: int = posmod(i + flow, RIPPLE_EVERY)
			var c: Color = palette[IDX_DEEP] if phase < RIPPLE_EVERY - 2 else palette[IDX_BASE]
			draw_rect(Rect2(roundf(p.x) - half, roundf(p.y) - half, w, w), c)
			if phase == 0:
				draw_rect(Rect2(roundf(p.x), roundf(p.y), 1, 1), palette[IDX_LIGHT])
