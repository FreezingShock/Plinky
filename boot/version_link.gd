class_name VersionLink
extends Control
## The version number in the corner of the boot and title screens. Drawn in the bright text colour with an ink
## outline so it reads over any backdrop; hover or focus turns it to the accent colour and underlines it, and a
## click (or Enter) emits `pressed` so the screen can open the Update Log.

signal pressed

const FONT: FontFile = preload("res://fonts/spleen-6x12.fnt")
const MARGIN: float = 6.0
const FONT_SIZE: int = 12

var rest_color: Color = Color.WHITE
var accent_color: Color = Color.WHITE
var outline_color: Color = Color.BLACK
var text: String = BuildInfo.string()

var _hover: bool = false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	Tip.bind(self, "Open the Update Log")   # the shared instant tooltip, not Godot's delayed tooltip_text
	custom_minimum_size = text_size() + Vector2(8.0, 4.0)
	var ms: Vector2 = custom_minimum_size
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -ms.x - MARGIN
	offset_top = -ms.y - MARGIN
	offset_right = -MARGIN
	offset_bottom = -MARGIN
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func text_size() -> Vector2:
	return Vector2(ceilf(FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE).x), ceilf(FONT.get_height(FONT_SIZE)))


## Pure: hover or keyboard focus both read as "active".
static func is_active(hovered: bool, focused: bool) -> bool:
	return hovered or focused


func _set_hover(on: bool) -> void:
	_hover = on
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()
	elif event.is_action_pressed(&"ui_accept"):
		pressed.emit()
		accept_event()


func _draw() -> void:
	var active: bool = is_active(_hover, has_focus())
	var col: Color = accent_color if active else rest_color
	var ts: Vector2 = text_size()
	var at := Vector2(floorf((size.x - ts.x) * 0.5), floorf((size.y - ts.y) * 0.5) + FONT.get_ascent(FONT_SIZE))
	for o: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(1, 1)]:
		FONT.draw_string(get_canvas_item(), at + o, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, outline_color)
	FONT.draw_string(get_canvas_item(), at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, col)
	if active:
		var uy: float = at.y + 2.0
		draw_rect(Rect2(at.x - 1.0, uy, ts.x + 2.0, 3.0), outline_color)
		draw_rect(Rect2(at.x, uy + 1.0, ts.x, 1.0), col)
