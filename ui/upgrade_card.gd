class_name UpgradeCard
extends PanelContainer
## One upgrade in the Upgrades gallery: a framed card with a transparent fill, so the panel shows through it.
## The outline says whether you can buy it right now: green when the next level is affordable, red when it is not,
## dim while it is locked and gold once it is maxed. Inside: the icon (or padlock), name, level pips, "now -> next"
## and an animated Buy button whose cost is green when you can pay it and red when you can't.
## Layout and text come from an UpgradeText.state() dictionary, so this node holds no game rules.
##
## Hold the Buy button (mouse, Enter/Space or the pad's confirm button) to keep buying, faster the longer you hold
## (see HoldRepeat). Repeats stop the moment the next level cannot be paid for, and play a light version of the animation.
##
## The whole card is a buy target: a click anywhere on it buys (hold to keep buying), the Buy button still takes focus and keys.
## Hovering a card you can afford adds a faint wash.
##
## Buying plays: the card pops, a few pixel sparks leave its centre, the button squashes, the cost flies off toward the
## currency's balance, the numbers tick up in steps, the newest level pip pops, and a rising click. Reduce motion / reduce
## flashing skip the motion and keep the sound.

signal buy_pressed(attr_id: StringName)

const RED: Color = Color("#d9604c")   ## no red in the palette roles; fixed like the rarity colours
const TICK_STEPS: int = 8
const FLY_SECONDS: float = 0.55
## Card size at 640x360: two across fit the gallery's list. Inside a card the icon, delta (136) and Buy (80) share one line.
const CARD_SIZE: Vector2 = Vector2(268.0, 56.0)
const SPARKS: int = 7
const SPARK_LIFE: float = 0.5
const SPARK_GRAVITY: float = 150.0
const PAPER_SPARK: Color = Color("fff1c8")
const BORDER: int = 2
const PAD: float = 5.0

var attr_id: StringName
var fly_target: Callable = Callable()   ## returns the global point the cost flies toward

var _def: AttributeDef
var _state: Dictionary = {}
var _frame: StyleBoxFlat
var _icon: TextureRect
var _lock: LockIcon
var _name: Label
var _level: Label
var _pips: PipBar
var _delta: RichTextLabel
var _buy: PixelButton
var _hold: HoldRepeat = HoldRepeat.new()
var _skip_pressed: bool = false   ## the press already bought on button_down, so the matching `pressed` must not buy again
var _ticking: bool = false
var _delta_text: String = ""
var _sparks: Array[Dictionary] = []


func setup(a: AttributeDef) -> void:
	_def = a
	attr_id = a.id
	custom_minimum_size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP   # the whole card takes clicks; the Buy button is a child and takes its own
	gui_input.connect(_on_card_input)
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))
	_frame = StyleBoxFlat.new()
	_frame.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	_frame.set_border_width_all(BORDER)
	_frame.set_corner_radius_all(0)
	_frame.set_content_margin_all(PAD)
	_frame.border_color = RelicStyle.dim
	add_theme_stylebox_override("panel", _frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(16, 16)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(slot)
	_icon = TextureRect.new()
	_icon.texture = load("res://assets/icons/%s.png" % StatIndex.attr_icon(a)) as Texture2D
	_icon.custom_minimum_size = Vector2(16, 16)
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(_icon)
	_lock = LockIcon.new()
	_lock.visible = false
	_lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(_lock)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	_name = Label.new()
	_name.text = a.display_name
	top.add_child(_name)
	_level = Label.new()
	_level.add_theme_color_override("font_color", RelicStyle.soft())
	top.add_child(_level)
	_pips = PipBar.new()
	_pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_pips)
	_delta = RichTextLabel.new()
	_delta.bbcode_enabled = true
	_delta.fit_content = true
	_delta.scroll_active = false
	_delta.autowrap_mode = TextServer.AUTOWRAP_OFF
	_delta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_delta.custom_minimum_size = Vector2(136, 0)
	_delta.add_theme_color_override("default_color", RelicStyle.text)
	col.add_child(_delta)
	_buy = PixelButton.new()
	_buy.custom_minimum_size = Vector2(80, 0)
	_buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_buy.pressed.connect(_on_pressed)
	_buy.button_down.connect(_on_down)
	_buy.button_up.connect(_hold.end)
	_buy.focus_exited.connect(_hold.end)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_hold.end())
	row.add_child(_buy)
	set_process(false)


## True while a held Buy is repeating (the repeats after the first purchase).
func is_repeating() -> bool:
	return _hold.held and _hold.repeats > 0


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
		if not bool(_state.get("can_afford", false)):   # the menu refreshed the card: that was the last one we can pay for
			_hold.end()
			return


func _on_buy() -> void:
	if bool(_state.get("can_afford", false)):
		buy_pressed.emit(attr_id)
	else:
		_deny()


## A click on the card outside the Buy button: press starts the buy and hold, release ends the hold.
## It does not set _skip_pressed, which belongs to the Buy button's own press.
func _on_card_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_hold.begin()
		set_process(true)
		_on_buy()
	else:
		_hold.end()


func _hover(on: bool) -> void:
	var wash: bool = on and bool(_state.get("can_afford", false))
	_frame.bg_color = Color(RelicStyle.text, 0.06) if wash else Color(0.0, 0.0, 0.0, 0.0)


func state() -> Dictionary:
	return _state


## The outline colour for a card in this state: dim locked, gold maxed, green affordable, red out of reach.
static func edge_color(unlocked: bool, maxed: bool, can_afford: bool) -> Color:
	if not unlocked:
		return RelicStyle.dim
	if maxed:
		return RelicStyle.accent
	return RelicStyle.good if can_afford else AccessOptions.tint(RED)


## Bring the card in line with the sim. Cheap to call every frame: nothing is rewritten unless it changed.
func refresh(s: Dictionary) -> void:
	_state = s
	var unlocked: bool = bool(s["unlocked"])
	var maxed: bool = bool(s["maxed"])
	var can: bool = bool(s["can_afford"])
	_frame.border_color = edge_color(unlocked, maxed, can)
	_icon.visible = unlocked
	_lock.visible = not unlocked
	_name.add_theme_color_override("font_color", RelicStyle.text if unlocked else RelicStyle.dim)
	_level.visible = unlocked
	_pips.visible = unlocked
	_buy.visible = unlocked
	if unlocked:
		_level.text = "%d/%d" % [s["level"], s["cap"]]
		_pips.set_level(int(s["level"]), int(s["cap"]), maxed)
		_buy.disabled = maxed
		if maxed:
			_buy.text = "MAX"
		else:
			_buy.text = "Buy %s" % s["cost_text"]
			var c: Color = RelicStyle.good if can else AccessOptions.tint(RED)
			for n: String in ["font_color", "font_hover_color", "font_focus_color"]:
				_buy.add_theme_color_override(n, c)
	if not _ticking:
		_set_delta_text(_build_delta(s, String(s["now"]), String(s["next"])))


func _build_delta(s: Dictionary, now: String, nxt: String) -> String:
	var dim: String = RelicStyle.soft().to_html(false)
	if not bool(s["unlocked"]):
		return "[color=#%s]%s (%d/%d)[/color]" % [dim, s["lock"], s["rebirths"], s["need"]]
	if bool(s["maxed"]):
		return "[color=#%s]%s[/color] [color=#%s]MAX[/color] [color=#%s]%s[/color]" % [dim, now, RelicStyle.good.to_html(false), dim, s["unit"]]
	return "[color=#%s]%s ->[/color] [color=#%s]%s[/color] [color=#%s]%s[/color]" % [dim, now, RelicStyle.accent.to_html(false), nxt, dim, s["unit"]]


func _set_delta_text(t: String) -> void:
	if t != _delta_text:
		_delta_text = t
		_delta.text = t


func _calm() -> bool:
	return MeadowLife.reduce_motion or FxConfig.reduce_flashing


## Called by the menu right after a successful buy, with the state from after it.
func play_buy(after: Dictionary) -> void:
	var before: Dictionary = _state
	var light: bool = is_repeating()   # held repeats: pip pop and a quiet click only, no squash, flying cost or tick
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
	if _calm():
		return
	_squash()
	_pop_card()
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


func _squash() -> void:
	_buy.pivot_offset = _buy.size / 2.0
	_buy.scale = Vector2(1.14, 0.82)
	var t := create_tween()
	t.tween_property(_buy, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The whole card pops a little when a buy lands.
func _pop_card() -> void:
	pivot_offset = size * 0.5
	scale = Vector2(1.04, 1.04)
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Pixel sparks leave the centre and fall away. They are drawn in _draw, so they add no nodes.
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


func _draw() -> void:
	for s: Dictionary in _sparks:
		var age: float = float(s["age"])
		var u: float = age / float(s["life"])
		if u > 0.7 and int(age * 40.0) % 2 == 0:
			continue   # the last part of a spark blinks out, pixel-art style
		var sz: float = 2.0 if u < 0.3 else 1.0
		draw_rect(Rect2((s["pos"] as Vector2).round(), Vector2(sz, sz)), s["col"] as Color)


func _deny() -> void:
	_sfx(&"ui_back", 0.8, -2.0)
	if _calm():
		return
	_buy.pivot_offset = _buy.size / 2.0
	_buy.scale = Vector2(0.9, 0.9)
	var t := create_tween()
	t.tween_property(_buy, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## "-170" in the cost colour leaves the button and flies to the currency's balance in whole-texel steps.
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
	var from: Vector2 = _buy.global_position + Vector2(_buy.size.x * 0.5 - 12.0, 0.0)
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


## The "now" and "next" numbers count up from their old values to the new ones in steps.
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
