class_name ListRow
extends Button
## A flat, one-line menu row: text in a palette colour, a dither wash on hover, a marching-dot ring on focus, and a
## small bar down the left edge when `marked` (the place you are in). Used by the zone menu.

var tint: Color = Color.WHITE:
	set(v):
		tint = v
		_colours()
## Pixel icon id (AreaIcons) drawn in the indent before the text.
var icon: String = ""
var marked: bool = false:
	set(v):
		if v != marked:
			marked = v
			queue_redraw()


func _init() -> void:
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_text = true
	add_theme_stylebox_override("normal", AsciiBox.make(AsciiBox.Kind.BUTTON, 6.0, 1.0))
	add_theme_stylebox_override("hover", AsciiBox.make(AsciiBox.Kind.HOVER, 6.0, 1.0))
	add_theme_stylebox_override("pressed", AsciiBox.make(AsciiBox.Kind.PRESSED, 6.0, 1.0))
	add_theme_stylebox_override("disabled", AsciiBox.make(AsciiBox.Kind.DISABLED, 6.0, 1.0))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_colours()


func _colours() -> void:
	for n in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		add_theme_color_override(n, tint)
	add_theme_color_override("font_pressed_color", RelicStyle.ink)
	add_theme_color_override("font_disabled_color", tint.lerp(RelicStyle.ink, 0.55))


func _draw() -> void:
	if marked:
		draw_rect(Rect2(1, 3, 2, maxf(size.y - 6.0, 2.0)), tint)
	if icon != "":
		AreaIcons.draw(self, icon, Vector2(7.0, floorf((size.y - AreaIcons.SIZE) * 0.5)), tint)
	if has_focus():
		PadInput.draw_focus_ring(self, Rect2(Vector2.ZERO, size).grow(1), tint)


func _process(_d: float) -> void:
	if has_focus():
		queue_redraw()
	if is_hovered() and not disabled:
		var ph: int = int(Time.get_ticks_msec() / 110)
		if ph != AsciiBox.phase:
			AsciiBox.phase = ph
			queue_redraw()
