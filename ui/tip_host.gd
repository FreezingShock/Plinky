class_name TipHost
extends PanelContainer
## The single tooltip panel Tip drives. Themed like every other panel (AsciiBox, Pixelify title, Spleen
## body). Never takes mouse input. Positioned in the 640x360 stretch view, so it follows UI scale for free,
## and clamped to the visible rect so it never leaves the screen.

const MAX_WIDTH: int = 150
const HOVER_DELAY: float = 0.35     ## seconds before a mouse hover shows
const FOCUS_DELAY: float = 0.08     ## keyboard / pad focus shows almost at once
const GRACE: float = 0.30           ## after one tip, the next shows instantly within this window
const CURSOR_OFFSET: Vector2 = Vector2(10.0, 12.0)

var target: Control = null
var _by_focus: bool = false
var _free_mode: bool = false
var _free_at: Vector2 = Vector2.ZERO
var _wait: float = 0.0
var _since_hidden: float = 99.0
var _title: Label
var _body: Label
var _hint: Label


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 200
	add_theme_stylebox_override("panel", AsciiBox.panel())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	_title = _label(v)
	_title.theme_type_variation = &"TitleLabel"
	_body = _label(v)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.x = MAX_WIDTH
	_hint = _label(v)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = MAX_WIDTH
	_hint.add_theme_color_override("font_color", RelicStyle.dim)


func _label(parent: Node) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", RelicStyle.text)
	l.add_theme_color_override("font_outline_color", RelicStyle.ink)
	parent.add_child(l)
	return l


## A bound control was entered or focused. Starts the delay (or shows at once inside the grace window).
func request(c: Control, by_focus: bool) -> void:
	target = c
	_by_focus = by_focus
	_free_mode = false
	_wait = 0.0 if _since_hidden < GRACE else (FOCUS_DELAY if by_focus else HOVER_DELAY)
	if _wait <= 0.0:
		_show()
	else:
		visible = false


func show_free(spec: Variant, at: Vector2, exact: bool = false) -> void:
	_free_exact = exact
	if not _free_mode:
		target = null
		_free_mode = true
		_by_focus = false
		_wait = 0.0 if _since_hidden < GRACE else HOVER_DELAY
		_free_spec = spec
	_free_spec = spec
	_free_at = at
	if _wait <= 0.0:
		_fill(spec)
		visible = true
		_place()


var _free_spec: Variant = null
var _free_exact: bool = false


func hide_free() -> void:
	if _free_mode:
		dismiss()


func refresh() -> void:
	if visible and target != null and target.has_meta(Tip.META):
		_fill(target.get_meta(Tip.META))
		_place()


func dismiss() -> void:
	if visible:
		_since_hidden = 0.0
	visible = false
	target = null
	_free_mode = false
	_wait = 0.0


func _process(delta: float) -> void:
	if not visible:
		_since_hidden += delta
	if target != null and (not is_instance_valid(target) or (target.is_inside_tree() and not target.is_visible_in_tree())):
		dismiss()
		return
	if _free_mode:
		if _wait > 0.0:
			_wait -= delta
			if _wait <= 0.0:
				_fill(_free_spec)
				visible = true
				_place()
		elif visible:
			_place()
		return
	if target == null:
		return
	if _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_show()
	elif visible and not _by_focus:
		_place()


func _show() -> void:
	if target == null or not target.has_meta(Tip.META):
		return
	_fill(target.get_meta(Tip.META))
	visible = true
	_place()


func _fill(spec: Variant) -> void:
	var d: Dictionary = Tip.normalize(spec)
	_title.text = str(d["title"])
	_title.visible = _title.text != ""
	_body.text = str(d["body"])
	_body.visible = _body.text != ""
	_hint.text = str(d["hint"])
	_hint.visible = _hint.text != ""
	var c: Color = d["color"] as Color
	_title.add_theme_color_override("font_color", c if c.a > 0.0 else RelicStyle.text)
	add_theme_stylebox_override("panel", AsciiBox.panel(c))
	reset_size()


func _place() -> void:
	reset_size()
	var view: Vector2 = _view_size()
	var p: Vector2
	if _free_mode:
		p = _free_at if _free_exact else _free_at + CURSOR_OFFSET
		if not _free_exact and p.y + size.y > view.y - 2.0:
			p.y = _free_at.y - size.y - 8.0
	elif _by_focus and target != null:
		# Anchor under the focused control; flip above if it would run off the bottom.
		var r: Rect2 = target.get_global_rect()
		p = Vector2(r.position.x, r.end.y + 3.0)
		if p.y + size.y > view.y - 2.0:
			p.y = r.position.y - size.y - 3.0
	else:
		var m: Vector2 = get_viewport().get_mouse_position() if get_viewport() != null else Vector2.ZERO
		p = m + CURSOR_OFFSET
		if p.y + size.y > view.y - 2.0:
			p.y = m.y - size.y - 8.0
		if p.x + size.x > view.x - 2.0:
			p.x = m.x - size.x - 6.0
	p.x = clampf(p.x, 2.0, maxf(2.0, view.x - size.x - 2.0))
	p.y = clampf(p.y, 2.0, maxf(2.0, view.y - size.y - 2.0))
	global_position = p.round()


func _view_size() -> Vector2:
	var vp: Viewport = get_viewport()
	return vp.get_visible_rect().size if vp != null else Vector2(640.0, 360.0)
