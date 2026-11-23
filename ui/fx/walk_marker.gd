class_name WalkMarker
extends CanvasLayer
## Click-to-walk feedback, drawn in screen space (crisp, never scaled by camera zoom):
##  - a pixel ring on the ground (2:1 iso ellipse) that shrinks onto the click point, then pulses,
##    with a dithered inner ring and a one-shot outgoing ripple;
##  - marching dots from the walker to the target, 2x2 near the target tapering to 1x1 near the walker;
##  - everything collapses when the walker arrives, a key takes over, or you click somewhere else.
## Colours are palette roles (ink / accent / light / text), so they follow the zone.
## Owns no walker code: it mirrors the walker's own click rule (TexelWalker.BOUNDS) and reads
## walker.position and walker.moving.
##
## Wire-up (main.gd, after the walker and world exist):
##   WalkMarker.attach(self, world, walker)

const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
const DOT_GAP := 6.0
const MARCH_SPEED := 22.0      # texels per second toward the target
const RING_REST := 8
const RING_START := 20
const SHRINK_TIME := 0.3
const COLLAPSE_TIME := 0.25
const RIPPLE_TIME := 0.35
const ARRIVE_DIST := 1.5

var walker: TexelWalker
var world: CanvasItem          # the zoomed/panned world; gives the world-to-screen transform
var _canvas: Node2D
var _target := Vector2.ZERO    # world (texel) space
var _active := false
var _t := 0.0                  # seconds since the click
var _end := -1.0               # >= 0 while collapsing after arrival

static func attach(parent: Node, world_node: CanvasItem, walker_node: TexelWalker) -> WalkMarker:
	var m := WalkMarker.new()
	m.layer = 4  # under popups (5), over the world
	m.world = world_node
	m.walker = walker_node
	parent.add_child(m)
	return m

func _ready() -> void:
	_canvas = Node2D.new()
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.draw.connect(_draw_fx)
	add_child(_canvas)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = world.get_local_mouse_position()  # world-local texels; the world node is scaled and panned by the camera
		# Same rule as TexelWalker: clamp to its bounds.
		_target = Vector2(
			clampf(p.x, TexelWalker.bounds.position.x, TexelWalker.bounds.end.x),
			clampf(p.y, TexelWalker.bounds.position.y, TexelWalker.bounds.end.y))
		_active = true
		_t = 0.0
		_end = -1.0

func _process(delta: float) -> void:
	if _active:
		_t += delta
		if _end < 0.0:
			var arrived := walker.position.distance_to(_target) < ARRIVE_DIST
			# A walker that is not moving after a short grace period means keys took over or it was blocked.
			if arrived or (_t > 0.15 and not walker.moving):
				_end = 0.0
		else:
			_end += delta
			if _end > COLLAPSE_TIME:
				_active = false
	_canvas.queue_redraw()

func _to_screen(p: Vector2) -> Vector2:
	return (world.get_global_transform_with_canvas() * p).round()

func _col(role: String) -> Color:
	return PlinkyPalette.role(PopupStack.zone, role)

func _draw_fx() -> void:
	if not _active:
		return
	var tgt: Vector2 = _to_screen(_target)
	var from: Vector2 = _to_screen(walker.position)
	if _end < 0.0:
		_draw_dots(from, tgt)
	_draw_rings(tgt)

func _draw_dots(from: Vector2, tgt: Vector2) -> void:
	var delta: Vector2 = tgt - from
	var length: float = delta.length()
	if length < 16.0:
		return
	var dir: Vector2 = delta / length
	var offset: float = fmod(_t * MARCH_SPEED, DOT_GAP)
	var ink: Color = _col("ink")
	var d: float = offset + 8.0   # start past the walker's feet
	while d < length - 7.0:
		var pt: Vector2 = (from + dir * d).round()
		var big: bool = (length - d) > 14.0
		var sz: Vector2 = Vector2(2, 2) if big else Vector2(1, 1)
		_canvas.draw_rect(Rect2(pt + Vector2(0, 1), sz), ink)
		_canvas.draw_rect(Rect2(pt, sz), _col("text") if big else _col("accent"))
		d += DOT_GAP

func _draw_rings(tgt: Vector2) -> void:
	var r: int
	if _end >= 0.0:
		r = maxi(0, roundi(RING_REST * (1.0 - _end / COLLAPSE_TIME)))
	elif _t < SHRINK_TIME:
		r = roundi(lerpf(RING_START, RING_REST, _t / SHRINK_TIME))
	else:
		r = RING_REST + (int(_t * 4.0) % 2)   # 2 steps per beat, no smooth pulse
	if r > 0:
		_ring(tgt + Vector2(0, 1), r, _col("ink"), 1.0)   # ink drop-edge
		_ring(tgt, r, _col("accent"), 1.0)
		if r > 4:
			_ring(tgt, r - 4, _col("text"), 0.55)          # dithered inner ring
	if _t < RIPPLE_TIME and _end < 0.0:
		var k: float = _t / RIPPLE_TIME
		_ring(tgt, roundi(lerpf(8.0, 30.0, k)), _col("good"), 0.3 * (1.0 - k) + 0.05)
	_canvas.draw_rect(Rect2(tgt + Vector2(-1, -1), Vector2(3, 3)), _col("ink"))
	_canvas.draw_rect(Rect2(tgt, Vector2(1, 1)), _col("accent"))

## 2:1 iso ellipse of single texels. `threshold` < 1 dithers it with the 4x4 Bayer matrix.
func _ring(c: Vector2, r: int, col: Color, threshold: float) -> void:
	var seen: Dictionary = {}
	var steps: int = maxi(r * 7, 16)
	for i in steps:
		var a: float = TAU * float(i) / float(steps)
		var p := Vector2(roundf(c.x + cos(a) * r), roundf(c.y + sin(a) * r * 0.5))
		if seen.has(p):
			continue
		seen[p] = true
		if threshold >= 1.0 or float(BAYER[(int(p.y) & 3) * 4 + (int(p.x) & 3)]) / 16.0 < threshold:
			_canvas.draw_rect(Rect2(p, Vector2.ONE), col)
