class_name LifeGround
extends Node2D
## Ground layer of the zone 1 world life, drawn on top of the baked backdrop (MeadowScene child, after it).
## Grass tips flick up to two texels sideways in a wind wave that rolls across the field. The backdrop is
## never painted over: a tip that moves repaints its own vacated texel from the backdrop texture, and the
## tip is redrawn at its new texel. Stepped at 6 fps, no alpha, palette index 4 (light).
## The backdrop may sit at an offset (the 3D meadow's bleed), so texels are read through the sprite's position.

const STEP: float = 1.0 / 6.0
const WAVE_SPEED: float = 2.2          # radians per second the wind front travels
const WAVE_PER_TEXEL: float = 0.045    # radians per texel along x (about 140 texels per wave)
const LEAN_1_AT: float = 0.55          # wave level for a one-texel lean
const LEAN_2_AT: float = 0.85          # wave level for a two-texel lean

var backdrop: Texture2D
var origin: Vector2i = Vector2i.ZERO   # where the backdrop's texel (0, 0) sits in the 640x360 frame
var palette: PackedColorArray = Palettes.colors(Palettes.MEADOW)
## Group of the node the grass bends away from (the walker). Empty = no bending.
var pusher_group: StringName = &""
const BEND_RADIUS: float = 16.0
var _push: Node2D
var _tips: Array[Vector2i] = []
var _t: float = 0.0
var _step: int = -1


func setup(backdrop_sprite: Sprite2D, tips: Array) -> void:
	backdrop = backdrop_sprite.texture
	origin = Vector2i(roundi(backdrop_sprite.position.x), roundi(backdrop_sprite.position.y))
	_tips.clear()
	for p: Variant in tips:
		var a: Array = p as Array
		_tips.append(Vector2i(int(a[0]), int(a[1])))
	queue_redraw()


func _process(delta: float) -> void:
	if MeadowLife.reduce_motion:
		return
	_t += delta
	if pusher_group != &"" and (_push == null or not is_instance_valid(_push)):
		_push = get_tree().get_first_node_in_group(pusher_group) as Node2D
	var s: int = int(_t / STEP)
	if s != _step:
		_step = s
		queue_redraw()


## Lean away from the walker: 2 texels inside half the radius, 1 inside the radius, else 0 (wind rules).
## Tips beside the walker's feet (same column) stay upright.
static func bend(tip: Vector2i, pusher: Vector2) -> int:
	if pusher == Vector2.INF:
		return 0
	var d: Vector2 = Vector2(tip) - pusher
	d.y *= 2.0  # the ground is a 2:1 isometric plane, so one texel down is two across
	var dist: float = d.length()
	if dist > BEND_RADIUS or absf(d.x) < 1.0:
		return 0
	var mag: int = 2 if dist < BEND_RADIUS * 0.5 else 1
	return mag if d.x > 0.0 else -mag


## Lean of one tip this step, in texels: -2 .. +2.
func _lean(p: Vector2i, t: float) -> int:
	var b: int = bend(p, _push.position if _push != null else Vector2.INF)
	if b != 0:
		return b
	var phase: float = float(p.x) * WAVE_PER_TEXEL - t * WAVE_SPEED + float(p.y) * 0.011
	var w: float = sin(phase) + 0.35 * sin(phase * 2.3 + 1.7)
	w *= 0.7 + 0.9 * MeadowLife.wind   # a gust leans the grass further, a calm spell less (wind 0.2 is the old look)
	var mag: int = 2 if absf(w) > LEAN_2_AT else (1 if absf(w) > LEAN_1_AT else 0)
	return mag if w > 0.0 else -mag


func _draw() -> void:
	if backdrop == null or _tips.is_empty():
		return
	var tip_col: Color = palette[4]
	var t: float = float(maxi(_step, 0)) * STEP
	for p: Vector2i in _tips:
		var d: int = 0 if MeadowLife.reduce_motion else _lean(p, t)
		if d == 0:
			continue  # the backdrop already shows the tip in place
		# Repaint the vacated texel from the texel below it, then draw the tip at its new place.
		var src: Vector2i = p - origin
		draw_texture_rect_region(backdrop, Rect2(p.x, p.y, 1, 1), Rect2(src.x, src.y + 1, 1, 1))
		draw_rect(Rect2(p.x + d, p.y, 1, 1), tip_col)
