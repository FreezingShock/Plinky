class_name FarmWheat
extends Node
## Parts the farm's wheat around the walker. Each field sprite has its own ShaderMaterial (farm_wheat.gdshader); this
## node feeds every one the walker's world position each frame. Under Reduce Motion the push is zero and the wheat only
## sways with the gust. The push is presentation only: it reads the walker and never changes gameplay.

const SHADER: String = "res://world/farm/farm_wheat.gdshader"
const PUSH_RADIUS: float = 22.0      # texels from the walker's feet where the wheat starts to lean
const PUSH_AMOUNT: float = 7.0       # texels of lean at the walker's feet, at the tips
const NOWHERE: Vector2 = Vector2(-99999.0, -99999.0)

var _mats: Array[ShaderMaterial] = []
var _walker: Node2D


## One material for one field, with its frame width and the push settings.
static func make_material(frame_w: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SHADER) as Shader
	m.set_shader_parameter("frame_w", float(frame_w))
	m.set_shader_parameter("push_radius", PUSH_RADIUS)
	m.set_shader_parameter("push_amount", push_for(false))
	m.set_shader_parameter("walker_world", NOWHERE)
	return m


## The lean at the walker's feet: none under Reduce Motion.
static func push_for(calm: bool) -> float:
	return 0.0 if calm else PUSH_AMOUNT


func add_material(m: ShaderMaterial) -> void:
	_mats.append(m)


func _process(_delta: float) -> void:
	if _walker == null or not is_instance_valid(_walker):
		_walker = get_tree().get_first_node_in_group(&"walker") as Node2D
	var at: Vector2 = _walker.global_position if _walker != null else NOWHERE
	var amount: float = push_for(MeadowLife.reduce_motion)
	for m: ShaderMaterial in _mats:
		m.set_shader_parameter("walker_world", at)
		m.set_shader_parameter("push_amount", amount)
