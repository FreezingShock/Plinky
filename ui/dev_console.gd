class_name DevConsole
extends PanelContainer
## Dev console. Opens with the console key (default ` , rebindable in Settings > Controls), only when
## SettingsRegistry.dev_tools_enabled(): a debug build, a --dev launch argument, or Settings > Data > Developer console.
## Game commands live in core/dev_commands.gd. This file adds the node-level ones (tp, speed, save) and the UI.

const LOG_LINES: int = 80
const HEIGHT: float = 156.0

var cmds: DevCommands
var _ctx: Dictionary = {}
var _log: RichTextLabel
var _line: LineEdit
var _history: PackedStringArray = PackedStringArray()
var _hist_at: int = 0


## Build the console under `parent`. ctx may hold: walker (Node2D), gate (Node2D), spawn (Vector2), pads (Dictionary id -> Node2D).
static func attach(parent: Control, sim: Sim, ctx: Dictionary = {}) -> DevConsole:
	var c := DevConsole.new()
	c.name = "DevConsole"
	c._ctx = ctx
	parent.add_child(c)
	c._build(sim)
	return c


func _build(sim: Sim) -> void:
	visible = false
	z_index = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size.y = HEIGHT
	add_theme_stylebox_override("panel", AsciiBox.make(AsciiBox.Kind.PANEL, 8.0, 6.0))
	cmds = DevCommands.new(sim)
	_register_extra()

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	add_child(v)
	_log = RichTextLabel.new()
	_log.custom_minimum_size = Vector2(0, HEIGHT - 40.0)
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	_log.selection_enabled = true
	_log.add_theme_color_override("default_color", RelicStyle.text)
	v.add_child(_log)
	_line = LineEdit.new()
	_line.placeholder_text = "type help"
	_line.add_theme_stylebox_override("normal", AsciiBox.make(AsciiBox.Kind.BUTTON, 6.0, 2.0))
	_line.add_theme_stylebox_override("focus", AsciiBox.make(AsciiBox.Kind.HOVER, 6.0, 2.0))
	_line.add_theme_color_override("font_color", RelicStyle.text)
	_line.add_theme_color_override("caret_color", RelicStyle.accent)
	_line.text_submitted.connect(_submit)
	_line.gui_input.connect(_line_input)
	v.add_child(_line)
	say("Dev console. Type help for commands. [%s] closes." % Keybinds.key_name(&"console"))


func _register_extra() -> void:
	cmds.register("tp", "move the walker: tp <x y | gate | start | pad id>", _cmd_tp)
	cmds.register("pos", "print the walker's position", _cmd_pos)
	cmds.register("speed", "game speed: speed <x>, 0.1 to 20", _cmd_speed)
	cmds.register("save", "save now", _cmd_save)
	cmds.register("clear", "clear this log", _cmd_clear)


func _walker() -> Node2D:
	return _ctx.get("walker") as Node2D


func _cmd_tp(args: PackedStringArray) -> String:
	var w: Node2D = _walker()
	if w == null:
		return "No walker to move."
	var to: Vector2 = Vector2.INF
	if args.size() >= 2 and args[0].is_valid_float() and args[1].is_valid_float():
		to = Vector2(args[0].to_float(), args[1].to_float())
	elif not args.is_empty() and args[0] == "gate" and _ctx.get("gate") is Node2D:
		to = (_ctx["gate"] as Node2D).position + Vector2(0, 14)
	elif not args.is_empty() and args[0] == "start" and _ctx.has("spawn"):
		to = _ctx["spawn"] as Vector2
	elif args.size() >= 2 and args[0] == "pad":
		var pads: Dictionary = _ctx.get("pads", {})
		var pad: Node2D = pads.get(StringName(args[1])) as Node2D
		if pad == null:
			return "No pad '%s'. Pads: %s" % [args[1], ", ".join(PackedStringArray(pads.keys().map(func(k: Variant) -> String: return str(k))))]
		to = pad.position + Vector2(0, 12)
	if to == Vector2.INF:
		return "Usage: tp <x> <y> | tp gate | tp start | tp pad <id>"
	w.position = to
	w.set("_has_target", false)   # drop any click-to-walk destination
	return "Walker at %d, %d." % [roundi(to.x), roundi(to.y)]


func _cmd_pos(_args: PackedStringArray) -> String:
	var w: Node2D = _walker()
	return "No walker." if w == null else "Walker at %d, %d." % [roundi(w.position.x), roundi(w.position.y)]


func _cmd_speed(args: PackedStringArray) -> String:
	if args.is_empty() or not args[0].is_valid_float():
		return "Speed is %.2f. Usage: speed <x>" % Engine.time_scale
	Engine.time_scale = clampf(args[0].to_float(), 0.1, 20.0)
	return "Speed %.2fx." % Engine.time_scale


func _cmd_save(_args: PackedStringArray) -> String:
	var s: Node = get_node_or_null("/root/Save")
	return "Saved." if s != null and bool(s.call("save_game")) else "Save failed."


func _cmd_clear(_args: PackedStringArray) -> String:
	_log.clear()
	return ""


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
	var w: Node2D = _walker()
	if w != null:
		w.set_process(false)   # typing WASD must not walk
	_line.grab_focus()


func close() -> void:
	visible = false
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
	if not (event is InputEventKey and (event as InputEventKey).pressed) or _history.is_empty():
		return
	var k: Key = (event as InputEventKey).keycode
	if k == KEY_UP:
		_hist_at = maxi(0, _hist_at - 1)
		_line.text = _history[_hist_at]
		_line.caret_column = _line.text.length()
		_line.accept_event()
	elif k == KEY_DOWN:
		_hist_at = mini(_history.size(), _hist_at + 1)
		_line.text = "" if _hist_at >= _history.size() else _history[_hist_at]
		_line.caret_column = _line.text.length()
		_line.accept_event()


func _submit(text: String) -> void:
	_line.clear()
	var t: String = text.strip_edges()
	if t.is_empty():
		return
	_history.append(t)
	_hist_at = _history.size()
	say("> " + t)
	var reply: String = cmds.run(t)
	if not reply.is_empty():
		say(reply)
	if cmds.needs_reload:
		cmds.needs_reload = false
		var s: Node = get_node_or_null("/root/Save")
		if s != null:
			s.call("save_game")
		get_tree().reload_current_scene()
	_line.grab_focus()


func say(text: String) -> void:
	_log.append_text(text.replace("[", "[lb]") + "\n")
