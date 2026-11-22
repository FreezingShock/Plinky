class_name DisplayPanel
extends PanelContainer
## Settings panel (F10, or the Settings button in the bottom bar). Window scale and window mode.
## Every choice writes through DisplaySettings, so it is saved and applied at once.

var _win: Window
var _pixel_btn: PixelButton
var _fit_btn: PixelButton
var _wide_btn: PixelButton
var _window_btn: PixelButton
var _full_btn: PixelButton
var _custom_btn: PixelButton
var _native_btn: PixelButton
var _hint: Label


func bind(win: Window) -> void:
	_win = win
	visible = false
	add_theme_stylebox_override("panel", AsciiBox.panel())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)

	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "Settings"
	v.add_child(title)

	v.add_child(_caption("Window scale"))
	var scale_row := HBoxContainer.new()
	scale_row.add_theme_constant_override("separation", 4)
	v.add_child(scale_row)
	_pixel_btn = _option(scale_row, "Pixel perfect", func() -> void:
		DisplaySettings.set_scale_mode(_win, DisplaySettings.Scale.PIXEL)
		refresh())
	_fit_btn = _option(scale_row, "Fit window", func() -> void:
		DisplaySettings.set_scale_mode(_win, DisplaySettings.Scale.FIT)
		refresh())
	_wide_btn = _option(scale_row, "Wide view", func() -> void:
		DisplaySettings.set_scale_mode(_win, DisplaySettings.Scale.WIDE)
		refresh())

	v.add_child(_caption("Window"))
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 4)
	v.add_child(mode_row)
	_window_btn = _option(mode_row, "Windowed", func() -> void:
		DisplaySettings.set_fullscreen(_win, false)
		refresh())
	_full_btn = _option(mode_row, "Fullscreen", func() -> void:
		DisplaySettings.set_fullscreen(_win, true)
		refresh())

	v.add_child(_caption("Window frame"))
	var frame_row := HBoxContainer.new()
	frame_row.add_theme_constant_override("separation", 4)
	v.add_child(frame_row)
	_custom_btn = _option(frame_row, "Plinky frame", func() -> void:
		DisplaySettings.set_native_frame(_win, false)
		refresh())
	_native_btn = _option(frame_row, "System frame", func() -> void:
		DisplaySettings.set_native_frame(_win, true)
		refresh())

	_hint = Label.new()
	_hint.custom_minimum_size.x = 220
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	_hint.add_theme_color_override("font_color", RelicStyle.dim)
	v.add_child(_hint)

	var close_btn := PixelButton.new()
	close_btn.text = "Close [F10]"
	close_btn.pressed.connect(close)
	v.add_child(close_btn)

	_win.size_changed.connect(_on_window_changed)
	refresh()


func open() -> void:
	refresh()
	visible = true
	reset_size()
	await get_tree().process_frame
	# Centre over the frame, which is the parent (the HUD is the frame's size).
	position = ((get_parent_area_size() - size) * 0.5).floor()


func close() -> void:
	visible = false


func refresh() -> void:
	if _win == null:
		return
	var mode: int = DisplaySettings.scale_mode
	_pixel_btn.text = _tag(mode == DisplaySettings.Scale.PIXEL, "Pixel perfect")
	_fit_btn.text = _tag(mode == DisplaySettings.Scale.FIT, "Fit window")
	_wide_btn.text = _tag(mode == DisplaySettings.Scale.WIDE, "Wide view")
	_window_btn.text = _tag(not DisplaySettings.fullscreen, "Windowed")
	_full_btn.text = _tag(DisplaySettings.fullscreen, "Fullscreen")
	_custom_btn.text = _tag(not DisplaySettings.native_frame, "Plinky frame")
	_native_btn.text = _tag(DisplaySettings.native_frame, "System frame")
	if mode == DisplaySettings.Scale.FIT:
		_hint.text = "Fit fills the window at any size. Texels can differ by one pixel. F11 toggles fullscreen."
	elif not DisplaySettings.pixel_active(_win):
		_hint.text = "This window is too small for a whole-number scale, so it shows Fit. Make it bigger for a sharper view."
	elif mode == DisplaySettings.Scale.WIDE and not DisplaySettings.bleed_ready:
		_hint.text = "Wide view shows more of the meadow once its wider backdrop is in. Until then it letterboxes."
	elif mode == DisplaySettings.Scale.WIDE:
		_hint.text = "Wide view shows the whole 840x480 meadow, centred, with black beyond it. F11 toggles fullscreen."
	else:
		_hint.text = "Pixel perfect keeps every texel the same size. F11 toggles fullscreen."


func _on_window_changed() -> void:
	if visible:
		refresh()


func _caption(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", RelicStyle.dim)
	return l


func _option(row: HBoxContainer, label: String, on_pick: Callable) -> PixelButton:
	var b := PixelButton.new()
	b.text = label
	b.pressed.connect(on_pick)
	row.add_child(b)
	return b


func _tag(on: bool, label: String) -> String:
	return ("> " if on else "  ") + label
