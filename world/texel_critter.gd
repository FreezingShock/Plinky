class_name TexelCritter
extends Node2D
## The golden critter: a small sparkle that drifts near the pads for a few seconds. Click it for a payout.
## Timing and the payout are in Sim (critter_spawned, catch_critter); this node only shows it and takes the click.

const CLICK_RADIUS: float = 12.0
const DRIFT_X: float = 46.0
const DRIFT_Y: float = 22.0

var palette: PackedColorArray = Palettes.colors(Palettes.MEADOW)
## Pad positions in world texels. The critter appears near one of them.
var anchors: PackedVector2Array = PackedVector2Array()

var _home: Vector2 = Vector2.ZERO
var _t: float = 0.0


func _ready() -> void:
	visible = false
	var bus: Node = get_node("/root/EventBus")
	bus.critter_spawned.connect(_on_spawned)
	bus.critter_gone.connect(func() -> void: visible = false)


func _on_spawned() -> void:
	if anchors.is_empty():
		return
	var rng: RandomNumberGenerator = GameState.sim.rng
	_home = anchors[rng.randi() % anchors.size()] + Vector2(rng.randf_range(-30.0, 30.0), rng.randf_range(-24.0, 12.0))
	_t = rng.randf() * TAU
	position = _home
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	position = _home + Vector2(sin(_t * 0.9) * DRIFT_X, sin(_t * 1.8) * DRIFT_Y)
	queue_redraw()


func _draw() -> void:
	var left: float = GameState.sim.critter_left
	if left < 3.0 and int(left * 6.0) % 2 == 0:
		return  # blink while it is about to leave
	var pulse: bool = int(_t * 5.0) % 2 == 0
	var gold: Color = palette[4]
	var core: Color = palette[7] if pulse else palette[4]
	draw_rect(Rect2(-1.0, -4.0, 2.0, 8.0), gold)
	draw_rect(Rect2(-4.0, -1.0, 8.0, 2.0), gold)
	draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), core)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	if GuiGuard.covers(get_tree().root, event.position):
		return   # a click on any GUI does not catch a critter under it
	var m: Vector2 = (get_parent() as Node2D).get_local_mouse_position()
	if m.distance_to(position) <= CLICK_RADIUS and GameState.sim.catch_critter():
		get_viewport().set_input_as_handled()
