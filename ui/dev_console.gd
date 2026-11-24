class_name DevConsole
extends PanelContainer
## Dev console: a floating window over the game. Drag the title bar to move it, drag the corner to resize it,
## x or Esc closes it. The input has focus the moment it opens. Tab completes a command or its argument and lists
## the suggestions under the log; Up and Down recall history. Opens with the console key (default `, rebindable in
## Settings > Controls) only when SettingsRegistry.dev_tools_enabled(): a debug build, a --dev launch argument, or
## Settings > Data > Developer console. Commands: core/dev_commands.gd. This file adds the node-level ones (tp, pos,
## speed, weather, reset speed, reset weather, save, clear) and the window.

const GRIP: int = 10
const MIN_SIZE: Vector2 = Vector2(220.0, 120.0)
const DEFAULT_SIZE: Vector2 = Vector2(380.0, 190.0)
const EDGE_GAP: float = 6.0
const MAX_SUGGEST: int = 10
const HISTORY_MAX: int = 100

## Last place and size this session, relative to the HUD. A reopened console stays where it was put.
static var _saved: Rect2 = Rect2()
static var _history: PackedStringArray = PackedStringArray()

var cmds: DevCommands
var _sim: Sim
var _ctx: Dictionary = {}
var _title: PanelContainer
var _log: RichTextLabel
var _strip: RichTextLabel
var _line: LineEdit
var _grip: Control
var _hist_at: int = 0
var _dragging: bool = false
var _drag_off: Vector2 = Vector2.ZERO
var _resizing: bool = false
var _resize_from: Vector2 = Vector2.ZERO
var _resize_size: Vector2 = Vector2.ZERO
var _tab_list: PackedStringArray = PackedStringArray()
var _tab_at: int = -1
var _tab_text: String = ""


## Build the console under `parent`. ctx may hold: walker (Node2D), gate (Node2D), spawn (Vector2), pads (Dictionary id -> Node2D).
static func attach(parent: Control, sim: Sim, ctx: Dictionary = {}) -> DevConsole:
	var c := DevConsole.new()
	c.name = "DevConsole"
	c._ctx = ctx
	parent.add_child(c)
	c._build(sim)
	return c


func _build(sim: Sim) -> void:
	_sim = sim
	visible = false
	z_index = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	custom_minimum_size = MIN_SIZE
	add_theme_stylebox_override("panel", AsciiBox.make(AsciiBox.Kind.PANEL, 6.0, 4.0))
	cmds = DevCommands.new(sim)
	_register_extra()

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	add_child(v)

	_title = _make_title()
	v.add_child(_title)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.selection_enabled = true
	_log.focus_mode = Control.FOCUS_NONE
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.custom_minimum_size = Vector2(0.0, 40.0)
	_log.add_theme_color_override("default_color", RelicStyle.text)
	v.add_child(_log)

	_strip = RichTextLabel.new()
	_strip.bbcode_enabled = true
	_strip.autowrap_mode = TextServer.AUTOWRAP_OFF
	_strip.clip_contents = true
	_strip.scroll_active = false
	_strip.focus_mode = Control.FOCUS_NONE
	_strip.custom_minimum_size = Vector2(0.0, 14.0)
	_strip.add_theme_color_override("default_color", RelicStyle.dim)
	v.add_child(_strip)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	v.add_child(row)
	_line = LineEdit.new()
	_line.placeholder_text = "type a command, or help"
	_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line.add_theme_stylebox_override("normal", AsciiBox.make(AsciiBox.Kind.BUTTON, 6.0, 2.0))
	_line.add_theme_stylebox_override("focus", AsciiBox.make(AsciiBox.Kind.HOVER, 6.0, 2.0))
	_line.add_theme_color_override("font_color", RelicStyle.text)
	_line.add_theme_color_override("caret_color", RelicStyle.accent)
	_line.text_submitted.connect(_submit)
	_line.text_changed.connect(_on_text_changed)
	_line.gui_input.connect(_line_input)
	row.add_child(_line)

	_grip = Control.new()
	_grip.custom_minimum_size = Vector2(GRIP, GRIP)
	_grip.size_flags_vertical = Control.SIZE_SHRINK_END
	_grip.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	_grip.focus_mode = Control.FOCUS_NONE
	_grip.draw.connect(_draw_grip)
	_grip.gui_input.connect(_on_grip_input)
	Tip.bind(_grip, {"title": "Resize", "body": "Drag to make the console bigger or smaller."})
	row.add_child(_grip)
	_grip.queue_redraw()

	say("Dev console. Type help for the commands. [%s] or Esc closes it." % Keybinds.key_name(&"console"), &"hint")
	get_viewport().size_changed.connect(_fit)
	_refresh_strip()


func _make_title() -> PanelContainer:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", AsciiBox.make(AsciiBox.Kind.BUTTON, 4.0, 1.0))
	bar.mouse_default_cursor_shape = Control.CURSOR_MOVE
	bar.focus_mode = Control.FOCUS_NONE
	bar.gui_input.connect(_on_title_input)
	Tip.bind(bar, {"title": "Dev Console", "body": "Drag to move the window. Esc closes it.",
		"hint": "Type help for the command list."})
	var h := HBoxContainer.new()
	bar.add_child(h)
	var label := Label.new()
	label.text = "Dev Console"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", RelicStyle.accent)
	h.add_child(label)
	var btn_close := Button.new()
	btn_close.text = "x"
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.add_theme_stylebox_override("normal", AsciiBox.make(AsciiBox.Kind.BUTTON, 3.0, 0.0))
	btn_close.add_theme_stylebox_override("hover", AsciiBox.make(AsciiBox.Kind.HOVER, 3.0, 0.0))
	btn_close.add_theme_stylebox_override("pressed", AsciiBox.make(AsciiBox.Kind.PRESSED, 3.0, 0.0))
	btn_close.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn_close.add_theme_color_override("font_color", RelicStyle.text)
	btn_close.add_theme_color_override("font_hover_color", RelicStyle.accent)
	btn_close.pressed.connect(close)
	Tip.bind(btn_close, {"title": "Close", "body": "Hides the console. Its place is kept.",
		"hint": "Click to close!", "hint_color": RelicStyle.accent})
	h.add_child(btn_close)
	return bar


func _register_extra() -> void:
	cmds.register("tp", "move the walker to a spot, the gate, a pad, an area or a zone", _cmd_tp,
		Callable(self, "_tp_words"), "World", "tp [x y | gate | start | pad <id> | area <id> | zone <id>]")
	cmds.register("pos", "print the walker's position", _cmd_pos, Callable(), "World", "pos")
	cmds.register("speed", "game speed from 0.1x to 20x. Alone, shows the current speed", _cmd_speed,
		Callable(), "Time and weather", "speed [x]")
	cmds.register("weather", "force clear or rain, or leave it to the sky's own rhythm", _cmd_weather,
		Callable(self, "_weather_words"), "Time and weather", "weather [clear | rain | auto]")
	cmds.register("reset speed", "back to 1x", _cmd_reset_speed, Callable(), "Dev", "reset speed")
	cmds.register("reset weather", "back to the sky's own weather", _cmd_reset_weather, Callable(), "Dev", "reset weather")
	cmds.register("save", "save the game now", _cmd_save, Callable(), "Console", "save")
	cmds.register("clear", "clear this log", _cmd_clear, Callable(), "Console", "clear")


func _walker() -> Node2D:
	return _ctx.get("walker") as Node2D


func _move_walker(to: Vector2, msg: String) -> String:
	var w: Node2D = _walker()
	if w == null:
		return "No walker to move."
	w.position = to
	w.set("_has_target", false)   # drop any click-to-walk destination
	return msg


func _cmd_tp(args: PackedStringArray) -> String:
	if args.size() >= 2 and args[0].to_lower() == "zone":
		return cmds.run("zone %s" % args[1])   # the zone change loads its scene and places the walker there
	if args.size() >= 2 and args[0].to_lower() == "area":
		return _tp_area(args[1])
	if _walker() == null:
		return "No walker to move."
	var to: Vector2 = Vector2.INF
	if args.size() >= 2 and args[0].is_valid_float() and args[1].is_valid_float():
		to = Vector2(args[0].to_float(), args[1].to_float())
	elif not args.is_empty() and args[0].to_lower() == "gate" and _ctx.get("gate") is Node2D:
		to = (_ctx["gate"] as Node2D).position + Vector2(0.0, 14.0)
	elif not args.is_empty() and args[0].to_lower() == "start" and _ctx.has("spawn"):
		to = _ctx["spawn"] as Vector2
	elif args.size() >= 2 and args[0].to_lower() == "pad":
		var pads: Dictionary = _ctx.get("pads", {})
		var pad: Node2D = pads.get(StringName(args[1])) as Node2D
		if pad == null:
			return "No pad '%s'. Pads here: %s" % [args[1], ", ".join(_names(pads))]
		to = pad.position + Vector2(0.0, 12.0)
	if to == Vector2.INF:
		return "Usage: tp <x> <y> | tp gate | tp start | tp pad <id> | tp area <id> | tp zone <id>"
	return _move_walker(to, "Walker at %d, %d." % [roundi(to.x), roundi(to.y)])


## Walk to the first pad of an area that is on screen. An area in another zone needs that zone first.
func _tp_area(id: String) -> String:
	var area: AreaDef = _sim.area_defs.get(StringName(id.to_lower())) as AreaDef
	if area == null:
		return "No area '%s'. Areas: %s" % [id, ", ".join(_names(_sim.area_defs))]
	var pads: Dictionary = _ctx.get("pads", {})
	for bid: String in area.pad_buttons:
		var pad: Node2D = pads.get(StringName(bid)) as Node2D
		if pad != null:
			return _move_walker(pad.position + Vector2(0.0, 12.0), "Walker at %s." % area.display_name)
	return "%s is in zone %s. Get there first: zone %s." % [area.display_name, area.zone, area.zone]


func _tp_words(typed: PackedStringArray) -> PackedStringArray:
	if typed.is_empty():
		return PackedStringArray(DevCommands.TP_WORDS)
	if typed.size() == 1:
		var first: String = typed[0].to_lower()
		if first == "pad":
			return _names(_ctx.get("pads", {}))
		if first == "area":
			return _names(_sim.area_defs)
		if first == "zone":
			return _names(_sim.zone_defs)
	return PackedStringArray()


func _cmd_pos(_args: PackedStringArray) -> String:
	var w: Node2D = _walker()
	return "No walker." if w == null else "Walker at %d, %d." % [roundi(w.position.x), roundi(w.position.y)]


func _cmd_speed(args: PackedStringArray) -> String:
	if args.is_empty():
		return "Speed is %.2fx. Usage: speed <x>, e.g. speed 2 or speed 0.5x" % Engine.time_scale
	var word: String = args[0].to_lower().trim_suffix("x")
	if not word.is_valid_float():
		return "Usage: speed <x>, e.g. speed 2 or speed 0.5x"
	Engine.time_scale = clampf(word.to_float(), 0.1, 20.0)
	return "Speed %.2fx." % Engine.time_scale


func _cmd_reset_speed(_args: PackedStringArray) -> String:
	Engine.time_scale = 1.0
	return "Speed 1.00x."


## Weather is the sky's own rhythm unless forced: SkyCycle.debug_rain < 0 is auto, 0 clear, rain_max rain.
func _cmd_weather(args: PackedStringArray) -> String:
	if args.is_empty():
		return _weather_status()
	var level: float = DevCommands.weather_level(args[0])
	if level <= -2.0:
		return "Usage: weather [clear | rain | auto]"
	if level < 0.0:
		SkyCycle.debug_rain = -1.0
	elif level > 0.5:
		SkyCycle.debug_rain = _rain_max()
	else:
		SkyCycle.debug_rain = 0.0
	return _weather_status()


func _cmd_reset_weather(_args: PackedStringArray) -> String:
	SkyCycle.debug_rain = -1.0
	return _weather_status()


func _weather_status() -> String:
	var d: float = SkyCycle.debug_rain
	if d < 0.0:
		return "Weather follows the sky."
	return "Weather is forced to rain." if d > 0.0 else "Weather is forced to clear."


func _rain_max() -> float:
	var cfg: SkyConfig = load("res://content/config/sky.tres") as SkyConfig
	return cfg.rain_max if cfg != null else 0.6


func _weather_words(typed: PackedStringArray) -> PackedStringArray:
	return PackedStringArray(DevCommands.WEATHER_WORDS) if typed.is_empty() else PackedStringArray()


func _cmd_save(_args: PackedStringArray) -> String:
	var s: Node = get_node_or_null("/root/Save")
	return "Saved." if s != null and bool(s.call("save_game")) else "Save failed."


func _cmd_clear(_args: PackedStringArray) -> String:
	_log.clear()
	return ""


static func _names(d: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for k: Variant in d:
		out.append(String(k))
	out.sort()
	return out


# ---------------------------------------------------------------- window geometry

## The HUD this window floats over. Falls back to the viewport when the parent has no size yet.
func _bounds() -> Vector2:
	var p: Control = get_parent_control()
	var b: Vector2 = p.size if p != null else Vector2.ZERO
	if b.x < 2.0 or b.y < 2.0:
		b = get_viewport_rect().size
	return b


## The mouse in the parent's coordinates, so drag and resize stay right under any scale.
func _local_mouse() -> Vector2:
	var p: Control = get_parent_control()
	if p == null:
		return get_global_mouse_position()
	return p.get_global_transform_with_canvas().affine_inverse() * get_global_mouse_position()


## Keep the window inside the HUD: never below its minimum size, never off the edge.
func _fit() -> void:
	var b: Vector2 = _bounds()
	var s: Vector2 = Vector2(
		clampf(size.x, MIN_SIZE.x, maxf(MIN_SIZE.x, b.x - EDGE_GAP)),
		clampf(size.y, MIN_SIZE.y, maxf(MIN_SIZE.y, b.y - EDGE_GAP)))
	size = s
	position = Vector2(
		clampf(position.x, 0.0, maxf(0.0, b.x - s.x)),
		clampf(position.y, 0.0, maxf(0.0, b.y - s.y)))


func _place() -> void:
	if _saved.size == Vector2.ZERO:
		size = DEFAULT_SIZE
		position = Vector2(EDGE_GAP, _bounds().y - DEFAULT_SIZE.y - EDGE_GAP)
	else:
		size = _saved.size
		position = _saved.position
	_fit()


func _remember() -> void:
	_saved = Rect2(position, size)


func _on_title_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_dragging = true
			_drag_off = _local_mouse() - position
		elif _dragging:
			_dragging = false
			_remember()
		_title.accept_event()
		return
	if _dragging and event is InputEventMouseMotion:
		position = _local_mouse() - _drag_off
		_fit()
		_title.accept_event()


func _on_grip_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_resizing = true
			_resize_from = _local_mouse()
			_resize_size = size
		elif _resizing:
			_resizing = false
			_remember()
		_grip.accept_event()
		return
	if _resizing and event is InputEventMouseMotion:
		size = _resize_size + (_local_mouse() - _resize_from)
		_fit()
		_grip.accept_event()


## Three pixel dots in the corner, in the zone's edge colour.
func _draw_grip() -> void:
	var c: Color = RelicStyle.edge
	for i in 3:
		var o: float = 3.0 * float(i)
		_grip.draw_rect(Rect2(GRIP - 2.0 - o, GRIP - 2.0, 2.0, 2.0), c)
		_grip.draw_rect(Rect2(GRIP - 2.0, GRIP - 2.0 - o, 2.0, 2.0), c)


# ---------------------------------------------------------------- open, close, input

func is_open() -> bool:
	return visible


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if not SettingsRegistry.dev_tools_enabled():
		return
	visible = true
	_place()
	var w: Node2D = _walker()
	if w != null:
		w.set_process(false)   # typing WASD must not walk
	_refresh_strip()
	_line.grab_focus()


func close() -> void:
	if not visible:
		return
	_remember()
	visible = false
	_dragging = false
	_resizing = false
	_line.release_focus()
	var w: Node2D = _walker()
	if w != null:
		w.set_process(true)


func _input(event: InputEvent) -> void:
	if Keybinds.matches(&"console", event):
		if SettingsRegistry.dev_tools_enabled():
			toggle()
			get_viewport().set_input_as_handled()
	elif visible and event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _line_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed:
		return
	var k: Key = key_event.keycode
	if k == KEY_TAB:
		_tab()
		_line.accept_event()
	elif k == KEY_UP or k == KEY_DOWN:
		if _history.is_empty():
			return
		if k == KEY_UP:
			_hist_at = maxi(0, _hist_at - 1)
		else:
			_hist_at = mini(_history.size(), _hist_at + 1)
		_line.text = "" if _hist_at >= _history.size() else _history[_hist_at]
		_line.caret_column = _line.text.length()
		_tab_list = PackedStringArray()
		_refresh_strip()
		_line.accept_event()


## Tab: complete the word under the caret. One match fills it in with a space after. Several matches fill in their
## common start first; a second Tab cycles through them.
func _tab() -> void:
	var raw: String = _line.text
	if _tab_list.is_empty() or raw != _tab_text:
		_tab_list = cmds.complete(raw)
		_tab_at = -1
		if _tab_list.is_empty():
			_refresh_strip()
			return
		if _tab_list.size() == 1:
			_set_last_word(_tab_list[0], true)
			_tab_list = PackedStringArray()
			_refresh_strip()
			return
		var word: String = raw.substr(raw.rfind(" ") + 1)
		var common: String = _common_prefix(_tab_list)
		if common.length() > word.length():
			_set_last_word(common, false)
			_refresh_strip()
			return
	_tab_at = (_tab_at + 1) % _tab_list.size()
	_set_last_word(_tab_list[_tab_at], false)
	_refresh_strip()


func _set_last_word(word: String, space: bool) -> void:
	var raw: String = _line.text
	_line.text = raw.substr(0, raw.rfind(" ") + 1) + word + (" " if space else "")
	_line.caret_column = _line.text.length()
	_tab_text = _line.text


static func _common_prefix(words: PackedStringArray) -> String:
	var p: String = words[0]
	for w: String in words:
		while not w.begins_with(p):
			p = p.left(-1)
	return p


func _on_text_changed(_new_text: String) -> void:
	_refresh_strip()


## The line under the log: the matching words (the one Tab would pick is lit), or the usage of the command typed.
func _refresh_strip() -> void:
	if _strip == null:
		return
	var raw: String = _line.text
	var list: PackedStringArray = cmds.complete(raw)
	var parts: PackedStringArray = raw.strip_edges().split(" ", false)
	var text: String = ""
	if not list.is_empty():
		var shown: PackedStringArray = PackedStringArray()
		for i in mini(list.size(), MAX_SUGGEST):
			var w: String = _esc(list[i])
			shown.append("[color=#%s]%s[/color]" % [_hex(RelicStyle.accent), w] if i == _tab_at else w)
		text = "Tab: " + "   ".join(shown)
	elif not parts.is_empty() and cmds.usage_of(parts[0]) != "":
		text = "[color=#%s]%s[/color]" % [_hex(RelicStyle.accent), _esc(cmds.usage_of(parts[0]))]
	_strip.text = text


func _submit(text: String) -> void:
	_line.clear()
	_tab_list = PackedStringArray()
	var t: String = text.strip_edges()
	if t.is_empty():
		_refresh_strip()
		return
	if _history.is_empty() or _history[_history.size() - 1] != t:
		_history.append(t)
		while _history.size() > HISTORY_MAX:
			_history.remove_at(0)
	_hist_at = _history.size()
	say("> " + t, &"echo")
	var reply: String = cmds.run(t)
	for line: String in reply.split("\n"):
		if not line.is_empty():
			say(line, DevCommands.reply_kind(line))
	if cmds.needs_reload:
		cmds.needs_reload = false
		var s: Node = get_node_or_null("/root/Save")
		if s != null:
			s.call("save_game")
		get_tree().reload_current_scene()
	_refresh_strip()
	_line.grab_focus()


## Coloured log line. Echo is bright, ok is green, usage and hints are dim, errors and warnings are the accent
## colour with a "!" in front. ("[" is escaped so the text is never read as BBCode.)
func say(text: String, kind: StringName = &"ok") -> void:
	var colour: Color = RelicStyle.good
	match kind:
		&"echo":
			colour = RelicStyle.text
		&"hint", &"usage":
			colour = RelicStyle.dim
		&"error", &"warn":
			colour = RelicStyle.accent
	var body: String = _esc(text)
	if kind == &"error":
		body = "! " + body
	_log.append_text("[color=#%s]%s[/color]\n" % [_hex(colour), body])


static func _esc(s: String) -> String:
	return s.replace("[", "[lb]")


static func _hex(c: Color) -> String:
	return c.to_html(false)
