class_name ModalCard
extends PanelContainer
## A small centred card with a title, a few coloured lines and two buttons (confirm / cancel). Used for the rebirth
## confirm and the offline-earnings summary. Enter or the pad's confirm button accepts, Esc or the pad's B cancels.
## The Hud centres it in the free area (see Hud._layout). It never pauses the game.

signal confirmed
signal cancelled

const WIDTH: float = 230.0

## Settings > Gameplay > Confirm rebirth.
static var rebirth_confirm: bool = true

var on_confirm: Callable = Callable()   ## run when the confirm button is pressed (set by open())
var _title: Label
var _lines: VBoxContainer
var _ok: PixelButton
var _cancel: PixelButton


func _init() -> void:
	visible = false
	z_index = 160
	add_theme_stylebox_override("panel", AsciiBox.panel())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	add_child(v)
	_title = Label.new()
	_title.theme_type_variation = &"TitleLabel"
	v.add_child(_title)
	_lines = VBoxContainer.new()
	_lines.add_theme_constant_override("separation", 1)
	_lines.custom_minimum_size.x = WIDTH
	v.add_child(_lines)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	v.add_child(row)
	_ok = PixelButton.new()
	_ok.pressed.connect(func() -> void: _finish(true))
	row.add_child(_ok)
	_cancel = PixelButton.new()
	_cancel.pressed.connect(func() -> void: _finish(false))
	row.add_child(_cancel)


## lines: Array of [text, Color]. An empty cancel_text hides the cancel button (a notice, not a question).
func open(title: String, lines: Array, ok_text: String, cancel_text: String = "", p_on_confirm: Callable = Callable()) -> void:
	on_confirm = p_on_confirm
	_title.text = title
	for c: Node in _lines.get_children():
		_lines.remove_child(c)
		c.queue_free()
	for ln: Array in lines:
		var l := Label.new()
		l.text = String(ln[0])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = WIDTH
		l.add_theme_color_override("font_color", ln[1] as Color)
		_lines.add_child(l)
	_ok.text = ok_text
	_cancel.text = cancel_text
	_cancel.visible = cancel_text != ""
	reset_size()
	visible = true
	_ok.grab_focus()


func is_open() -> bool:
	return visible


func close() -> void:
	visible = false


func _finish(accepted: bool) -> void:
	visible = false
	if accepted:
		if on_confirm.is_valid():
			on_confirm.call()
		confirmed.emit()
	else:
		cancelled.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish(false)
