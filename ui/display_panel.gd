class_name DisplayPanel
extends PanelContainer
## The settings menu (F10 or the bottom-bar Settings button). Tabs, rows and values all come from
## SettingsRegistry (ui/settings/settings_registry.gd), so a new setting is one register() call, not panel code.
## Class name and bind/open/close/refresh are kept from the old display panel so main.gd and the HUD still wire it.

const TAB_WIDTH: float = 430.0
const BODY_HEIGHT: float = 196.0
const LABEL_WIDTH: float = 130.0

var _win: Window
var _tab: String = "Audio"
var _tab_buttons: Dictionary = {}     # tab name -> PixelButton
var _body: VBoxContainer
var _hint: Label
var _close_btn: PixelButton
var _refreshers: Array[Callable] = []
var _capture: StringName = &""        # key action waiting for a keypress
var _armed: StringName = &""          # confirm action pressed once


func bind(win: Window) -> void:
	_win = win
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)

	var title := Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.text = "Settings"
	v.add_child(title)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 2)
	v.add_child(tab_row)
	for t in SettingsRegistry.tabs():
		var b := PixelButton.new()
		b.text = t
		b.pressed.connect(show_tab.bind(t))
		tab_row.add_child(b)
		_tab_buttons[t] = b

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(TAB_WIDTH, BODY_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 4)
	scroll.add_child(_body)

	_hint = Label.new()
	_hint.custom_minimum_size = Vector2(TAB_WIDTH, 28)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	_hint.add_theme_color_override("font_color", RelicStyle.dim)
	v.add_child(_hint)

	_close_btn = PixelButton.new()
	_close_btn.pressed.connect(close)
	v.add_child(_close_btn)

	_win.size_changed.connect(_on_window_changed)
	show_tab(_tab)


func open() -> void:
	_close_btn.text = "Close [%s]" % Keybinds.key_name(&"settings")
	show_tab(_tab)
	visible = true
	reset_size()
	await get_tree().process_frame
	# Centre over the frame, which is the parent (the HUD is the frame's size).
	position = ((get_parent_area_size() - size) * 0.5).floor()


func close() -> void:
	_capture = &""
	_armed = &""
	visible = false


## Show one tab. Rows are rebuilt, so options that depend on the machine (devices, monitors) are fresh.
func show_tab(tab: String) -> void:
	if not SettingsRegistry.tabs().has(tab):
		tab = SettingsRegistry.tabs()[0]
	_tab = tab
	_capture = &""
	_armed = &""
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_refreshers.clear()
	for def in SettingsRegistry.entries(tab):
		_body.add_child(_make_row(def))
	_hint.text = ""
	for t: String in _tab_buttons:
		(_tab_buttons[t] as PixelButton).text = _tag(t == tab, t)
	refresh()


## Re-read every value in the open tab.
func refresh() -> void:
	if _win == null:
		return
	for r in _refreshers:
		r.call()


func _on_window_changed() -> void:
	DisplaySettings.note_resized(_win)   # a dragged edge frees the picked window size
	if visible:
		refresh()


# ---------------------------------------------------------------- rows

func _make_row(def: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var kind: int = int(def["kind"])
	if kind != SettingsRegistry.Kind.ACTION:
		var l := Label.new()
		l.text = String(def["label"])
		l.custom_minimum_size.x = LABEL_WIDTH
		row.add_child(l)
	match kind:
		SettingsRegistry.Kind.TOGGLE:
			_build_toggle(row, def)
		SettingsRegistry.Kind.CHOICE:
			_build_choice(row, def)
		SettingsRegistry.Kind.SLIDER:
			_build_slider(row, def)
		SettingsRegistry.Kind.ACTION:
			_build_action(row, def)
		SettingsRegistry.Kind.KEY:
			_build_key(row, def)
	return row


func _show_hint(def: Dictionary) -> void:
	_hint.text = String(def.get("hint", ""))


func _build_toggle(row: HBoxContainer, def: Dictionary) -> void:
	var b := PixelButton.new()
	b.custom_minimum_size.x = 90
	b.pressed.connect(func() -> void:
		SettingsRegistry.set_value(def["id"], not bool(SettingsRegistry.value(def["id"])))
		_show_hint(def)
		refresh())
	b.mouse_entered.connect(_show_hint.bind(def))
	row.add_child(b)
	_refreshers.append(func() -> void:
		b.text = "[x] On" if bool(SettingsRegistry.value(def["id"])) else "[ ] Off")


func _options(def: Dictionary) -> Array:
	return (def["options"] as Callable).call()


func _option_index(opts: Array, cur: Variant) -> int:
	for i in opts.size():
		if (opts[i] as Array)[0] == cur:
			return i
	return 0


func _build_choice(row: HBoxContainer, def: Dictionary) -> void:
	var prev := PixelButton.new()
	prev.text = "<"
	var val := Label.new()
	val.custom_minimum_size.x = 190
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var nxt := PixelButton.new()
	nxt.text = ">"
	row.add_child(prev)
	row.add_child(val)
	row.add_child(nxt)
	var step := func(dir: int) -> void:
		var opts: Array = _options(def)
		if opts.is_empty():
			return
		var i: int = posmod(_option_index(opts, SettingsRegistry.value(def["id"])) + dir, opts.size())
		SettingsRegistry.set_value(def["id"], (opts[i] as Array)[0])
		_show_hint(def)
		refresh()
	prev.pressed.connect(step.bind(-1))
	nxt.pressed.connect(step.bind(1))
	prev.mouse_entered.connect(_show_hint.bind(def))
	nxt.mouse_entered.connect(_show_hint.bind(def))
	_refreshers.append(func() -> void:
		var opts: Array = _options(def)
		val.text = "-" if opts.is_empty() else String((opts[_option_index(opts, SettingsRegistry.value(def["id"]))] as Array)[1]))


func _build_slider(row: HBoxContainer, def: Dictionary) -> void:
	var s := AsciiSlider.new()
	s.min_value = float(def.get("min", 0.0))
	s.max_value = float(def.get("max", 1.0))
	s.step = float(def.get("step", 0.05))
	var val := Label.new()
	val.custom_minimum_size.x = 48
	var fmt: Callable = def.get("format", Callable()) as Callable
	var put := func(v: float) -> void:
		val.text = String(fmt.call(v)) if fmt.is_valid() else "%.2f" % v
	s.value_changed.connect(func(v: float) -> void:
		SettingsRegistry.set_value(def["id"], v)
		put.call(v))
	s.mouse_entered.connect(_show_hint.bind(def))
	row.add_child(s)
	row.add_child(val)
	_refreshers.append(func() -> void:
		var cur: float = float(SettingsRegistry.value(def["id"]))
		s.value = cur
		put.call(cur))


func _build_action(row: HBoxContainer, def: Dictionary) -> void:
	var b := PixelButton.new()
	b.custom_minimum_size.x = 200
	var id: StringName = def["id"]
	var label: String = String(def["label"])
	b.pressed.connect(func() -> void:
		if bool(def.get("confirm", false)) and _armed != id:
			_armed = id
			b.text = "Sure? Press again"
			_hint.text = String(def.get("hint", ""))
			return
		_armed = &""
		b.text = label
		_hint.text = String(((def["run"]) as Callable).call()))
	b.mouse_entered.connect(_show_hint.bind(def))
	b.mouse_exited.connect(func() -> void:
		if _armed == id:
			_armed = &""
			b.text = label)
	row.add_child(b)
	_refreshers.append(func() -> void:
		if _armed != id:
			b.text = label)


func _build_key(row: HBoxContainer, def: Dictionary) -> void:
	var action: StringName = def["action"]
	var b := PixelButton.new()
	b.custom_minimum_size.x = 120
	b.pressed.connect(func() -> void:
		_capture = action
		_hint.text = String(def.get("hint", ""))
		refresh())
	row.add_child(b)
	_refreshers.append(func() -> void:
		b.text = "Press a key..." if _capture == action else Keybinds.key_name(action))


func _input(event: InputEvent) -> void:
	if _capture == &"" or not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if not k.pressed or k.echo:
		return
	get_viewport().set_input_as_handled()
	if k.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
		return
	var action: StringName = _capture
	_capture = &""
	if k.keycode == KEY_ESCAPE:
		refresh()
		return
	var swapped: StringName = Keybinds.set_key(action, k.keycode)
	_close_btn.text = "Close [%s]" % Keybinds.key_name(&"settings")
	if swapped != &"":
		_hint.text = "%s now uses %s's old key." % [Keybinds.label_for(swapped), Keybinds.label_for(action)]
	else:
		_hint.text = "%s is now %s." % [Keybinds.label_for(action), Keybinds.key_name(action)]
	refresh()


func _tag(on: bool, label: String) -> String:
	return ("> " if on else "  ") + label
