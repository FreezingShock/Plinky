class_name IndexRow
extends Button
## One line of the Stats or Attributes index: icon, name, value, note. Focusable, so keyboard and pad can walk
## the list; hover or focus shows its tooltip through the panel. Rows only display: they never change the Sim.

const H: int = 16

var data: Dictionary = {}
var _icon: TextureRect
var _name: Label
var _value: Label
var _note: Label


func _init(width: float) -> void:
	custom_minimum_size = Vector2(width, H)
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for s: String in ["hover", "pressed", "hover_pressed"]:
		add_theme_stylebox_override(s, AsciiBox.make(AsciiBox.Kind.HOVER, 2.0, 1.0))
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 3.0
	h.offset_right = -3.0
	h.add_theme_constant_override("separation", 5)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(h)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(16, 16)
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_icon)
	_name = _label(h, 84)
	_value = _label(h, 60)
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_note = _label(h, 0)
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note.clip_text = true


func _label(parent: Node, w: float) -> Label:
	var l := Label.new()
	l.custom_minimum_size.x = w
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func set_data(d: Dictionary) -> void:
	var first: bool = data.is_empty()
	data = d
	if first:
		var path: String = "res://assets/icons/%s.png" % String(d["icon"])
		if ResourceLoader.exists(path):
			_icon.texture = load(path) as Texture2D
	var pending: bool = bool(d.get("pending", false))
	_name.text = String(d["name"])
	_value.text = String(d["value"])
	_note.text = String(d["note"])
	_name.add_theme_color_override("font_color", RelicStyle.dim if pending else RelicStyle.text)
	_value.add_theme_color_override("font_color", RelicStyle.dim if pending else RelicStyle.good)
	_note.add_theme_color_override("font_color", RelicStyle.dim)
	_icon.modulate = Color(1, 1, 1, 0.5) if pending else Color.WHITE


func _draw() -> void:
	if has_focus():
		PadInput.draw_focus_ring(self, Rect2(Vector2.ZERO, size).grow(1), RelicStyle.accent)


func _process(_d: float) -> void:
	if has_focus():
		queue_redraw()
