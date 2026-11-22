class_name PixelButton
extends Button
## HUD button with hover / press / disabled states in texel steps.
## Hover: 1 texel lift + paper outline. Press: 1 texel sink + brief invert.

var _rest_y := 0.0
var _rest_set := false

func _ready() -> void:
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))
	button_down.connect(_press.bind(true))
	button_up.connect(_press.bind(false))

func _rest() -> float:
	if not _rest_set:
		_rest_y = position.y
		_rest_set = true
	return _rest_y

func _hover(on: bool) -> void:
	if disabled: return
	position.y = _rest() - (1.0 if on else 0.0)
	modulate = Color("f6efd9") if on else Color.WHITE

func _press(down: bool) -> void:
	if disabled: return
	position.y = _rest() + (1.0 if down else 0.0)
	if down and not FxConfig.reduce_flashing:
		# One-frame inverted flash, then back.
		modulate = Color(0.1, 0.1, 0.12)
		await get_tree().process_frame
		modulate = Color("f6efd9")
