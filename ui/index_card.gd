class_name IndexCard
extends Button
## One gallery card: a 32 px icon, the name and the amount. Hover or focus lifts the icon two texels and tints the
## frame; the panel shows the full details in its info strip. Click opens the stat's detail page.

const W: int = 72
const H: int = 66
const LIFT: int = 2

var data: Dictionary = {}
var _icon: TextureRect
var _name: Label
var _value: Label
var _lifted: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_theme_stylebox_override("normal", AsciiBox.make(AsciiBox.Kind.BUTTON, 2.0, 2.0))
	add_theme_stylebox_override("hover", AsciiBox.make(AsciiBox.Kind.HOVER, 2.0, 2.0))
	add_theme_stylebox_override("pressed", AsciiBox.make(AsciiBox.Kind.PRESSED, 2.0, 2.0))
	add_theme_stylebox_override("hover_pressed", AsciiBox.make(AsciiBox.Kind.PRESSED, 2.0, 2.0))
	add_theme_stylebox_override("focus", AsciiBox.make(AsciiBox.Kind.HOVER, 2.0, 2.0))
	_icon = TextureRect.new()
	_icon.position = Vector2((W - 32) / 2, 5)
	_icon.custom_minimum_size = Vector2(32, 32)
	_icon.size = Vector2(32, 32)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_name = _label(38)
	_value = _label(50)
	_value.add_theme_color_override("font_color", RelicStyle.good)
	mouse_entered.connect(_sync_lift)
	mouse_exited.connect(_sync_lift)
	focus_entered.connect(_sync_lift)
	focus_exited.connect(_sync_lift)


func _label(y: float) -> Label:
	var l := Label.new()
	l.position = Vector2(2, y)
	l.custom_minimum_size.x = W - 4
	l.size = Vector2(W - 4, 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func set_data(d: Dictionary) -> void:
	var first: bool = data.is_empty()
	data = d
	if first:
		_icon.texture = icon_for(String(d["icon"]))
	var pending: bool = bool(d.get("pending", false))
	_name.text = String(d["name"])
	_value.text = String(d["value"])
	_name.add_theme_color_override("font_color", RelicStyle.dim if pending else RelicStyle.text)
	_value.add_theme_color_override("font_color", RelicStyle.dim if pending else RelicStyle.good)
	_icon.modulate = Color(1, 1, 1, 0.5) if pending else Color.WHITE


## The 32 px icon when there is one, else the 16 px icon (shown at 2x, still crisp).
static func icon_for(icon: String) -> Texture2D:
	var big: String = "res://assets/icons/big/%s.png" % icon
	if ResourceLoader.exists(big):
		return load(big) as Texture2D
	var small: String = "res://assets/icons/%s.png" % icon
	return load(small) as Texture2D if ResourceLoader.exists(small) else null


func _sync_lift() -> void:
	var want: bool = is_hovered() or has_focus()
	if want == _lifted:
		return
	_lifted = want
	_icon.position.y = 5.0 - (LIFT if want else 0)


func _draw() -> void:
	if has_focus():
		PadInput.draw_focus_ring(self, Rect2(Vector2.ZERO, size).grow(1), RelicStyle.accent)


func _process(_d: float) -> void:
	if has_focus():
		queue_redraw()
