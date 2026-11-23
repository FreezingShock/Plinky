class_name Player
extends Node3D
## The walker. WASD/arrows (rotated to the isometric view) or click-to-move via move_to().
## Logic only: the mesh and animation belong to the render thread and hang under this node.

## Feel value, world units per second. Attribute levels scale it through GameState.
@export var base_speed: float = 4.0
## Camera yaw, so screen-up maps to the right world direction (SPEC section 4).
@export var iso_yaw_degrees: float = 45.0
@export var arrive_distance: float = 0.05

var moving: bool = false
var _target: Vector3 = Vector3.ZERO
var _has_target: bool = false


func _ready() -> void:
	add_to_group(&"player")


func move_to(world_pos: Vector3) -> void:
	_target = Vector3(world_pos.x, global_position.y, world_pos.z)
	_has_target = true


func _physics_process(delta: float) -> void:
	var input: Vector2 = PadInput.move_vector()
	var dir: Vector3 = Vector3.ZERO
	if input != Vector2.ZERO:
		_has_target = false  # keys cancel click-to-move
		dir = Basis(Vector3.UP, deg_to_rad(iso_yaw_degrees)) * Vector3(input.x, 0.0, input.y)
	elif _has_target:
		var to: Vector3 = _target - global_position
		if to.length() <= arrive_distance:
			_has_target = false
		else:
			dir = to.normalized()
	moving = dir != Vector3.ZERO
	if moving:
		var step: float = _speed() * delta
		if _has_target:
			step = minf(step, (_target - global_position).length())
		global_position += dir * step


func _speed() -> float:
	var gs: Node = get_node_or_null("/root/GameState")
	var mult: float = 1.0
	if gs != null and gs.get("sim") != null:
		mult = (gs.get("sim") as Sim).walk_speed_mult()
	return base_speed * mult


static func _key(code: Key) -> bool:
	return Input.is_physical_key_pressed(code)
