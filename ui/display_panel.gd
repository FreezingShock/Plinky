class_name DisplayPanel
extends PanelContainer
## The settings menu (F10 or the bottom-bar Settings button). Tabs, rows and values all come from
## SettingsRegistry (ui/settings/settings_registry.gd), so a new setting is one register() call, not panel code.
## Class name and bind/open/close/refresh are kept from the old display panel so main.gd and the HUD still wire it.

## Emitted by the Data tab's Send feedback row. main.gd opens the feedback panel.
signal feedback_requested

const TAB_WIDTH: float = 430.0
const BODY_HEIGHT: float = 196.0
const LABEL_WIDTH: float = 126.0
## How far a sub row (an option under a master row, such as the two Reduce Motion options) is pushed in.
const SUB_INDENT: float = 14.0
## One colour per tab, from the same fixed stat colours the gallery cards wear. New tabs fall back to PAPER.
const TAB_COLORS: Dictionary = {
	"Audio": Color("6fd6e8"), "Display": Color("55aaff"), "Gameplay": Color("f2c94c"),
	"Access": Color("7be08a"), "Controls": Color("c77dff"), "Data": Color("f08fb0"),
}

var _win: Window
var _tab: String = "Audio"
var _tab_buttons: Dictionary = {}     # tab name -> PixelButton
var _body: VBoxContainer
var _scroll: ScrollContainer
var _hint: Label
var _title: Label
var _refreshers: Array[Callable] = []
var _capture: StringName = &""        # key action waiting for a keypress
var _cap_mod: int = 0                 # a modifier key held down while a key is being captured
var _armed: StringName = &""          # confirm action pressed once


func bind(win: Window) -> void:
	_win = win
	SettingsRegistry.register({
		"id": &"send_feedback", "tab": "Data", "label": "Send feedback", "kind": SettingsRegistry.Kind.ACTION,
		"hint": "Opens the feedback form. Notes are saved on this computer.", "run": _request_feedback,
	})
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)

	_title = Label.new()
	_title.theme_type_variation = &"TitleLabel"
	_title.text = "Settings"
	v.add_child(_title)
	v.add_child(PanelDivider.new(2))

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 2)
	v.add_child(tab_row)
	for t in SettingsRegistry.tabs():
		var b := PixelButton.new()
		b.text = t
		b.pressed.connect(show_tab.bind(t))
		tab_row.add_child(b)
		_tab_buttons[t] = b
		_paint_tab(b, tab_color(t))

	_scroll = ScrollContainer.new()
	var scroll: ScrollContainer = _scroll
	scroll.custom_minimum_size = Vector2(TAB_WIDTH, BODY_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true   # stick or arrows can reach rows below the fold
	v.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 4)
	scroll.add_child(_body)

	v.add_child(PanelDivider.new(2))
	_hint = Label.new()
	_hint.custom_minimum_size = Vector2(TAB_WIDTH, 28)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	_hint.add_theme_color_override("font_color", RelicStyle.dim)
	v.add_child(_hint)


	_win.size_changed.connect(_on_window_changed)
	show_tab(_tab)


func _request_feedback() -> String:
	feedback_requested.emit()
	return ""


func open() -> void:
	show_tab(_tab)
	visible = true
	reset_size()
	await get_tree().process_frame
	# Centre over the frame, which is the parent (the HUD is the frame's size).
	position = ((get_parent_area_size() - size) * 0.5).floor()


func close() -> void:
	reset_capture()
	visible = false


## Drop any half-finished key capture. The menu router calls this, then plays the close wipe.
func reset_capture() -> void:
	_capture = &""
	_armed = &""


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
	var col: Color = tab_color(tab)
	add_theme_stylebox_override("panel", AsciiBox.panel(col.darkened(0.2)))
	_title.add_theme_color_override("font_color", col)
	for def in SettingsRegistry.entries(tab):
		_body.add_child(_make_card(_make_row(def, col), col))
	_wire_focus()
	_hint.text = ""
	for t: String in _tab_buttons:
		var tb: PixelButton = _tab_buttons[t]
		tb.text = _tag(t == tab, t)
		tb.add_theme_color_override("font_color", RelicStyle.text if t == tab else tab_color(t))
	refresh()


## Pad and keyboard focus. Godot's geometry search stalls inside the scroll area, so Up and Down are wired
## explicitly: tab -> row 1 -> ... -> last row -> tab, and back. Every control in a row shares its row's links.
func _wire_focus() -> void:
	var rows: Array = []   # Array of Array[Control], one per row, in order
	for row: Node in _body.get_children():
		var ctl: Array[Control] = []
		_collect_focusable(row, ctl)
		if not ctl.is_empty():
			rows.append(ctl)
			for c: Control in ctl:
				c.focus_entered.connect(_scroll.ensure_control_visible.bind(c))
	for t: String in _tab_buttons:
		var b: PixelButton = _tab_buttons[t]
		b.focus_neighbor_bottom = b.get_path_to((rows[0] as Array)[0]) if not rows.is_empty() else b.get_path_to(b)
	link_rows(rows, _tab_buttons[_tab], _tab_buttons[_tab])   # the X closes; the last row wraps back to the tabs


## Link rows (Array of Array[Control]) top to bottom. `above` is reached from the first row going up and
## `below` from the last row going down.
static func link_rows(rows: Array, above: Control, below: Control) -> void:
	for i in rows.size():
		var up: Control = above if i == 0 else (rows[i - 1] as Array)[0]
		var down: Control = below if i == rows.size() - 1 else (rows[i + 1] as Array)[0]
		for c: Control in rows[i]:
			c.focus_neighbor_top = c.get_path_to(up)
			c.focus_neighbor_bottom = c.get_path_to(down)


func _collect_focusable(n: Node, out: Array[Control]) -> void:
	for ch: Node in n.get_children():
		if ch is Control and (ch as Control).focus_mode == Control.FOCUS_ALL and not (ch is BaseButton and (ch as BaseButton).disabled):
			out.append(ch)
		_collect_focusable(ch, out)


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

## Every row sits on its own small card with a dim outline in the tab colour, like the gallery's stat cards.
func _make_card(row: Control, col: Color) -> Control:
	var card := PanelContainer.new()
	var box: AsciiBox = AsciiBox.make(AsciiBox.Kind.BUTTON, 5.0, 3.0)
	box.edge_override = col.darkened(0.45)
	card.add_theme_stylebox_override("panel", box)
	card.add_child(row)
	return card


static func tab_color(tab: String) -> Color:
	return TAB_COLORS.get(tab, StatStyle.PAPER) as Color


## Title Case for display: every word starts with a capital. Registry strings stay as written, so rows other
## threads add are covered too. Keeps words already containing capitals or digits (VSync, FPS) as they are.
static func title_case(s: String) -> String:
	var out: PackedStringArray = PackedStringArray()
	for w: String in s.split(" "):
		out.append(w if w == "" or w != w.to_lower() else w.substr(0, 1).to_upper() + w.substr(1))
	return " ".join(out)


## Tab buttons wear their tab colour: dim outline at rest, brighter on hover, solid when picked.
static func _paint_tab(b: PixelButton, col: Color) -> void:
	var rest: AsciiBox = AsciiBox.make(AsciiBox.Kind.BUTTON, AsciiBox.BUTTON_PAD.x, AsciiBox.BUTTON_PAD.y)
	rest.edge_override = col.darkened(0.35)
	var lit: AsciiBox = AsciiBox.make(AsciiBox.Kind.SELECT, AsciiBox.BUTTON_PAD.x, AsciiBox.BUTTON_PAD.y)
	lit.edge_override = col.lightened(0.2)
	var down: AsciiBox = AsciiBox.make(AsciiBox.Kind.PRESSED, AsciiBox.BUTTON_PAD.x, AsciiBox.BUTTON_PAD.y)
	down.edge_override = col
	b.add_theme_stylebox_override("normal", rest)
	b.add_theme_stylebox_override("hover", lit)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", col.lightened(0.2))


func _make_row(def: Dictionary, col: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var kind: int = int(def["kind"])
	# A "sub" row sits under its master row: indented, with its label narrower so the controls line up.
	var indent: float = SUB_INDENT if bool(def.get("sub", false)) else 0.0
	if indent > 0.0:
		var gap := Control.new()
		gap.custom_minimum_size.x = indent
		row.add_child(gap)
	if kind != SettingsRegistry.Kind.ACTION:
		var l := Label.new()
		l.text = title_case(String(def["label"]))
		l.add_theme_color_override("font_color", col)
		# The gap and its separator take the indent and 4 px, so the controls still line up with the rows above.
		l.custom_minimum_size.x = LABEL_WIDTH - indent - 4.0 if indent > 0.0 else LABEL_WIDTH
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
	if String(def.get("hint", "")) != "":
		Tip.bind_all(row, {"title": title_case(String(def["label"])) if kind != SettingsRegistry.Kind.ACTION else "", "body": String(def["hint"])})
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
	var label: String = title_case(String(def["label"]))
	b.pressed.connect(func() -> void:
		if bool(def.get("confirm", false)) and _armed != id:
			_armed = id
			b.text = "Sure? Press Again"
			_hint.text = String(def.get("hint", ""))
			return
		_armed = &""
		b.text = label
		_hint.text = String(((def["run"]) as Callable).call()))
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


func _process(_delta: float) -> void:
	# A waiting rebind owns the keys, so WASD must not walk the walker while it waits.
	PadInput.key_capture = visible and _capture != &""


func _exit_tree() -> void:
	PadInput.key_capture = false


func _input(event: InputEvent) -> void:
	if visible and _capture != &"" and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		# Rebinding waits for a keyboard key. The pad is ignored, except B, which cancels.
		if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
			_capture = &""
			refresh()
		get_viewport().set_input_as_handled()
		return
	if visible and _capture == &"":
		# Pad shoulders flip tabs. Focus stays on a tab button so the pad never gets stranded.
		var dir: int = int(event.is_action_pressed(&"plinky_tab_next")) - int(event.is_action_pressed(&"plinky_tab_prev"))
		if dir != 0:
			var names: PackedStringArray = SettingsRegistry.tabs()
			show_tab(names[posmod(names.find(_tab) + dir, names.size())])
			(_tab_buttons[_tab] as PixelButton).grab_focus()
			get_viewport().set_input_as_handled()
			return
	if _capture == &"" or not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if k.echo:
		return
	get_viewport().set_input_as_handled()
	if Keybinds.is_modifier(int(k.keycode)):
		# A modifier alone (Shift, Ctrl) binds when it is released with no other key pressed in between;
		# pressed with another key it becomes part of that combo (Shift+C).
		if k.pressed:
			_cap_mod = int(k.keycode)
		elif _cap_mod == int(k.keycode):
			_finish_capture(_cap_mod)
		return
	if not k.pressed:
		return
	if k.keycode == KEY_ESCAPE:
		_capture = &""
		_cap_mod = 0
		refresh()
		return
	_finish_capture(Keybinds.code_of(k))


func _finish_capture(code: int) -> void:
	var action: StringName = _capture
	_capture = &""
	_cap_mod = 0
	var swapped: StringName = Keybinds.set_key(action, code)
	if swapped != &"":
		_hint.text = "%s now uses %s's old key." % [Keybinds.label_for(swapped), Keybinds.label_for(action)]
	else:
		_hint.text = "%s is now %s." % [Keybinds.label_for(action), Keybinds.key_name(action)]
	refresh()


func _tag(on: bool, label: String) -> String:
	return ("> " if on else "  ") + label
