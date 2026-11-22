class_name AsciiSlider
extends Control
## A volume-style slider drawn from texel blocks to match the HUD bars: a notched frame and a row of cells.
## Drag or click to set it. Left and right arrow keys step it when focused. Emits value_changed(value).

signal value_changed(value: float)

const CELL: int = 4          # texels per cell, including its 1 texel gap
const HEIGHT: int = 12

var min_value: float = 0.0
var max_value: float = 1.0
var step: float = 0.05
var value: float = 0.0:
	set(v):
		value = clampf(snappedf(v, step), min_value, max_value)
		queue_redraw()

var _dragging: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(140, HEIGHT)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	var w: float = floorf(size.x)
	var h: float = floorf(size.y)
	var edge: Color = RelicStyle.accent if (has_focus() or _dragging or is_hovered()) else RelicStyle.edge
	draw_rect(Rect2(0, 0, w, h), RelicStyle.ink)
	draw_rect(Rect2(2, 0, w - 4, 1), edge)
	draw_rect(Rect2(2, h - 1, w - 4, 1), edge)
	draw_rect(Rect2(0, 2, 1, h - 4), edge)
	draw_rect(Rect2(w - 1, 2, 1, h - 4), edge)
	draw_rect(Rect2(1, 1, 1, 1), edge)
	draw_rect(Rect2(w - 2, 1, 1, 1), edge)
	draw_rect(Rect2(1, h - 2, 1, 1), edge)
	draw_rect(Rect2(w - 2, h - 2, 1, 1), edge)
	var cells: int = maxi(1, int((w - 6.0) / CELL))
	var lit: int = roundi(_fraction() * float(cells))
	for i in cells:
		var c: Color = RelicStyle.good if i < lit else RelicStyle.ink.lerp(RelicStyle.edge, 0.35)
		draw_rect(Rect2(3 + i * CELL, 3, CELL - 1, h - 6), c)


func _fraction() -> float:
	return 0.0 if is_equal_approx(max_value, min_value) else (value - min_value) / (max_value - min_value)


func _set_from_x(x: float) -> void:
	var f: float = clampf((x - 3.0) / maxf(1.0, size.x - 6.0), 0.0, 1.0)
	var before: float = value
	value = min_value + f * (max_value - min_value)
	if not is_equal_approx(before, value):
		value_changed.emit(value)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_dragging = (event as InputEventMouseButton).pressed
		if _dragging:
			grab_focus()
			_set_from_x((event as InputEventMouseButton).position.x)
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_set_from_x((event as InputEventMouseMotion).position.x)
		accept_event()
	elif event is InputEventKey and (event as InputEventKey).pressed:
		var k: Key = (event as InputEventKey).keycode
		if k == KEY_LEFT or k == KEY_RIGHT:
			var before: float = value
			value = value + (step if k == KEY_RIGHT else -step)
			if not is_equal_approx(before, value):
				value_changed.emit(value)
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()
