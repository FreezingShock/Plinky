class_name ScreenLight
extends Node2D
## Frame-fixed light: the vignette. A multiply ColorRect over the whole 640x360 frame (or the wider bleed view),
## dithered in two steps toward the corners. It is a child of the main Control, above the world layers and
## below the HUD, so it never darkens the interface. SkyCycle adds it and keeps its strength in sync.

const SHADER: Shader = preload("res://render/shaders/vignette.gdshader")

var _rect: ColorRect
var _mat: ShaderMaterial
var _host: Control
## A node that sits at the world origin (SkyCycle). The vignette's dither is pinned to the world through its transform,
## so the dots scroll and scale with the ground instead of staying fixed to the screen.
var world_ref: Node2D


func _ready() -> void:
	z_index = 40   # above world layers (z 0..11), below the HUD (z 100) and ParticleBurst (z 90)
	_rect = ColorRect.new()
	_rect.name = "Vignette"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect.material = _mat
	add_child(_rect)
	_fit()


func _process(_delta: float) -> void:
	_fit()
	if world_ref != null and is_instance_valid(world_ref):
		var xf: Transform2D = world_ref.get_global_transform_with_canvas()
		var sc: float = maxf(xf.x.length(), 0.001)
		# snap to whole texels so the pattern steps with the camera and never shimmers
		_mat.set_shader_parameter("w_origin", Vector2(roundf(xf.origin.x), roundf(xf.origin.y)))
		_mat.set_shader_parameter("w_scale", sc)


func set_strength(s: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("strength", s)
	visible = s > 0.001


func _fit() -> void:
	if _host == null or not is_instance_valid(_host):
		_host = get_parent() as Control
	if _host != null and _rect.size != _host.size:
		_rect.position = Vector2.ZERO
		_rect.size = _host.size
