class_name GrassBlades
extends Node2D
## Interactive grass for the zone 1 meadow. One shader quad covers the ground (world/grass_blades.gdshader): every
## blade is generated per texel from a hash, so there are no nodes per blade and nothing extra loads. The shader
## runs the wind wave and bends blades away from the walker, the same rules as LifeGround. It owns its material,
## so it sets the wind and pusher uniforms itself (presentation only; gameplay still emits signals).
## Stepped at the same rate as LifeGround, frozen by Reduce Motion (the blades stay, the wind goes still).

const SHADER: Shader = preload("res://world/grass_blades.gdshader")
const MAX_PADS: int = 8

var _mat: ShaderMaterial
var _origin: Vector2 = Vector2.ZERO
var _size: Vector2 = Vector2.ZERO
var _push: Node2D
var _t: float = 0.0
var pusher_group: StringName = &"walker"


## backdrop_sprite: the ground sprite (its texture size and position set the covered area).
## pads: pad sites in frame texels (keeps blades off the pad plates). palette: the zone palette.
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
	_mat.set_shader_parameter("ground_tex", tex)
	_mat.set_shader_parameter("ground_origin", _origin)
	_mat.set_shader_parameter("ground_size", _size)
	_mat.set_shader_parameter("pad_count", mini(pads.size(), MAX_PADS))
	if palette.size() > 4:
		_mat.set_shader_parameter("tip_col", palette[4])
		_mat.set_shader_parameter("base_col", palette[2])
	material = _mat
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
	_mat.set_shader_parameter("pusher", _push.position if _push != null else Vector2(-9999.0, -9999.0))


func _draw() -> void:
	if _mat == null:
		return
	draw_rect(Rect2(_origin, _size), Color.WHITE)
