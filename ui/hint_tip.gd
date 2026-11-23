class_name HintTip
extends PanelContainer
## Small hover and focus tooltip in the panel style: a title and a few wrapped lines. One instance serves a whole
## panel. `attach(control, provider)` wires a control; the provider returns [title, body] when asked, so the text is
## always current. The tip opens beside the control (left first, since the zone panel hugs the right edge) and never
## takes mouse input.

const MAX_WIDTH: float = 150.0

var _title: Label
var _body: Label
var _host: Control


func _init() -> void:
	visible = false
	top_level = true
	z_index = 220
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", AsciiBox.panel())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	add_child(v)
	_title = Label.new()
	_title.theme_type_variation = &"TitleLabel"
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_title)
	_body = Label.new()
	_body.custom_minimum_size.x = MAX_WIDTH
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_color_override("font_color", RelicStyle.text)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_body)


func attach(ctrl: Control, provider: Callable) -> void:
	ctrl.mouse_entered.connect(_open.bind(ctrl, provider))
	ctrl.focus_entered.connect(_open.bind(ctrl, provider))
	ctrl.mouse_exited.connect(_close.bind(ctrl))
	ctrl.focus_exited.connect(_close.bind(ctrl))
	ctrl.visibility_changed.connect(func() -> void:
		if not ctrl.is_visible_in_tree():
			_close(ctrl))


func _open(ctrl: Control, provider: Callable) -> void:
	var tip: Array = provider.call() as Array
	if tip.is_empty():
		return
	_host = ctrl
	_title.text = String(tip[0])
	_body.text = String(tip[1]) if tip.size() > 1 else ""
	_body.visible = _body.text != ""
	visible = true
	reset_size()
	_place(ctrl)


func _close(ctrl: Control) -> void:
	if _host == ctrl:
		_host = null
		visible = false


func hide_tip() -> void:
	_host = null
	visible = false


func _place(ctrl: Control) -> void:
	var r: Rect2 = ctrl.get_global_rect()
	var area: Vector2 = get_viewport_rect().size
	var p := Vector2(r.position.x - size.x - 4.0, r.position.y)
	if p.x < 2.0:
		p = Vector2(r.position.x, r.end.y + 3.0)
	p.x = clampf(p.x, 2.0, maxf(area.x - size.x - 2.0, 2.0))
	p.y = clampf(p.y, 2.0, maxf(area.y - size.y - 2.0, 2.0))
	global_position = p.round()
