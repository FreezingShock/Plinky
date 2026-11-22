class_name TexelPad
extends Node2D
## A pressable pad anchored on the baked meadow art. Standing on it presses at the player's press rate.
## The art already shows the pad; this adds the live ring, the cost label, and the press logic.

const HALF: Vector2 = Vector2(14.0, 7.0)  # pad half extents in texels (2:1 diamond)

var button_id: StringName
var walker: TexelWalker
var glow: PadGlow
var palette: PackedColorArray = Palettes.colors(Palettes.MEADOW)
var standing: bool = false
var affordable: bool = false
## True while the mouse is held down on this pad (hold-to-press). Read by main for Juice.
var holding: bool = false
var hold: HoldPress

var _timer: float = 0.0
var _label: Label
var _label_clock: float = 0.0


func _ready() -> void:
	hold = HoldPress.new()
	add_child(hold)
	hold.tick.connect(_press)
	hold.released.connect(func() -> void: holding = false)
	_label = Label.new()
	_label.theme_type_variation = &"CaptionLabel"
	_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(80, 10)
	_label.position = Vector2(-40, -26)
	add_child(_label)
	_refresh_label()


func _physics_process(delta: float) -> void:
	var sim: Sim = GameState.sim
	var d: Vector2 = walker.position - position
	var inside: bool = (d.x * d.x) / (HALF.x * HALF.x) + (d.y * d.y) / (HALF.y * HALF.y) <= 1.0
	if inside and not standing:
		_timer = 0.0  # first press is immediate on arrival
	standing = inside
	affordable = sim.can_afford(button_id)
	if inside:
		_timer -= delta
		if _timer <= 0.0:
			_press()
			_timer = sim.press_interval()
	_label_clock += delta
	if _label_clock >= 0.2:
		_label_clock = 0.0
		_refresh_label()
	queue_redraw()


func _press() -> void:
	GameState.try_press(button_id, Vector3(global_position.x, global_position.y, 0.0))


## Click a pad to press it; hold to repeat (HoldPress speeds up while held).
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		var d: Vector2 = to_local(get_global_mouse_position())
		var h: Vector2 = HALF * 1.3
		if (d.x * d.x) / (h.x * h.x) + (d.y * d.y) / (h.y * h.y) <= 1.0:
			holding = true
			hold.begin()
			_press()
			get_viewport().set_input_as_handled()
	elif holding:
		hold.end()


func _refresh_label() -> void:
	var sim: Sim = GameState.sim
	var b: ButtonDef = sim.button_defs.get(button_id) as ButtonDef
	if b == null:
		return
	_label.text = "%s > +%s" % [Formulas.button_cost(b).format(), sim.press_gain_preview(button_id).format()]
	_label.modulate = Color.WHITE if affordable else Color(1, 1, 1, 0.55)


func _diamond(scale: float) -> PackedVector2Array:
	var h: Vector2 = HALF * scale
	return PackedVector2Array([Vector2(-h.x, 0), Vector2(0, -h.y), Vector2(h.x, 0), Vector2(0, h.y), Vector2(-h.x, 0)])


func _draw() -> void:
	var col: Color = glow.pad_color(palette) if (glow != null and affordable) else palette[2]
	draw_polyline(_diamond(1.0), col, 1.0)
	if standing:
		draw_polyline(_diamond(0.6), palette[7], 1.0)
