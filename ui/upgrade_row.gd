class_name UpgradeRow
extends HBoxContainer
## One line of the Upgrades menu: icon (or padlock while locked), name, level pips, "now -> next" with the current value
## greyed and the next one lit, and an animated Buy button whose cost is green when you can pay it and red when you can't.
## Layout and text come from an UpgradeText.state() dictionary, so this node holds no game rules.
##
## Buying plays: button squash, the cost flying off toward the Prestige readout, the numbers ticking up in steps, the newest
## level pip popping, and a rising click. Reduce motion / reduce flashing skip the motion and keep the sound.

signal buy_pressed(attr_id: StringName)

const RED: Color = Color("#d9604c")   ## no red in the palette roles; fixed like the rarity colours
const TICK_STEPS: int = 8
const FLY_SECONDS: float = 0.55

var attr_id: StringName
var fly_target: Callable = Callable()   ## returns the global point the cost flies toward

var _def: AttributeDef
var _state: Dictionary = {}
var _icon: TextureRect
var _lock: LockIcon
var _name: Label
var _level: Label
var _pips: PipBar
var _delta: RichTextLabel
var _buy: PixelButton
var _ticking: bool = false
var _delta_text: String = ""


func setup(a: AttributeDef) -> void:
	_def = a
	attr_id = a.id
	add_theme_constant_override("separation", 6)
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(16, 16)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(slot)
	_icon = TextureRect.new()
	_icon.texture = load("res://assets/icons/%s.png" % String(StatIndex.ATTR_ICONS.get(a.effect, "prestige"))) as Texture2D
	_icon.custom_minimum_size = Vector2(16, 16)
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(_icon)
	_lock = LockIcon.new()
	_lock.visible = false
	slot.add_child(_lock)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	col.add_child(top)
	_name = Label.new()
	_name.text = a.display_name
	top.add_child(_name)
	_level = Label.new()
	_level.add_theme_color_override("font_color", RelicStyle.dim)
	top.add_child(_level)
	_pips = PipBar.new()
	_pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_pips)
	_delta = RichTextLabel.new()
	_delta.bbcode_enabled = true
	_delta.fit_content = true
	_delta.scroll_active = false
	_delta.autowrap_mode = TextServer.AUTOWRAP_OFF
	_delta.custom_minimum_size = Vector2(196, 0)
	_delta.add_theme_color_override("default_color", RelicStyle.text)
	col.add_child(_delta)
	_buy = PixelButton.new()
	_buy.custom_minimum_size = Vector2(84, 0)
	_buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_buy.pressed.connect(_on_buy)
	add_child(_buy)


func _on_buy() -> void:
	if bool(_state.get("can_afford", false)):
		buy_pressed.emit(attr_id)
	else:
		_deny()


func state() -> Dictionary:
	return _state


## Bring the row in line with the sim. Cheap to call every frame: nothing is rewritten unless it changed.
func refresh(s: Dictionary) -> void:
	_state = s
	var unlocked: bool = bool(s["unlocked"])
	var maxed: bool = bool(s["maxed"])
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
			var c: Color = RelicStyle.good if bool(s["can_afford"]) else RED
			for n: String in ["font_color", "font_hover_color", "font_focus_color"]:
				_buy.add_theme_color_override(n, c)
	if not _ticking:
		_set_delta_text(_build_delta(s, String(s["now"]), String(s["next"])))


func _build_delta(s: Dictionary, now: String, nxt: String) -> String:
	var dim: String = RelicStyle.dim.to_html(false)
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
	_sfx(&"ui_click", 0.9 + 0.5 * float(after["level"]) / maxf(float(after["cap"]), 1.0))
	_sfx(&"popup_tick", 1.0 + 0.04 * float(int(after["level"]) % 12), -4.0)
	if bool(after["maxed"]):
		_sfx(&"gate_open", 1.3, -8.0)
	refresh_keep(after)
	_pips.pop()
	if _calm():
		return
	_squash()
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


func _deny() -> void:
	_sfx(&"ui_back", 0.8, -2.0)
	if _calm():
		return
	_buy.pivot_offset = _buy.size / 2.0
	_buy.scale = Vector2(0.9, 0.9)
	var t := create_tween()
	t.tween_property(_buy, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## "-170" in the cost colour leaves the button and flies to the Prestige readout in whole-texel steps.
func _fly_cost(cost_text: String) -> void:
	if cost_text == "" or not fly_target.is_valid():
		return
	var l := Label.new()
	l.text = "-%s" % cost_text
	l.top_level = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", RED)
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
