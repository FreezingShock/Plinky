class_name GrassBlades
extends Node2D
## Interactive grass for the zone 1 meadow and Larkmoor. The blades are one shader (world/grass_blades.gdshader):
## every blade is generated per texel from a hash, so there are no nodes per blade and nothing extra loads. The shader
## runs the wind wave and bends blades away from the nearest walker or critter, the same rules as LifeGround.
## It owns its material, so it sets the wind and pusher uniforms itself (presentation only; gameplay emits nothing new).
## Stepped at the same rate as LifeGround, frozen by Reduce Motion (the blades stay, the wind goes still).
##
## Two modes. Whole ground (the meadow): one quad over the whole ground. Chunked (Larkmoor): the blades draw only in the
## prop chunks that are loaded, one rect per chunk, all in this one node, so the node count does not grow.

const SHADER: Shader = preload("res://world/grass_blades.gdshader")
const MAX_PADS: int = 8
const MAX_PUSHERS: int = 6
const OFF_SCREEN: Vector2 = Vector2(-9999.0, -9999.0)

var _mat: ShaderMaterial
var _origin: Vector2 = Vector2.ZERO
var _size: Vector2 = Vector2.ZERO
var _rects: Array[Rect2] = []
var _chunk_rects: Dictionary = {}     # chunk key -> Rect2, chunked mode only
var _push: Node2D
var _t: float = 0.0
var pusher_group: StringName = &"walker"
## Extra pusher points each frame (rabbits and other critters), in the same frame texels as the walker. Empty = none.
var critter_source: Callable = Callable()


## backdrop_sprite: the ground sprite (its texture size and position set the covered area).
## pads: pad sites in frame texels (keeps blades off the pad plates, up to MAX_PADS). palette: the zone palette.
func setup(backdrop_sprite: Sprite2D, pads: Array, palette: PackedColorArray) -> void:
	var tex: Texture2D = backdrop_sprite.texture
	if tex == null:
		return
	_origin = backdrop_sprite.position
	_size = tex.get_size()
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	var pad_pts: PackedVector2Array = PackedVector2Array()
	for p: Variant in pads:
		if pad_pts.size() >= MAX_PADS:
			break
		var a: Array = p as Array
		pad_pts.append(Vector2(float(a[0]), float(a[1])))
	pad_pts.resize(MAX_PADS)
	_mat.set_shader_parameter("pads", pad_pts)
	_mat.set_shader_parameter("pad_count", mini(pads.size(), MAX_PADS))
	_mat.set_shader_parameter("ground_tex", tex)
	_mat.set_shader_parameter("ground_origin", _origin)
	_mat.set_shader_parameter("ground_size", _size)
	if palette.size() > 4:
		_mat.set_shader_parameter("tip_col", palette[4])
		_mat.set_shader_parameter("base_col", palette[2])
	material = _mat
	_rects = [Rect2(_origin, _size)]
	queue_redraw()


## Chunked mode: draw only the rects added with add_chunk. Call before the first chunk loads.
func use_chunks() -> void:
	_chunk_rects.clear()
	_rects.clear()
	queue_redraw()


## One loaded chunk: rect is in ground texels, the same space as the blades.
func add_chunk(key: Vector2i, rect: Rect2) -> void:
	_chunk_rects[key] = rect
	_rebuild_rects()


func remove_chunk(key: Vector2i) -> void:
	_chunk_rects.erase(key)
	_rebuild_rects()


func _rebuild_rects() -> void:
	_rects.clear()
	for r: Rect2 in _chunk_rects.values():
		_rects.append(r)
	queue_redraw()


func _process(delta: float) -> void:
	if _mat == null:
		return
	var still: bool = MeadowLife.reduce_motion
	if not still:
		_t += delta
	if _push == null or not is_instance_valid(_push):
		_push = get_tree().get_first_node_in_group(pusher_group) as Node2D
	var step: float = GraphicsQuality.sway_step()
	_mat.set_shader_parameter("t", 0.0 if still else floorf(_t / step) * step)
	_mat.set_shader_parameter("wind", 0.0 if still else MeadowLife.wind)
	var pts: PackedVector2Array = PackedVector2Array()
	if _push != null:
		pts.append(_push.position)
	if critter_source.is_valid():
		var extra: PackedVector2Array = critter_source.call() as PackedVector2Array
		for p: Vector2 in extra:
			if pts.size() >= MAX_PUSHERS:
				break
			pts.append(p)
	var count: int = pts.size()
	pts.resize(MAX_PUSHERS)
	for i: int in range(count, MAX_PUSHERS):
		pts[i] = OFF_SCREEN
	_mat.set_shader_parameter("pushers", pts)
	_mat.set_shader_parameter("pusher_count", count)


func _draw() -> void:
	if _mat == null:
		return
	for r: Rect2 in _rects:
		draw_rect(r, Color.WHITE)
