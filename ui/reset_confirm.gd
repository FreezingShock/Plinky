class_name ResetConfirm
extends PanelContainer
## The zone reset confirm (Bloom or Nucleus). The reset's currency icon is big, with the exact count under it and a hold
## button in the currency's colour under that. Hold to strike: press and hold the icon or the button (or Enter, or pad A).
## The fill rises and rings come off the icon, faster as it fills. At full the reset runs and its ritual flies out of the
## icon (BloomRitual.launch_global). Let go early and the fill drains. "Not yet" (or Esc, or pad B) closes it.
## Reduce motion and Reduce flashing drop the rings; the fill still shows. MenuRouter.blocked keeps every other menu shut
## while this is open.

signal cancelled

const HOLD_TIME: float = 1.0       ## seconds held to strike
const DRAIN_SPEED: float = 2.5     ## fill lost per second let go
const RING_EVERY: float = 0.16     ## seconds between rings while held (halves as the fill reaches full)
const RING_LIFE: float = 0.6
const RING_GROW: float = 70.0      ## how far a ring travels, in px
const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]   ## the 4x4 Bayer order the theme dithers with
const BADGE: float = 136.0         ## the icon's square; the icon itself is 4x (128 px)
const WIDTH: float = 250.0

var on_strike: Callable = Callable()   ## called with the icon's global centre once the hold completes
var _title: Label
var _body: VBoxContainer
var _badge: HoldIcon
var _count: Label
var _caption: Label
var _bar: HoldBar
var _cancel: PixelButton
var _held: float = 0.0
var _pressing: bool = false
var _ring_acc: float = 0.0
var _rings: Array[Dictionary] = []


## The bar of the button under the count: a fill that rises left to right in the currency colour.
class HoldBar extends Control:
	var fill: float = 0.0
	var colour: Color = Color.WHITE
	var text: String = ""

	func _init() -> void:
		custom_minimum_size = Vector2(250.0, 30.0)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var w: float = size.x
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.09, 0.11, 1.0))
		draw_rect(Rect2(Vector2.ZERO, Vector2(w * fill, size.y)), Color(colour.r, colour.g, colour.b, 0.55))
		draw_rect(Rect2(Vector2.ZERO, size), colour, false, 2.0)
		var font: Font = get_theme_default_font()
		var fs: int = get_theme_default_font_size()
		var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
		draw_string(font, Vector2(roundf((w - tw) * 0.5), roundf(size.y * 0.5 + fs * 0.35)), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, StatStyle.PAPER)


## The big currency icon, drawn at 4x. It brightens a little with the fill, so the hold reads on the icon too.
class HoldIcon extends Control:
	var icon: Texture2D
	var colour: Color = Color.WHITE
	var fill: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(136.0, 136.0)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var c: Vector2 = (size * 0.5).round()
		if fill > 0.0:
			# a round glow, dithered on a 4 px grid with the palette's 4x4 Bayer order, so it reads as pixels, not a box
			var r: float = 70.0
			var cell: float = 4.0
			var steps: int = int(r / cell)
			for iy: int in range(-steps, steps):
				for ix: int in range(-steps, steps):
					var p: Vector2 = Vector2(float(ix) + 0.5, float(iy) + 0.5) * cell
					var d: float = p.length() / r
					if d >= 1.0:
						continue
					var cover: float = fill * (1.0 - d) * (1.0 - d) * 0.5
					var bayer: float = (float(BAYER[(ix & 3) + (iy & 3) * 4]) + 0.5) / 16.0
					if cover > bayer:
						draw_rect(Rect2(c + Vector2(float(ix), float(iy)) * cell, Vector2(cell, cell)), Color(colour.r, colour.g, colour.b, 0.9))
		if icon != null:
			var px: float = icon.get_width() * 4.0
			var tint: Color = Color.WHITE.lerp(colour, 0.15 * fill)
			draw_texture_rect(icon, Rect2((c - Vector2(px, px) * 0.5).round(), Vector2(px, px)), false, tint)


func _init() -> void:
	visible = false
	z_index = 160
	add_theme_stylebox_override("panel", AsciiBox.panel())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	_title = Label.new()
	_title.theme_type_variation = &"TitleLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 1)
	_body.custom_minimum_size.x = WIDTH
	v.add_child(_body)
	_badge = HoldIcon.new()
	_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_badge.gui_input.connect(_on_hold_input)
	v.add_child(_badge)
	_count = Label.new()
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.add_theme_font_size_override("font_size", 30)
	v.add_child(_count)
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_caption)
	_bar = HoldBar.new()
	_bar.gui_input.connect(_on_hold_input)
	v.add_child(_bar)
	_cancel = PixelButton.new()
	_cancel.focus_mode = Control.FOCUS_NONE   # Enter holds; it must not also press Not yet
	_cancel.text = "Not yet"
	_cancel.pressed.connect(_close_unstruck)
	v.add_child(_cancel)


## Shows the card. `icon` is the currency's big icon; `count_text` is the exact amount, for example "+2,508".
func open(title: String, colour: Color, icon: Texture2D, count_text: String, caption: String, lines: Array,
		hold_text: String, p_on_strike: Callable) -> void:
	on_strike = p_on_strike
	_title.text = title
	_title.add_theme_color_override("font_color", StatStyle.PAPER)
	for c: Node in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	for ln: Array in lines:
		var l := Label.new()
		l.text = String(ln[0])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = WIDTH
		l.add_theme_color_override("font_color", ln[1] as Color)
		_body.add_child(l)
	_badge.icon = icon
	_badge.colour = colour
	_count.text = count_text
	_count.add_theme_color_override("font_color", colour)
	_caption.text = caption
	_caption.add_theme_color_override("font_color", colour)
	_bar.colour = colour
	_bar.text = hold_text
	_held = 0.0
	_pressing = false
	_ring_acc = 0.0
	_rings.clear()
	_refresh_fill()
	# shown first: a container does not sort a hidden child. Nothing draws until this returns, so the card is laid out now.
	visible = true
	reset_size()
	# lay the card and its box out now, outer first, so a press in the frame of the open hits the bar where it is drawn
	notification(Container.NOTIFICATION_SORT_CHILDREN)
	(get_child(0) as Container).notification(Container.NOTIFICATION_SORT_CHILDREN)
	reset_size()


## Pure: how full the hold reads for `held` seconds, 0 to 1.
static func fill_for(held: float) -> float:
	return clampf(held / HOLD_TIME, 0.0, 1.0)


## Pure: whether `held` seconds of hold is enough to strike.
static func strikes(held: float) -> bool:
	return held >= HOLD_TIME


func is_open() -> bool:
	return visible


func _process(frame_delta: float) -> void:
	if not visible:
		return
	# a long frame (a hitch, a window drag) must not finish a hold in one step: cap the step at 0.1 s
	var delta: float = minf(frame_delta, 0.1)
	if _pressing:
		_held = minf(HOLD_TIME, _held + delta)
		if not _calm():
			var every: float = RING_EVERY * (1.0 - 0.5 * fill_for(_held))
			_ring_acc += delta
			while _ring_acc >= every:
				_ring_acc -= every
				_rings.append({"age": 0.0})
	else:
		_held = maxf(0.0, _held - delta * DRAIN_SPEED)
	for r: Dictionary in _rings:
		r["age"] = float(r["age"]) + delta
	_rings = Array(_rings.filter(func(r: Dictionary) -> bool: return float(r["age"]) < RING_LIFE), TYPE_DICTIONARY, "", null)
	_refresh_fill()
	queue_redraw()
	if _pressing and strikes(_held):
		_strike()


## The same test as the ritual's, so the rings here and the flight there always agree.
func _calm() -> bool:
	return FxConfig.ascension_calm()


func _refresh_fill() -> void:
	_bar.fill = fill_for(_held)
	_badge.fill = fill_for(_held)
	_bar.queue_redraw()
	_badge.queue_redraw()


func _on_hold_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_pressing = (event as InputEventMouseButton).pressed
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and not (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_pressing = false   # a release anywhere ends the hold, even off the button
	elif event.is_action_pressed(&"ui_accept") and not (event is InputEventKey and (event as InputEventKey).echo):
		_pressing = true
		get_viewport().set_input_as_handled()
	elif event.is_action_released(&"ui_accept"):
		_pressing = false
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_unstruck()


func _strike() -> void:
	var origin: Vector2 = _badge.get_global_rect().get_center()
	_pressing = false
	_held = 0.0
	_rings.clear()
	visible = false
	if on_strike.is_valid():
		on_strike.call(origin)


func _close_unstruck() -> void:
	_pressing = false
	_held = 0.0
	_rings.clear()
	visible = false
	cancelled.emit()


func _draw() -> void:
	if not visible or _calm():
		return
	var c: Vector2 = _badge.get_global_rect().get_center() - get_global_rect().position
	for r: Dictionary in _rings:
		var u: float = float(r["age"]) / RING_LIFE
		var radius: float = BADGE * 0.5 + 6.0 + RING_GROW * (1.0 - pow(1.0 - u, 2.0))
		var col: Color = _badge.colour.lerp(Color("fff1c8"), u * 0.5)
		col.a = 1.0 - u
		var n: int = maxi(16, int(radius * 1.1))
		for i in n:
			if (i + int(u * 20.0)) % 2 == 1:
				continue   # dashed as it travels
			var a: float = TAU * float(i) / float(n)
			draw_rect(Rect2((c + Vector2(cos(a), sin(a) * 0.85) * radius).round(), Vector2(2.0, 2.0)), col)
