class_name GardenLayer
extends Node2D
## The flower gardens around each statistic's pads: hundreds of small animated flowers drawn by this one node, on top of the
## baked ground and under props, pads and the walker. Positions come from world/larkmoor_gardens.json (written by
## tools/art/gen_gardens.py), sprites from GardenArt. Each flower leans a texel in a wind wave (and away from the walker), stepped
## at the sway rate. Reduce Motion holds every flower upright and stops the redraws.

const WAVE_SPEED: float = 2.0          # radians per second the wind front travels
const WAVE_PER_TEXEL: float = 0.04     # radians per texel along x
const LEAN_AT: float = 0.5             # wave level that tips a flower one texel
const BEND_RADIUS: float = 14.0        # a flower this close to the walker leans away from it

## Group of the node the flowers bend away from (the walker). Empty = no bending.
var pusher_group: StringName = &""
var _push: Node2D
var _flowers: PackedInt32Array = PackedInt32Array()   # x, y, stat index, variant per flower, sorted by y
var _t: float = 0.0
var _step: int = -1
var _view: Rect2 = Rect2()   # the rect the last draw was culled to

## The season the flowers show (GardenArt.SEASON_*), and whether their heads are shut (night). Set by the scene each frame;
## a change redraws the field.
var season: int = GardenArt.SEASON_SUMMER:
	set(v):
		if v != season:
			season = v
			queue_redraw()
var closed: bool = false:
	set(v):
		if v != closed:
			closed = v
			queue_redraw()
## Dew on the open heads at dawn (GardenArt draws the drops).
var dew: bool = false:
	set(v):
		if v != dew:
			dew = v
			queue_redraw()


func setup(flowers: Array) -> void:
	_flowers.resize(flowers.size() * 4)
	for i in flowers.size():
		var f: Array = flowers[i] as Array
		for k in 4:
			_flowers[i * 4 + k] = int(f[k])
	queue_redraw()


func count() -> int:
	return _flowers.size() >> 2


func _process(delta: float) -> void:
	if _flowers.is_empty():
		return
	# the camera moved (a walk, a zoom, a jump to another zone): redraw so the flowers that came into view are drawn
	var view: Rect2 = GraphicsQuality.visible_local_rect(self)
	if view.has_area() and (view.position.distance_to(_view.position) > 16.0 or view.size.distance_to(_view.size) > 16.0):
		queue_redraw()
	if MeadowLife.reduce_motion:
		return
	_t += delta
	if pusher_group != &"" and (_push == null or not is_instance_valid(_push)):
		_push = get_tree().get_first_node_in_group(pusher_group) as Node2D
	var s: int = int(_t / GraphicsQuality.sway_step())
	if s != _step:
		_step = s
		queue_redraw()


## Lean of one flower this step: -1, 0 or +1. The walker pushes first; otherwise the wind wave decides.
static func lean(x: int, y: int, t: float, wind: float, pusher: Vector2) -> int:
	if pusher != Vector2.INF:
		var d := Vector2(float(x) - pusher.x, (float(y) - pusher.y) * 2.0)   # the ground is 2:1, so a texel down is two across
		if d.length() < BEND_RADIUS and absf(d.x) >= 1.0:
			return 1 if d.x > 0.0 else -1
	var phase: float = float(x) * WAVE_PER_TEXEL - t * WAVE_SPEED + float(y) * 0.013
	var w: float = (sin(phase) + 0.35 * sin(phase * 2.3 + 1.7)) * (0.7 + 0.9 * wind)
	if absf(w) < LEAN_AT:
		return 0
	return 1 if w > 0.0 else -1


func _draw() -> void:
	if _flowers.is_empty():
		return
	PerfStats.lap_begin()
	var moving: bool = not MeadowLife.reduce_motion
	var t: float = float(maxi(_step, 0)) * GraphicsQuality.sway_step()
	var pusher: Vector2 = _push.position if (_push != null and moving) else Vector2.INF
	var view: Rect2 = GraphicsQuality.visible_local_rect(self)
	_view = view
	view = view.grow(20.0)   # a tall flower's head shows above its foot, so cull a little wider than the view
	var culling: bool = view.has_area()
	# The flowers are sorted by y, so the ones in view are one run of rows: find the run, then check x only.
	var first: int = _first_row(view.position.y) if culling else 0
	var last: int = _first_row(view.end.y) if culling else count()
	var atlas: Texture2D = GardenArt.atlas()
	for i in range(first, last):
		var x: int = _flowers[i * 4]
		if culling and (x < view.position.x or x >= view.end.x):
			continue
		var stat_index: int = _flowers[i * 4 + 2]
		var variant: int = _flowers[i * 4 + 3]
		var y: int = _flowers[i * 4 + 1]
		var l: int = lean(x, y, t, MeadowLife.wind, pusher) if moving else 0
		var src: Rect2 = GardenArt.atlas_rect(GardenArt.frame_index(stat_index, variant, l, season, closed, dew))
		var w: int = int(src.size.x)
		var h: int = int(src.size.y)
		draw_texture_rect_region(atlas, Rect2(x - (w >> 1), y - h + 1 + GardenArt.foot_drop(variant), w, h), src)
	PerfStats.lap("garden draw")


## Index of the first flower whose y is at or below `y` (the flowers are sorted by y).
func _first_row(y: float) -> int:
	var lo: int = 0
	var hi: int = count()
	while lo < hi:
		var mid: int = (lo + hi) >> 1
		if float(_flowers[mid * 4 + 1]) < y:
			lo = mid + 1
		else:
			hi = mid
	return lo
