class_name TipHost
extends PanelContainer
## The single tooltip panel Tip drives. Themed like every other panel (AsciiBox, Pixelify title, Spleen body).
## Never takes mouse input. Drawn in the 640x360 stretch view, so it follows UI scale, and clamped to the visible rect.
##
## Layout: [icon] title / prose body / rich lines (coloured segments and inline icons) / hint.
## Hover is tracked by asking the viewport which control is under the mouse each frame, so it is right at any
## stretch scale and never depends on mouse_exited arriving; it hides once the mouse has been away for AWAY seconds.

const BODY_FONT: String = "res://fonts/spleen-6x12.fnt"
const TITLE_FONT: String = "res://fonts/PixelifySans.ttf"
const THEME_FALLBACK: String = "res://theme/plinky_theme.tres"
const ICON_DIR: String = "res://assets/icons/"
const MAX_WIDTH: int = 150
const HOVER_DELAY: float = 0.35     ## seconds before a mouse hover shows
const FOCUS_DELAY: float = 0.08     ## keyboard / pad focus shows almost at once
const GRACE: float = 0.30           ## after one tip, the next shows instantly within this window
const AWAY: float = 0.10            ## the mouse may be off the control this long before the tip hides
const CURSOR_OFFSET: Vector2 = Vector2(10.0, 12.0)
const AVOID_GROUP: StringName = &"tip_avoid"

var target: Control = null
## Tests set this to stand in for the viewport's hovered control.
var test_hover_enabled: bool = false
var test_hover: Control = null
## Extra rects to keep clear of, besides the visible Controls in the avoid group (used by tests).
var avoid_extra: Array[Rect2] = []

var _suppressed: Control = null   ## pressed or unfocused: stays quiet until the mouse leaves it
var _by_focus: bool = false
var _beside_target: bool = false   ## spec asked to sit beside its control instead of at the cursor
var _free_mode: bool = false
var _free_exact: bool = false
var _free_at: Vector2 = Vector2.ZERO
var _free_spec: Variant = null
var _anchor: Rect2 = Rect2()
var _wait: float = 0.0
var _away: float = 0.0
var _since_hidden: float = 99.0
var _head: HBoxContainer
var _icon: TextureRect
var _title: Label
var _body: Label
var _lines: VBoxContainer
var _hint: Label
var _body_font: Font
var _title_font: Font


func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 200
	theme = load(THEME_FALLBACK) as Theme   # replaced by the live HUD theme when there is one
	_body_font = load(BODY_FONT) as Font
	_title_font = load(TITLE_FONT) as Font
	add_theme_stylebox_override("panel", AsciiBox.panel())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	_head = HBoxContainer.new()
	_head.add_theme_constant_override("separation", 4)
	_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_head)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(16, 16)
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head.add_child(_icon)
	_title = _label(_head, true)
	_body = _label(v, false)
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", 1)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_lines)
	_hint = _label(v, false)


func _label(parent: Node, title: bool) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if title:
		l.theme_type_variation = &"TitleLabel"
		l.add_theme_font_override(&"font", _title_font)
		l.add_theme_font_size_override(&"font_size", 16)
	else:
		l.add_theme_font_override(&"font", _body_font)   # explicit: never depend on inheritance
		l.add_theme_font_size_override(&"font_size", 12)
	l.add_theme_color_override("font_color", RelicStyle.text)
	l.add_theme_color_override("font_outline_color", RelicStyle.ink)
	parent.add_child(l)
	return l


## A bound control was entered or focused. Starts the delay (or shows at once inside the grace window or when
## the mouse slid straight from another tip).
func request(c: Control, by_focus: bool) -> void:
	_adopt_theme(c)
	target = c
	_by_focus = by_focus
	_free_mode = false
	_away = 0.0
	_wait = 0.0 if (visible or _since_hidden < GRACE) else (FOCUS_DELAY if by_focus else HOVER_DELAY)
	if _wait <= 0.0:
		_show()
	else:
		visible = false


func show_free(spec: Variant, at: Vector2, exact: bool = false) -> void:
	_free_exact = exact
	if not _free_mode:
		_adopt_theme(get_tree().current_scene if is_inside_tree() else null)
		target = null
		_free_mode = true
		_by_focus = false
		_wait = 0.0 if _since_hidden < GRACE else HOVER_DELAY
	_free_spec = spec
	_free_at = at
	if _wait <= 0.0:
		if _fill(spec):
			visible = true
			_place()
		else:
			visible = false


func set_beside(r: Rect2) -> void:
	_anchor = r
	if visible:
		_place()


func hide_free() -> void:
	if _free_mode:
		dismiss()


func refresh() -> void:
	if visible and target != null and target.has_meta(Tip.META):
		_fill(target.get_meta(Tip.META))
		_place()


## A bound control lost focus, was pressed, or left the tree. Mouse departures are handled by polling instead.
func on_exit(c: Control) -> void:
	if c == target:
		_suppressed = c
		dismiss()


func dismiss() -> void:
	if visible:
		_since_hidden = 0.0
	visible = false
	target = null
	_free_mode = false
	_wait = 0.0
	_away = 0.0


## The first navigation input after a quiet menu-open focus lets focus tooltips show again.
func _input(event: InputEvent) -> void:
	if not Tip.focus_muted or not event.is_pressed():
		return
	for a: StringName in [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_focus_next", &"ui_focus_prev"]:
		if event.is_action_pressed(a):
			Tip.focus_muted = false
			return


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
				if _fill(_free_spec):
					visible = true
					_place()
		elif visible:
			_place()
		return
	if target == null:
		_discover()
		return
	if not _by_focus and _track_hover(delta):
		return
	if _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_show()
	elif visible and not _by_focus:
		_place()


## Nothing is showing: find the nearest bound control at or above whatever is under the mouse. This makes
## hover independent of mouse_entered signals, so a bound row works even if only a child or the panel is hovered.
func _discover() -> void:
	if _free_mode or not (test_hover_enabled or (is_inside_tree() and get_viewport() != null)):
		return
	var n: Node = test_hover if test_hover_enabled else get_viewport().gui_get_hovered_control()
	while n != null:
		if n is Control and n.has_meta(Tip.META):
			if n == _suppressed:
				return
			_suppressed = null
			request(n as Control, false)
			return
		n = n.get_parent()
	_suppressed = null


## True if the tip was dismissed or switched. Asks the viewport which control is under the mouse.
func _track_hover(delta: float) -> bool:
	if not test_hover_enabled and not (is_inside_tree() and get_viewport() != null):
		return false
	var hov: Control = test_hover if test_hover_enabled else get_viewport().gui_get_hovered_control()
	if hov != null and (hov == target or target.is_ancestor_of(hov)):
		_away = 0.0
		return false
	var up: Node = hov
	while up != null:
		if up is Control and up.has_meta(Tip.META):
			request(up as Control, false)   # slid straight onto another tooltip's control
			return true
		up = up.get_parent()
	_away += delta
	if _away >= AWAY:
		dismiss()
		return true
	return false


## The panel lives on its own layer, outside the HUD's theme, so borrow the theme (and so the fonts) of the
## nearest themed ancestor of whatever it describes. Shared by reference, so zone recolours reach it too.
func _adopt_theme(from: Node) -> void:
	var n: Node = from
	while n != null:
		if n is Control and (n as Control).theme != null:
			theme = (n as Control).theme
			return
		n = n.get_parent()


func _show() -> void:
	if target == null or not target.has_meta(Tip.META):
		return
	if _fill(target.get_meta(Tip.META)):
		visible = true
		_place()
	else:
		visible = false


## Build the panel from a spec. False when the spec is empty (nothing to show).
func _fill(spec: Variant) -> bool:
	var d: Dictionary = Tip.normalize(spec)
	if bool(d["empty"]):
		return false
	var tc: Color = d["title_color"] as Color
	var edge: Color = d["color"] as Color
	_beside_target = bool(d.get("beside", false))
	_title.text = str(d["title"])
	_title.add_theme_color_override("font_color", tc if tc.a > 0.0 else (edge if edge.a > 0.0 else RelicStyle.text))
	_head.visible = _title.text != "" or str(d["icon"]) != ""
	_title.visible = _title.text != ""
	var ic: String = str(d["icon"])
	var tex: Texture2D = load(ICON_DIR + ic + ".png") as Texture2D if ic != "" and ResourceLoader.exists(ICON_DIR + ic + ".png") else null
	_icon.texture = tex
	_icon.visible = tex != null
	_prose(_body, str(d["body"]), RelicStyle.text)
	var hc: Color = d["hint_color"] as Color
	_prose(_hint, str(d["hint"]), hc if hc.a > 0.0 else RelicStyle.dim)
	for ch: Node in _lines.get_children():
		_lines.remove_child(ch)
		ch.queue_free()
	for line: Variant in (d["lines"] as Array):
		_lines.add_child(_rich_line(line as Array))
	_lines.visible = _lines.get_child_count() > 0
	add_theme_stylebox_override("panel", AsciiBox.panel(edge))
	reset_size()
	return true


## Prose wraps at MAX_WIDTH, but a short sentence keeps its natural width so the box hugs it.
func _prose(l: Label, text: String, c: Color) -> void:
	l.text = text
	l.visible = text != ""
	l.add_theme_color_override("font_color", c)
	var widest: float = 0.0
	for part: String in text.split("\n"):
		widest = maxf(widest, _body_font.get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x)
	if widest > MAX_WIDTH:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = MAX_WIDTH
	else:
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.custom_minimum_size.x = 0


## One row of coloured text and inline 16 px icons.
func _rich_line(segs: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for sg: Variant in segs:
		var d: Dictionary = {"t": str(sg)} if not (sg is Dictionary) else (sg as Dictionary)
		if d.has("icon"):
			var path: String = ICON_DIR + str(d["icon"]) + ".png"
			if ResourceLoader.exists(path):
				var icon_rect := TextureRect.new()
				icon_rect.texture = load(path) as Texture2D
				icon_rect.custom_minimum_size = Vector2(16, 16)
				icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row.add_child(icon_rect)
			continue
		var l := _label(row, false)
		if bool(d.get("tag", false)):
			l.add_theme_font_override(&"font", StatStyle.tag_font())
			l.add_theme_font_size_override(&"font_size", StatStyle.TAG_SIZE)
		l.text = str(d.get("t", ""))
		var c: Color = d.get("c", Color(0, 0, 0, 0)) as Color
		l.add_theme_color_override("font_color", c if c.a > 0.0 else RelicStyle.text)
	return row


func set_extra_avoid(rects: Array[Rect2]) -> void:
	avoid_extra = rects


func _place() -> void:
	reset_size()
	var view: Vector2 = _view_size()
	var p: Vector2
	if _free_mode:
		p = _free_at if _free_exact else _free_at + CURSOR_OFFSET
		if _free_exact and _anchor.size != Vector2.ZERO:
			p = _beside(view)
		if not _free_exact and p.y + size.y > view.y - 2.0:
			p.y = _free_at.y - size.y - 8.0
	elif _beside_target and target != null:
		_anchor = target.get_global_rect()
		p = _beside(view)
	elif _by_focus and target != null:
		# Anchor under the focused control; flip above near the bottom.
		var r: Rect2 = target.get_global_rect()
		p = Vector2(r.position.x, r.end.y + 3.0)
		if p.y + size.y > view.y - 2.0:
			p.y = r.position.y - size.y - 3.0
	else:
		var m: Vector2 = get_viewport().get_mouse_position() if get_viewport() != null else Vector2.ZERO
		p = m + CURSOR_OFFSET
		if p.y + size.y > view.y - 2.0 or m.y > view.y * 0.6:
			p.y = m.y - size.y - 8.0
		if p.x + size.x > view.x - 2.0:
			p.x = m.x - size.x - 6.0
	p.x = clampf(p.x, 2.0, maxf(2.0, view.x - size.x - 2.0))
	p.y = clampf(p.y, 2.0, maxf(2.0, view.y - size.y - 2.0))
	global_position = p.round()


func _view_size() -> Vector2:
	var vp: Viewport = get_viewport()
	return vp.get_visible_rect().size if vp != null else Vector2(640.0, 360.0)


## First of right, left, below, above of the anchor that is on screen and clear of the avoid panels.
func _beside(view: Vector2) -> Vector2:
	var a: Rect2 = _anchor
	var cands: Array[Vector2] = [
		Vector2(a.end.x + 4.0, a.position.y), Vector2(a.position.x - size.x - 4.0, a.position.y),
		Vector2(a.position.x, a.end.y + 4.0), Vector2(a.position.x, a.position.y - size.y - 4.0)]
	var avoid: Array[Rect2] = avoid_extra.duplicate()
	if is_inside_tree():
		for n: Node in get_tree().get_nodes_in_group(AVOID_GROUP):
			if n is Control and (n as Control).is_visible_in_tree():
				avoid.append((n as Control).get_global_rect())
	var screen := Rect2(Vector2(2.0, 2.0), view - Vector2(4.0, 4.0))
	for c: Vector2 in cands:
		var r := Rect2(c, size)
		if not screen.encloses(r):
			continue
		var clear: bool = true
		for av: Rect2 in avoid:
			if av.intersects(r):
				clear = false
				break
		if clear:
			return c
	return cands[0]
