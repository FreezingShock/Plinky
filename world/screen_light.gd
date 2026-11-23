class_name ScreenLight
extends Node2D
## World-anchored edge shade (the vignette). A multiply ColorRect over the whole 640x360 frame (or the wider bleed view),
## dithered in two steps toward the corners. It is a child of the main Control, above the world layers and
## below the HUD, so it never darkens the interface. SkyCycle adds it and keeps its strength in sync.

const SHADER: Shader = preload("res://render/shaders/vignette.gdshader")

var _rect: ColorRect
var _mat: ShaderMaterial
var _host: Control
## Kept for callers that set it; the shader now reads the camera transform from the world_origin / world_scale globals.
var world_ref: Node2D


func set_area(r: Rect2) -> void:
	if _mat == null:
		_pending_area = r
		return
	_mat.set_shader_parameter("area_center", r.get_center())
	_mat.set_shader_parameter("area_half", r.size * 0.5)


var _pending_area: Rect2 = Rect2()


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
	if _pending_area.size != Vector2.ZERO:
		set_area(_pending_area)


func _process(_delta: float) -> void:
	_fit()


func set_strength(s: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("strength", s)
	visible = s > 0.001 and not FxConfig.reduce_screen_fx


func _fit() -> void:
	if _host == null or not is_instance_valid(_host):
		_host = get_parent() as Control
	if _host != null and _rect.size != _host.size:
		_rect.position = Vector2.ZERO
		_rect.size = _host.size
