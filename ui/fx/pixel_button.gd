class_name PixelButton
extends Button
## HUD button with hover / press / disabled states in texel steps.
## Colours and borders come from the theme (ink fill, base border; hover accent; pressed accent fill).
## This script only adds the 1 texel sink on press (theme.md section 4). Hover is theme-only.

var _rest_y := 0.0
var _rest_set := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_theme_stylebox_override("normal", AsciiBox.make(AsciiBox.Kind.BUTTON, AsciiBox.BUTTON_PAD.x, AsciiBox.BUTTON_PAD.y))
	add_theme_stylebox_override("hover", AsciiBox.make(AsciiBox.Kind.HOVER, AsciiBox.BUTTON_PAD.x, AsciiBox.BUTTON_PAD.y))
	add_theme_stylebox_override("pressed", AsciiBox.make(AsciiBox.Kind.PRESSED, AsciiBox.BUTTON_PAD.x, AsciiBox.BUTTON_PAD.y))
	add_theme_stylebox_override("disabled", AsciiBox.make(AsciiBox.Kind.DISABLED, AsciiBox.BUTTON_PAD.x, AsciiBox.BUTTON_PAD.y))
	add_theme_color_override("font_disabled_color", RelicStyle.dim)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())   # focus ring is drawn in _draw (marching dots)
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
	pass # accent border and text come from the theme

func _press(down: bool) -> void:
	if disabled: return
	position.y = _rest() + (1.0 if down else 0.0)


func _draw() -> void:
	if has_focus():
		PadInput.draw_focus_ring(self, Rect2(Vector2.ZERO, size).grow(1), get_theme_color("font_hover_color"))


func _process(_d: float) -> void:
	if has_focus():
		queue_redraw()
	if is_hovered() and not disabled:
		var ph: int = int(Time.get_ticks_msec() / 110)
		if ph != AsciiBox.phase:
			AsciiBox.phase = ph
			queue_redraw()
