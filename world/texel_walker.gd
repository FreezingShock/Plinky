class_name TexelWalker
extends Node2D
## The walker in the 2D meadow (texel space, 640x360). WASD/arrows or click to move.
## Pads and gates read `position`. Visuals are placeholder shapes until the walker sheet is imported.

## Feel values, texels per second. Vertical is halved to match the 2:1 isometric ground.
const SPEED: float = 70.0
const BOUNDS: Rect2 = Rect2(24.0, 96.0, 592.0, 240.0)

var palette: PackedColorArray = Palettes.colors(Palettes.MEADOW)
var moving: bool = false
var _target: Vector2 = Vector2.ZERO
var _has_target: bool = false
var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	var input := Vector2(
		float(_key(KEY_D) or _key(KEY_RIGHT)) - float(_key(KEY_A) or _key(KEY_LEFT)),
		float(_key(KEY_S) or _key(KEY_DOWN)) - float(_key(KEY_W) or _key(KEY_UP)))
	var dir := Vector2.ZERO
	if input != Vector2.ZERO:
		_has_target = false
		dir = input.normalized()
	elif _has_target:
		var to: Vector2 = _target - position
		if to.length() < 1.0:
			_has_target = false
		else:
			dir = to.normalized()
	moving = dir != Vector2.ZERO
	if moving:
		var speed: float = SPEED * GameState.sim.walk_speed_mult()
		var step := Vector2(dir.x, dir.y * 0.5) * speed * delta
		if _has_target:
			step = step.limit_length((_target - position).length())
		position = Vector2(
			clampf(position.x + step.x, BOUNDS.position.x, BOUNDS.end.x),
			clampf(position.y + step.y, BOUNDS.position.y, BOUNDS.end.y))
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = (get_parent() as Node2D).to_local(get_global_mouse_position())
		_target = Vector2(clampf(p.x, BOUNDS.position.x, BOUNDS.end.x), clampf(p.y, BOUNDS.position.y, BOUNDS.end.y))
		_has_target = true


func _draw() -> void:
	var bob: float = float(int(_t * 8.0) % 2) if moving else 0.0
	# shadow: a flat 2:1 diamond
	draw_colored_polygon(PackedVector2Array([Vector2(-5, 0), Vector2(0, -2), Vector2(5, 0), Vector2(0, 2)]), palette[1])
	draw_rect(Rect2(-3, -9 - bob, 6, 7), palette[7])   # body
	draw_rect(Rect2(-3, -9 - bob, 6, 2), palette[5])   # scarf
	draw_rect(Rect2(-2, -13 - bob, 4, 4), palette[7])   # head
	draw_rect(Rect2(-2, -12 - bob, 1, 1), palette[0])   # eye
	draw_rect(Rect2(1, -12 - bob, 1, 1), palette[0])


static func _key(code: Key) -> bool:
	return Input.is_physical_key_pressed(code)
