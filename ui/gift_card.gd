class_name GiftCard
extends Button
## One gift in the Upgrades gallery. The whole card is the buy button. Its outline says what you can do with it: green when
## you can pay for the next level, red (with a dim fill) when you cannot, a plain dim frame while it is locked, a gold frame
## when it is maxed. Layout and text come from an UpgradeText.state() dictionary, so this node holds no game rules.
##
## Hold the card (mouse, Enter/Space or the pad's confirm button) to keep buying, faster the longer you hold (see HoldRepeat).
## Repeats stop the moment the next level cannot be paid for, and play a light version of the animation.
##
## Buying plays: the card pops, a few pixel sparks leave its centre, the cost flies off toward the balance in the header,
## the numbers tick up in steps, the newest pip pops, and a rising click. Reduce motion / reduce flashing skip the motion
## and keep the sound.

signal buy_pressed(attr_id: StringName)

const CARD_SIZE: Vector2 = Vector2(176.0, 72.0)
const PAD: Vector2 = Vector2(8.0, 6.0)
const RED: Color = Color("#d9604c")   ## no red in the palette roles; fixed like the rarity colours
const TICK_STEPS: int = 8
const FLY_SECONDS: float = 0.55
const SPARKS: int = 7
const SPARK_LIFE: float = 0.5
const SPARK_GRAVITY: float = 150.0
const PAPER_SPARK: Color = Color("fff1c8")

var attr_id: StringName
var fly_target: Callable = Callable()   ## returns the global point the cost flies toward

var _def: AttributeDef
var _state: Dictionary = {}
var _icon: TextureRect
var _lock: LockIcon
var _name: Label
var _level: Label
var _delta: RichTextLabel
var _unit: Label
var _pips: PipBar
var _cost: Label
var _hold: HoldRepeat = HoldRepeat.new()
var _skip_pressed: bool = false   ## the press already bought on button_down, so the matching `pressed` must not buy again
var _ticking: bool = false
var _delta_text: String = ""
var _style_key: String = ""
var _sparks: Array[Dictionary] = []


## True when motion is off (Reduce motion or Reduce flashing). Sound still plays.
static func calm() -> bool:
	return MeadowLife.reduce_motion or FxConfig.reduce_flashing


func setup(a: AttributeDef) -> void:
	_def = a
	attr_id = a.id
	text = ""
	custom_minimum_size = CARD_SIZE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())   # the focus ring is drawn in _draw, like PixelButton
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = PAD.x
	col.offset_top = PAD.y
	col.offset_right = -PAD.x
	col.offset_bottom = -PAD.y
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var slot := Control.new()   # the icon, or the padlock while locked, share one slot
	slot.custom_minimum_size = Vector2(16, 16)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(slot)
	_icon = TextureRect.new()
	_icon.texture = load("res://assets/icons/%s.png" % StatIndex.attr_icon(a)) as Texture2D
	_icon.custom_minimum_size = Vector2(16, 16)
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(_icon)
	_lock = LockIcon.new()
	_lock.visible = false
	slot.add_child(_lock)
	_name = Label.new()
	_name.text = a.display_name
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.clip_text = true
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_name)
	_level = Label.new()
	_level.add_theme_color_override("font_color", RelicStyle.soft())
	_level.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_level)
	_delta = RichTextLabel.new()
	_delta.bbcode_enabled = true
	_delta.fit_content = true
	_delta.scroll_active = false
	_delta.autowrap_mode = TextServer.AUTOWRAP_OFF
	_delta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_delta.add_theme_color_override("default_color", RelicStyle.text)
	col.add_child(_delta)
	_unit = Label.new()
	_unit.clip_text = true
	_unit.add_theme_color_override("font_color", RelicStyle.soft())
	_unit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_unit)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bottom)
	_pips = PipBar.new()
	_pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(_pips)
	_cost = Label.new()
	_cost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_cost)
	pressed.connect(_on_pressed)
	button_down.connect(_on_down)
	button_up.connect(_hold.end)
	focus_exited.connect(_hold.end)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_hold.end())
	set_process(false)


func _draw() -> void:
	for s: Dictionary in _sparks:
		var age: float = float(s["age"])
		var u: float = age / float(s["life"])
		if u > 0.7 and int(age * 40.0) % 2 == 0:
			continue   # the last part of a spark blinks out, pixel-art style
		var sz: float = 2.0 if u < 0.3 else 1.0
		draw_rect(Rect2((s["pos"] as Vector2).round(), Vector2(sz, sz)), s["col"] as Color)
	if has_focus():
		PadInput.draw_focus_ring(self, Rect2(Vector2.ZERO, size).grow(1), get_theme_color("font_hover_color"))


## True while a held Buy is repeating (the repeats after the first purchase).
func is_repeating() -> bool:
	return _hold.held and _hold.repeats > 0


func state() -> Dictionary:
	return _state


func _on_down() -> void:
	_skip_pressed = true
	_hold.begin()
	set_process(true)
	_on_buy()


func _on_pressed() -> void:
	if _skip_pressed:
		_skip_pressed = false
		return
	_on_buy()


func _process(delta: float) -> void:
	_step_sparks(delta)
	if _hold.held:
		_repeat_hold(delta)
	elif _sparks.is_empty():
		set_process(false)


func _repeat_hold(delta: float) -> void:
	for i: int in _hold.step(delta):
		if not bool(_state.get("can_afford", false)):
			_hold.end()
			return
		buy_pressed.emit(attr_id)
		if not bool(_state.get("can_afford", false)):   # the gallery refreshed the card: that was the last one we can pay for
			_hold.end()
			return


func _on_buy() -> void:
	if bool(_state.get("can_afford", false)):
		buy_pressed.emit(attr_id)
	else:
		_deny()


## Bring the card in line with the sim. Cheap to call every refresh: nothing is rewritten unless it changed.
func refresh(s: Dictionary) -> void:
	_state = s
	var unlocked: bool = bool(s["unlocked"])
	var maxed: bool = bool(s["maxed"])
	var can: bool = bool(s["can_afford"])
	_icon.visible = unlocked
	_lock.visible = not unlocked
	_name.add_theme_color_override("font_color", RelicStyle.text if unlocked else RelicStyle.dim)
	_level.visible = unlocked
	_pips.visible = unlocked
	_unit.text = String(s["unit"])
	_unit.add_theme_color_override("font_color", RelicStyle.soft() if unlocked else RelicStyle.dim)
	if unlocked:
		_level.text = "%d/%d" % [s["level"], s["cap"]]
		_pips.set_level(int(s["level"]), int(s["cap"]), maxed)
		if maxed:
			_cost.text = "MAX"
			_cost.add_theme_color_override("font_color", RelicStyle.accent)
		else:
			_cost.text = "Buy %s" % s["cost_text"]
			_cost.add_theme_color_override("font_color", StatStyle.buy(can))
	else:
		_cost.text = "Locked"
		_cost.add_theme_color_override("font_color", RelicStyle.dim)
	_restyle(unlocked, maxed, can)
	if not _ticking:
		_set_delta_text(_build_delta(s, String(s["now"]), String(s["next"])))


## Outline and fill for the state: green when affordable, red when not, gold when maxed, a dim frame while locked.
func _restyle(unlocked: bool, maxed: bool, can: bool) -> void:
	var edge: Color = RelicStyle.dim
	var fill: Color = Color(0.0, 0.0, 0.0, 0.0)
	if not unlocked:
		edge = RelicStyle.dim
	elif maxed:
		edge = RelicStyle.accent
	else:
		edge = StatStyle.buy(can)
		if not can:
			fill = Color(0.0, 0.0, 0.0, 0.32)   # dim, not solid: the card stays readable
	var key: String = "%s|%s" % [edge.to_html(), fill.to_html()]
	if key == _style_key:
		return
	_style_key = key
	var hover_fill: Color = fill if fill.a > 0.0 else Color(RelicStyle.text, 0.07)
	add_theme_stylebox_override("normal", _frame(edge, fill))
	add_theme_stylebox_override("disabled", _frame(edge, fill))
	add_theme_stylebox_override("hover", _frame(edge.lerp(RelicStyle.text, 0.45), hover_fill))
	add_theme_stylebox_override("pressed", _frame(edge, Color(edge, 0.22)))
	add_theme_stylebox_override("hover_pressed", _frame(edge, Color(edge, 0.22)))


func _frame(edge: Color, fill: Color) -> AsciiBox:
	var b: AsciiBox = AsciiBox.make(AsciiBox.Kind.CARD, PAD.x, PAD.y)
	b.edge_override = edge
	b.fill_override = fill
	return b


func _build_delta(s: Dictionary, now: String, nxt: String) -> String:
	var dim: String = RelicStyle.soft().to_html(false)
	if not bool(s["unlocked"]):
		return "[color=#%s]%d / %d to unlock[/color]" % [dim, s["rebirths"], s["need"]]
	if bool(s["maxed"]):
		return "[color=#%s]%s[/color]  [color=#%s]MAX[/color]" % [dim, now, RelicStyle.good.to_html(false)]
	return "[color=#%s]%s[/color] [color=#%s]->[/color] [color=#%s]%s[/color]" % [dim, now, dim, RelicStyle.accent.to_html(false), nxt]


func _set_delta_text(t: String) -> void:
	if t != _delta_text:
		_delta_text = t
		_delta.text = t


## Called by the gallery right after a successful buy, with the state from after it.
func play_buy(after: Dictionary) -> void:
	var before: Dictionary = _state
	var light: bool = is_repeating()   # held repeats: pip pop and a quiet click only, no pop, sparks, flying cost or tick
	_sfx(&"ui_click", 0.9 + 0.5 * float(after["level"]) / maxf(float(after["cap"]), 1.0), -9.0 if light else 0.0)
	if not light:
		_sfx(&"popup_tick", 1.0 + 0.04 * float(int(after["level"]) % 12), -4.0)
	if bool(after["maxed"]):
		_sfx(&"gate_open", 1.3, -8.0)
	refresh_keep(after)
	_pips.pop()
	if light:
		_set_delta_text(_build_delta(after, String(after["now"]), String(after["next"])))
		return
	if calm():
		return
	_pop()
	_burst_sparks()
	_fly_cost(String(before.get("cost_text", "")))
	_tick(before, after)


## Take the new state (pips, button) but leave the delta text to the tick tween.
func refresh_keep(after: Dictionary) -> void:
	var was: bool = _ticking
	_ticking = true
	refresh(after)
	_ticking = was
	if not _ticking:
		_set_delta_text(_build_delta(after, String(after["now"]), String(after["next"])))


func _pop() -> void:
	pivot_offset = size * 0.5
	scale = Vector2(1.07, 1.07)
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A few pixel sparks leave the centre of the card and fall away. Nodes are not added: they are drawn in _draw.
func _burst_sparks() -> void:
	var c: Vector2 = size * 0.5
	var col: Color = StatStyle.color(_def.currency)
	for i in GraphicsQuality.particle_count(SPARKS):
		var a: float = randf() * TAU
		var sp: float = randf_range(60.0, 150.0)
		_sparks.append({"pos": c, "vel": Vector2(cos(a), sin(a) * 0.8) * sp, "age": 0.0,
			"life": randf_range(0.3, SPARK_LIFE), "col": col if i % 2 == 0 else PAPER_SPARK})
	set_process(true)
	queue_redraw()


func _step_sparks(delta: float) -> void:
	if _sparks.is_empty():
		return
	for s: Dictionary in _sparks:
		s["age"] = float(s["age"]) + delta
		var v: Vector2 = s["vel"] as Vector2
		v *= maxf(0.0, 1.0 - 2.4 * delta)
		v.y += SPARK_GRAVITY * delta
		s["vel"] = v
		s["pos"] = (s["pos"] as Vector2) + v * delta
	_sparks = Array(_sparks.filter(func(s: Dictionary) -> bool: return float(s["age"]) < float(s["life"])), TYPE_DICTIONARY, "", null)
	queue_redraw()


func _deny() -> void:
	_sfx(&"ui_back", 0.8, -2.0)
	if calm():
		return
	pivot_offset = size * 0.5
	scale = Vector2(0.95, 0.95)
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## "-170" in the cost colour leaves the card and flies to the balance in whole-texel steps.
func _fly_cost(cost_text: String) -> void:
	if cost_text == "" or not fly_target.is_valid():
		return
	var l := Label.new()
	l.text = "-%s" % cost_text
	l.top_level = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", AccessOptions.tint(RED))
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(l)
	var from: Vector2 = global_position + Vector2(size.x * 0.5 - 12.0, 0.0)
	var to: Vector2 = fly_target.call() as Vector2
	l.global_position = from
	var t := create_tween()
	t.tween_method(_fly_step.bind(l, from, to), 0.0, 1.0, FLY_SECONDS)
	t.tween_callback(l.queue_free)


func _fly_step(k: float, l: Label, from: Vector2, to: Vector2) -> void:
	if not is_instance_valid(l):
		return
	var stepped: float = floorf(k * 12.0) / 12.0
	var e: float = stepped * stepped
	l.global_position = (from.lerp(to, e) + Vector2(0.0, -10.0 * sin(stepped * PI))).round()
	l.modulate.a = 1.0 if stepped < 0.75 else 0.5


## The "now" and "next" values count up from their old values to the new ones in steps.
func _tick(before: Dictionary, after: Dictionary) -> void:
	if _def == null or before.is_empty():
		return
	var n0: float = UpgradeText.amount_at(_def, int(before["level"]))
	var n1: float = UpgradeText.amount_at(_def, int(after["level"]))
	var x0: float = UpgradeText.amount_at(_def, int(before["level"]) + 1)
	var x1: float = UpgradeText.amount_at(_def, int(after["level"]) + 1)
	_ticking = true
	var t := create_tween()
	t.tween_method(_tick_step.bind(after, [n0, n1, x0, x1]), 0.0, 1.0, 0.4)
	t.tween_callback(_tick_done)


func _tick_step(k: float, after: Dictionary, r: Array) -> void:
	var stepped: float = floorf(k * float(TICK_STEPS)) / float(TICK_STEPS)
	var nxt: String = "" if bool(after["maxed"]) else UpgradeText.value(_def, lerpf(float(r[2]), float(r[3]), stepped))
	_set_delta_text(_build_delta(after, UpgradeText.value(_def, lerpf(float(r[0]), float(r[1]), stepped)), nxt))


func _tick_done() -> void:
	_ticking = false
	_set_delta_text(_build_delta(_state, String(_state["now"]), String(_state["next"])))


func _sfx(sound: StringName, pitch: float, vol_db: float = 0.0) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var au: Node = tree.root.get_node_or_null("Audio")
	if au != null:
		au.call("play", sound, pitch, vol_db, &"UI", false)
