class_name FarmFences
extends Node2D
## Wobbly post-and-rail fences for the Larkmoor farm. One node holds every run, and each run is drawn in code from its
## polyline, so the lines stay organic without a sprite per post. The node sits at the origin of the y-sorted prop
## parent, so it draws behind the walker, the crops and the buildings, as flat ground should.

const RAIL: Color = Color("#c2784e")        # the meadow's earth tone
const RAIL_SHADE: Color = Color("#1f3b35")
const POST: Color = Color("#14161c")
const POST_HEIGHT: float = 6.0
const RAIL_HEIGHTS: Array[float] = [2.0, 5.0]

var _runs: Array[PackedVector2Array] = []


static func make(runs: Array) -> FarmFences:
	var f := FarmFences.new()
	for r: Variant in runs:
		var pts := PackedVector2Array()
		for p: Variant in r as Array:
			var a: Array = p as Array
			pts.append(Vector2(float(a[0]), float(a[1])))
		if pts.size() >= 2:
			f._runs.append(pts)
	return f


func _draw() -> void:
	for pts: PackedVector2Array in _runs:
		for h: float in RAIL_HEIGHTS:
			var rail := PackedVector2Array()
			for p: Vector2 in pts:
				rail.append(p + Vector2(0.0, -h))
			draw_polyline(rail, RAIL, 1.0)
			var shade := PackedVector2Array()
			for p: Vector2 in rail:
				shade.append(p + Vector2(0.0, 1.0))
			draw_polyline(shade, RAIL_SHADE, 1.0)
		for p: Vector2 in pts:
			var x: float = roundf(p.x)
			var y: float = roundf(p.y)
			draw_rect(Rect2(x - 0.5, y - POST_HEIGHT, 2.0, POST_HEIGHT), POST)
