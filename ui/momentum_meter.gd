class_name MomentumMeter
extends PanelContainer
## Momentum panel: title, current stage name, the stage bar and the income bonus it pays.
## Walking charges it, pressing nudges it, it holds a moment, then drains (Sim.feed_momentum, Sim.momentum_hold).
## Behind DisplaySettings.momentum_meter (on by default). Hover for exact numbers (shared Tip).

const BAR_WIDTH: float = 128.0
const GHOST_HOLD: float = 0.35      ## seconds the ghost waits after a drop
const GHOST_DRAIN: float = 0.45     ## then follows at this much of the bar per second
const FLASH_TIME: float = 0.55

var _sim: Sim
var _bar: MomentumBar
var _stage: Label
var _value: Label
var _shown: float = 0.0
var _ghost: float = 0.0
var _ghost_wait: float = 0.0
var _flash: float = 0.0
var _blink: float = 0.0
var _last_tier: int = 0
var _sprint: Label        ## floats above the panel: SPRINTING HELD (Shift) or SPRINTING ENABLED (Ctrl lock)
var _sprint_state: int = 0


func setup(p_sim: Sim) -> void:
	_sim = p_sim
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", AsciiBox.make(AsciiBox.Kind.PANEL, 8.0, 4.0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	top.add_child(_title("MOMENTUM", Color("f6efd9")))
	_stage = _title("", RelicStyle.edge)
	_stage.custom_minimum_size = Vector2(72, 0)   # fixed room, so changing stage names never resize the panel
	_stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_stage)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	var bar_box := CenterContainer.new()
	bar_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar_box)
	_bar = MomentumBar.new(BAR_WIDTH)
	_bar.thresholds = _sim.config.momentum_tier_thresholds
	bar_box.add_child(_bar)
	_value = Label.new()
	_value.custom_minimum_size.x = 42
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_value)
	_sprint = _title("", RelicStyle.accent)
	_sprint.top_level = true   # outside the container's layout, so showing it never resizes the panel
	var plate := StyleBoxFlat.new()   # a dark backing, so the busy ground never shows through the letters
	plate.bg_color = Color("14161c")
	plate.set_border_width_all(1)
	plate.border_color = RelicStyle.edge
	plate.content_margin_left = 4.0
	plate.content_margin_right = 4.0
	plate.content_margin_top = 0.0
	plate.content_margin_bottom = 1.0
	_sprint.add_theme_stylebox_override("normal", plate)
	_sprint.visible = false
	add_child(_sprint)
	Tip.bind_all(self, Callable(self, "_spec"))
	_apply()


## The display face used on item titles (Pixelify Sans, emboldened, ink outline).
func _title(text: String, color: Color) -> Label:
	var face := FontVariation.new()
	face.base_font = preload("res://fonts/PixelifySans.ttf")
	face.variation_embolden = 0.6
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", face)
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("14161c"))
	l.add_theme_constant_override("outline_size", 2)
	return l


## Stage colours follow the zone palette: dim, good, accent, text, and Surge shimmers on top.
func _tier_color(tier: int) -> Color:
	var cols: Array[Color] = [RelicStyle.edge, RelicStyle.good, RelicStyle.accent, RelicStyle.text, RelicStyle.accent]
	return cols[clampi(tier, 0, cols.size() - 1)]


func _process(delta: float) -> void:
	# Appears with the Multiplier row, so a brand new player sees the first stat alone (see Onboarding).
	var on: bool = DisplaySettings.momentum_meter and _sim != null and GameState.onboarding.is_unlocked(Onboarding.F_DEWDROP)
	if visible != on:
		visible = on
	_update_sprint_label(on)
	if not on:
		return
	var target: float = _sim.momentum
	_shown = move_toward(_shown, target, delta * 1.5)
	if _shown < _ghost:
		if target < _ghost - 0.001 and _ghost_wait <= 0.0 and _sim.momentum_hold <= 0.0:
			_ghost_wait = GHOST_HOLD
		if _ghost_wait > 0.0:
			_ghost_wait -= delta
		else:
			_ghost = maxf(_shown, _ghost - GHOST_DRAIN * delta)
	else:
		_ghost = _shown
		_ghost_wait = 0.0
	var tier: int = _sim.momentum_tier()
	if tier != _last_tier:
		if tier > _last_tier:
			_flash = 1.0
		_last_tier = tier
	_flash = maxf(0.0, _flash - delta / FLASH_TIME)
	_blink += delta
	_apply()


func _update_sprint_label(panel_on: bool) -> void:
	var st: int = 0
	if panel_on and is_inside_tree():
		var w: Node = get_tree().get_first_node_in_group(&"walker")
		if w != null and w.has_method(&"sprint_state"):
			st = int(w.call(&"sprint_state"))
	if st != _sprint_state:
		_sprint_state = st
		_sprint.text = WalkerMotion.sprint_text(st)
		_sprint.add_theme_color_override("font_color", RelicStyle.accent if st == 1 else RelicStyle.good)
		_sprint.reset_size()
	_sprint.visible = st > 0
	if st > 0:
		_sprint.global_position = global_position + Vector2(0.0, -_sprint.size.y - 1.0)


func _apply() -> void:
	var tier: int = _sim.momentum_tier()
	var cols: Array[Color] = []
	for i in _sim.config.momentum_tier_names.size():
		cols.append(_tier_color(i))
	_bar.tier_colors = cols
	_bar.value = _shown
	_bar.ghost = _ghost
	_bar.tier = tier
	_bar.flash = _flash
	var hold_len: float = _sim.config.momentum_surge_hold if _sim.momentum >= 1.0 else _sim.config.momentum_grace
	_bar.hold = clampf(_sim.momentum_hold / maxf(hold_len, 0.001), 0.0, 1.0)
	var full: bool = tier >= _sim.config.momentum_tier_names.size() - 1
	var pulse: bool = full and not FxConfig.reduce_flashing and fmod(_blink, 0.6) < 0.3
	_bar.pulse = pulse
	_bar.queue_redraw()
	_stage.text = _sim.momentum_tier_name(tier).to_upper()
	var tc: Color = _tier_color(tier)
	_stage.add_theme_color_override("font_color", RelicStyle.text.lerp(tc, 1.0 - _flash) if _flash > 0.0 else tc)
	# No size change on a stage-up: a bigger font grows the row and pushes the panel. Colour and the frame flash carry it.
	_value.text = "+%d%%" % roundi(_sim.momentum_bonus() * 100.0)
	_value.modulate = RelicStyle.accent if pulse else Color.WHITE


func _spec() -> Variant:
	var c: GameConfig = _sim.config
	var tier: int = _sim.momentum_tier()
	var lines: Array[String] = []
	lines.append("Charge %d%%, income x%.2f" % [roundi(_sim.momentum * 100.0), 1.0 + _sim.momentum_bonus()])
	if tier < c.momentum_tier_thresholds.size():
		lines.append("Next: %s at %d%%" % [_sim.momentum_tier_name(tier + 1), roundi(c.momentum_tier_thresholds[tier] * 100.0)])
	else:
		lines.append("Surge holds %.0f s" % c.momentum_surge_hold)
	lines.append("Walk +%.1f%%/100 px, press +%.0f%%, crit +%.0f%%" % [c.momentum_per_unit * 10000.0, c.momentum_per_press * 100.0, c.momentum_per_crit * 100.0])
	lines.append("Holds %.1f s, then -%.0f%%/s" % [c.momentum_grace, c.momentum_decay_per_second * 100.0])
	return {"title": "Momentum: %s" % _sim.momentum_tier_name(tier), "body": "\n".join(lines), "hint": "Walk to climb."}
