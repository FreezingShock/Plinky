class_name TexelWalker
extends Node2D
## The walker in the 2D meadow (texel space, 640x360). WASD/arrows or click to move.
## Pads and gates read `position`. Visuals are placeholder shapes until the walker sheet is imported.

## Feel values, texels per second. Vertical is halved to match the 2:1 isometric ground.
const SPEED: float = 70.0
const BOUNDS: Rect2 = Rect2(0.0, 0.0, 640.0, 360.0)   # outer clamp only; WalkMask decides where feet may go

var palette: PackedColorArray = Palettes.colors(Palettes.MEADOW)
var moving: bool = false
var _target: Vector2 = Vector2.ZERO
var _has_target: bool = false
var _t: float = 0.0
var _sprite: Sprite2D
var _face: StringName = &"front"   # front, side, back
var _flip: bool = false
var _squash_left: float = 0.0
var _step_clock: float = 0.0
const STEP_INTERVAL: float = 0.25   # seconds between footfalls while walking

const ATLAS: Texture2D = preload("res://assets/art/walker/walker_atlas.png")
const CELL: int = 64
## Feet sit 47 texels below the cell top, centred horizontally.
const FEET: Vector2 = Vector2(32.0, 47.0)
const SQUASH_TIME: float = 0.18


func _ready() -> void:
	add_to_group(&"walker")
	_sprite = Sprite2D.new()
	_sprite.texture = ATLAS
	_sprite.centered = false
	_sprite.offset = -FEET
	_sprite.region_enabled = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_show(0, 0)


## Brief squash frame, called by main when the walker's pad fires.
func squash() -> void:
	_squash_left = SQUASH_TIME


func _show(row: int, col: int) -> void:
	_sprite.region_rect = Rect2(col * CELL, row * CELL, CELL, CELL)
	_sprite.flip_h = _flip


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
		var moved: bool = _try_step(step)
		if moved:
			GameState.sim.feed_momentum(step.length())
		if not moved and _has_target:
			_has_target = false   # click target was behind water, a cliff or a trunk: stop at the edge
		moving = moved
	if moving:
		_step_clock += delta
		if _step_clock >= STEP_INTERVAL:
			_step_clock = 0.0
			Audio.footstep()
	else:
		_step_clock = STEP_INTERVAL * 0.5
	if moving:
		if absf(dir.x) >= absf(dir.y):
			_face = &"side"
			_flip = dir.x < 0.0
		else:
			_face = &"front" if dir.y > 0.0 else &"back"
			_flip = false
	_animate(delta)


## Move by step if the new spot is walkable, else slide along x or y. Returns whether the walker moved.
func _try_step(step: Vector2) -> bool:
	for s: Vector2 in [step, Vector2(step.x, 0.0), Vector2(0.0, step.y)]:
		if s == Vector2.ZERO:
			continue
		var q := Vector2(
			clampf(position.x + s.x, BOUNDS.position.x, BOUNDS.end.x),
			clampf(position.y + s.y, BOUNDS.position.y, BOUNDS.end.y))
		if WalkMask.walkable(q):
			position = q
			return true
	return false


## Cells (row, col) in the atlas: row 0 = front, side, back, blink; row 1 = side walk 1-4;
## row 2 = front walk 1-2, press squash.
func _animate(delta: float) -> void:
	_squash_left = maxf(_squash_left - delta, 0.0)
	if _squash_left > 0.0:
		_flip = false
		_show(2, 2)
	elif not moving:
		var blink: bool = fmod(_t, 3.2) < 0.12
		_flip = false
		if blink:
			_show(0, 3)
		else:
			_show(0, 0)
	elif _face == &"side":
		_show(1, int(_t * 8.0) % 4)
	elif _face == &"front":
		_show(2, int(_t * 6.0) % 2)
	else:
		_flip = int(_t * 6.0) % 2 == 1   # no back walk frames: alternate mirrored back view
		_show(0, 2)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = (get_parent() as Node2D).to_local(get_global_mouse_position())
		_target = WalkMask.nearest(Vector2(clampf(p.x, BOUNDS.position.x, BOUNDS.end.x), clampf(p.y, BOUNDS.position.y, BOUNDS.end.y)))
		_has_target = true


static func _key(code: Key) -> bool:
	return Input.is_physical_key_pressed(code)
