class_name TipCard
extends PanelContainer
## One tip at a time, in the dither-box style: title, a few lines, a draining timer bar, and two buttons.
## "Got it" closes this tip. "Skip tips" closes it and turns tips off for good (the Hud saves that).
## The Hud places the card above the bottom bar and feeds it real-time deltas.

signal closed(skipped: bool)

const WIDTH: float = 250.0

var _title: Label
var _body: Label
var _bar: DitherBar
## True while a menu is open (the Esc menu, panels): the card steps aside, its timer pauses, and it comes back after.
var held: bool = false:
	set(v):
		held = v
		visible = _active and not held
var _active: bool = false
var _left: float = 0.0
var _total: float = 1.0


func _init() -> void:
	visible = false
	z_index = 150
	add_theme_stylebox_override("panel", AsciiBox.panel())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	add_child(v)
	_title = Label.new()
	_title.theme_type_variation = &"TitleLabel"
	v.add_child(_title)
	_body = Label.new()
	_body.custom_minimum_size.x = WIDTH
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_body)
	_bar = DitherBar.new(WIDTH)
	v.add_child(_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	v.add_child(row)
	var ok := PixelButton.new()
	ok.text = "Got it"
	ok.pressed.connect(func() -> void: _close(false))
	row.add_child(ok)
	var skip := PixelButton.new()
	skip.text = "Skip tips"
	skip.pressed.connect(func() -> void: _close(true))
	row.add_child(skip)


func show_tip(title: String, text: String, lifetime: float) -> void:
	_title.text = title
	_body.text = text
	_total = maxf(lifetime, 1.0)
	_left = _total
	_bar.value = 1.0
	_active = true
	visible = not held
	reset_size()


func is_showing() -> bool:
	return _active


func dismiss() -> void:
	_active = false
	visible = false


func _close(skipped: bool) -> void:
	_active = false
	visible = false
	closed.emit(skipped)


func _process(delta: float) -> void:
	if not visible:
		return
	_left -= delta
	_bar.value = _left / _total
	if _left <= 0.0:
		_close(false)
